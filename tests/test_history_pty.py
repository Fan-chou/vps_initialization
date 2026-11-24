#!/usr/bin/env python3
"""PTY checks for the ble.sh unique-prefix Up/Down adapter.

The shell is a temporary HOME. HISTFILE is a synthetic file in that HOME.
"""

from __future__ import annotations

import codecs
import fcntl
import os
import pty
import select
import struct
import subprocess
import termios
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROWS = 40
COLS = 120
HIST = [
    "echo hello",
    "ls /tmp",
    "ll",
    "ls /tmp",
    "echo world",
    "ll",
    "ls -la",
    "cat foo",
    "ls -la",
    "pwd",
]


class Screen:
    def __init__(self) -> None:
        self.grid = [[" "] * COLS for _ in range(ROWS)]
        self.cy = 0
        self.cx = 0
        self.pending = ""
        self.decoder = codecs.getincrementaldecoder("utf-8")("replace")
        self.raw = bytearray()

    def feed(self, data: bytes) -> None:
        self.raw.extend(data)
        if len(self.raw) > 20000:
            del self.raw[:-20000]
        self.pending += self.decoder.decode(data)
        self.pending = self._consume(self.pending)

    def _consume(self, text: str) -> str:
        index = 0
        while index < len(text):
            if text[index] != "\x1b":
                self._put(text[index])
                index += 1
                continue
            nxt = self._escape(text, index)
            if nxt is None:
                return text[index:]
            index = nxt
        return ""

    def _escape(self, text: str, index: int) -> int | None:
        if index + 1 >= len(text):
            return None
        kind = text[index + 1]
        if kind == "[":
            cursor = index + 2
            while cursor < len(text) and not (0x40 <= ord(text[cursor]) <= 0x7E):
                cursor += 1
            if cursor >= len(text):
                return None
            self._csi(text[index + 2 : cursor], text[cursor])
            return cursor + 1
        if kind == "]":
            cursor = index + 2
            while cursor < len(text):
                if text[cursor] == "\a":
                    return cursor + 1
                if text[cursor] == "\x1b" and cursor + 1 < len(text) and text[cursor + 1] == "\\":
                    return cursor + 2
                cursor += 1
            return None
        cursor = index + 1
        while cursor < len(text) and 0x20 <= ord(text[cursor]) <= 0x2F:
            cursor += 1
        if cursor >= len(text):
            return None
        return cursor + 1

    def _csi(self, body: str, final: str) -> None:
        if body.startswith("?"):
            return
        nums: list[int] = []
        if body:
            for part in body.split(";"):
                if part.isdigit():
                    nums.append(int(part))
                elif part == "":
                    nums.append(0)
                else:
                    return

        def num(pos: int, default: int) -> int:
            if pos < len(nums) and nums[pos]:
                return nums[pos]
            return default

        if final == "A":
            self.cy = max(0, self.cy - num(0, 1))
        elif final == "B":
            self.cy = min(ROWS - 1, self.cy + num(0, 1))
        elif final == "C":
            self.cx = min(COLS - 1, self.cx + num(0, 1))
        elif final == "D":
            self.cx = max(0, self.cx - num(0, 1))
        elif final == "G":
            self.cx = min(COLS - 1, max(0, num(0, 1) - 1))
        elif final in "Hf":
            self.cy = min(ROWS - 1, max(0, num(0, 1) - 1))
            self.cx = min(COLS - 1, max(0, num(1, 1) - 1))
        elif final == "K":
            mode = nums[0] if nums else 0
            if mode == 0:
                self._clear(self.cx, COLS)
            elif mode == 1:
                self._clear(0, self.cx + 1)
            elif mode == 2:
                self.grid[self.cy] = [" "] * COLS
        elif final == "J":
            mode = nums[0] if nums else 0
            if mode == 2:
                self.grid = [[" "] * COLS for _ in range(ROWS)]
                self.cy = 0
                self.cx = 0
            elif mode == 0:
                self._clear(self.cx, COLS)
                for row in range(self.cy + 1, ROWS):
                    self.grid[row] = [" "] * COLS
        elif final == "P":
            count = num(0, 1)
            row = self.grid[self.cy]
            del row[self.cx : self.cx + count]
            row.extend([" "] * (COLS - len(row)))
            self.grid[self.cy] = row[:COLS]
        elif final == "X":
            self._clear(self.cx, min(COLS, self.cx + num(0, 1)))
        elif final == "M":
            count = num(0, 1)
            for _ in range(count):
                if self.cy < len(self.grid):
                    del self.grid[self.cy]
                    self.grid.append([" "] * COLS)
        elif final == "L":
            count = num(0, 1)
            for _ in range(count):
                self.grid.pop()
                self.grid.insert(self.cy, [" "] * COLS)
        elif final == "s":
            self.saved = (self.cy, self.cx)
        elif final == "u":
            self.cy, self.cx = getattr(self, "saved", (self.cy, self.cx))

    def _clear(self, start: int, end: int) -> None:
        for col in range(start, end):
            self.grid[self.cy][col] = " "

    def _put(self, char: str) -> None:
        if char == "\r":
            self.cx = 0
            return
        if char == "\n":
            if self.cy >= ROWS - 1:
                self.grid.pop(0)
                self.grid.append([" "] * COLS)
            else:
                self.cy += 1
            return
        if char == "\b":
            self.cx = max(0, self.cx - 1)
            return
        if char == "\t":
            self.cx = min(COLS - 1, (self.cx + 8) & ~7)
            return
        if ord(char) < 32:
            return
        if self.cx >= COLS:
            self.cx = 0
            if self.cy >= ROWS - 1:
                self.grid.pop(0)
                self.grid.append([" "] * COLS)
            else:
                self.cy += 1
        self.grid[self.cy][self.cx] = char
        self.cx += 1

    def dump(self) -> str:
        lines = []
        for index, row in enumerate(self.grid):
            text = "".join(row).rstrip()
            if not text and index != self.cy:
                continue
            mark = " <cursor>" if index == self.cy else ""
            lines.append(f"{index:02d}|{text}{mark}")
        lines.append(f"cursor={self.cy},{self.cx}")
        lines.append(repr(bytes(self.raw[-300:])))
        return "\n".join(lines)

    def has_prompt(self) -> bool:
        return any("❯" in "".join(row) for row in self.grid)

    def command(self) -> tuple[str, str]:
        row = "".join(self.grid[self.cy])
        mark = row.rfind("❯")
        start = 0 if mark < 0 else mark + 1
        if start < len(row) and row[start] == " ":
            start += 1
        visible = row[start:].rstrip()
        accepted = row[start : self.cx].rstrip(" ")
        return visible, accepted


class Shell:
    def __init__(self, home: Path, histfile: Path) -> None:
        self.screen = Screen()
        master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", ROWS, COLS, 0, 0))
        env = {
            "HOME": str(home),
            "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
            "TERM": "xterm-256color",
            "LANG": "C.UTF-8",
            "LC_ALL": "C.UTF-8",
            "HISTFILE": str(histfile),
            "HISTSIZE": "50000",
            "HISTFILESIZE": "50000",
            "USER": "tester",
            "LOGNAME": "tester",
            "SHELL": "/bin/bash",
            "INPUTRC": "/dev/null",
        }

        def preexec() -> None:
            os.setsid()
            try:
                fcntl.ioctl(0, termios.TIOCSCTTY, 0)
            except OSError:
                pass

        self.proc = subprocess.Popen(
            ["bash", "--noprofile", "--rcfile", str(home / ".bashrc"), "-i"],
            stdin=slave,
            stdout=slave,
            stderr=slave,
            env=env,
            preexec_fn=preexec,
            close_fds=True,
        )
        os.close(slave)
        self.master = master

    def close(self) -> None:
        if self.proc.poll() is None:
            self.proc.terminate()
            try:
                self.proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.proc.kill()
        try:
            os.close(self.master)
        except OSError:
            pass

    def _read_once(self, timeout: float) -> bool:
        if self.proc.poll() is not None:
            return False
        ready, _, _ = select.select([self.master], [], [], timeout)
        if not ready:
            return False
        try:
            data = os.read(self.master, 65536)
        except OSError:
            return False
        if not data:
            return False
        self.screen.feed(data)
        return True

    def wait_until(self, pred, timeout: float = 8.0, quiet: float = 0.25) -> None:
        deadline = time.monotonic() + timeout
        last = time.monotonic()
        while time.monotonic() < deadline:
            if self._read_once(0.05):
                last = time.monotonic()
                continue
            if pred() and time.monotonic() - last >= quiet:
                return
        raise AssertionError(self.screen.dump())

    def send(self, data: bytes) -> None:
        os.write(self.master, data)
        time.sleep(0.02)

    def prompt(self) -> None:
        def ready() -> bool:
            blob = "\n".join("".join(row) for row in self.screen.grid)
            if "updating tput cache" in blob and "done" not in blob.split("updating tput cache", 1)[-1]:
                return False
            return self.screen.has_prompt()

        self.wait_until(ready, timeout=40, quiet=0.5)

    def visible_and_accepted(self) -> tuple[str, str]:
        return self.screen.command()


def write_history(path: Path) -> None:
    lines: list[str] = []
    for index, command in enumerate(HIST, start=1):
        lines.append(f"#{1700000000 + index}")
        lines.append(command)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def install(home: Path) -> None:
    passwd = home / "passwd"
    passwd.write_text("tester:x:1000:1000:Tester:/nonexistent/tester:/bin/zsh\n", encoding="utf-8")
    env = os.environ.copy()
    env.update(
        {
            "VPS_INIT_HOME": str(home),
            "VPS_INIT_USER": "tester",
            "VPS_INIT_PASSWD_FILE": str(passwd),
            "VPS_INIT_LOGIN_SHELL": "/bin/zsh",
            "VPS_INIT_SKIP_CHSH": "1",
            "VPS_INIT_SRC_CACHE": str(home / "src-cache"),
        }
    )
    env.pop("VPS_INIT_SKIP_DOWNLOADS", None)
    log = home / "install.log"
    with log.open("w", encoding="utf-8") as handle:
        subprocess.run(
            ["bash", "-c", 'source "$1" && InstallBashInteractive', "bash", str(ROOT / "vps_initialization.sh")],
            check=True,
            env=env,
            timeout=240,
            stdout=handle,
            stderr=subprocess.STDOUT,
        )
    ble = home / ".local/share/blesh/ble.sh"
    text = ble.read_text(encoding="utf-8", errors="replace")
    if "0.4.0-devel4+1529427" not in text:
        raise SystemExit("installed ble.sh is not commit 1529427")


def open_shell(home: Path) -> Shell:
    histfile = home / "synthetic_history"
    write_history(histfile)
    shell = Shell(home, histfile)
    try:
        shell.prompt()
    except Exception:
        shell.close()
        raise
    return shell


def expect_accepted(shell: Shell, accepted: str, visible_prefix: str | None = None) -> None:
    def ready() -> bool:
        visible, got = shell.visible_and_accepted()
        if got != accepted:
            return False
        if visible_prefix is not None and not visible.startswith(visible_prefix):
            return False
        return True

    try:
        shell.wait_until(ready, quiet=0.4)
    except AssertionError as exc:
        visible, got = shell.visible_and_accepted()
        raise AssertionError(
            f"wanted accepted={accepted!r} visible~{visible_prefix!r}\n"
            f"got accepted={got!r} visible={visible!r}\n{exc}"
        ) from None


def check_prefix(home: Path) -> None:
    shell = open_shell(home)
    try:
        shell.send(b"l")
        expect_accepted(shell, "l", "ls -la")
        shell.send(b"\x1b[A")
        expect_accepted(shell, "ll")
        shell.send(b"\x1b[A")
        expect_accepted(shell, "ls /tmp")
        shell.send(b"\x1b[B")
        expect_accepted(shell, "ll")
        shell.send(b"\x1b[B")
        expect_accepted(shell, "l", "l")
    finally:
        shell.close()


def check_unique_history(home: Path) -> None:
    shell = open_shell(home)
    expected = ["pwd", "ls -la", "cat foo", "ll", "echo world", "ls /tmp", "echo hello"]
    try:
        for command in expected:
            shell.send(b"\x1b[A")
            expect_accepted(shell, command)
        shell.send(b"\x1b[A")
        expect_accepted(shell, "echo hello")
    finally:
        shell.close()


def check_ctrl_p_keeps_duplicates(home: Path) -> None:
    shell = open_shell(home)
    try:
        for command in ("pwd", "ls -la", "cat foo", "ls -la"):
            shell.send(b"\x10")
            expect_accepted(shell, command)
    finally:
        shell.close()


def check_accept(home: Path, key: bytes) -> None:
    shell = open_shell(home)
    try:
        shell.send(b"l")
        expect_accepted(shell, "l", "ls -la")
        shell.send(key)
        expect_accepted(shell, "ls -la", "ls -la")
    finally:
        shell.close()


def main() -> None:
    import tempfile

    with tempfile.TemporaryDirectory(prefix="vps-init-pty-") as tmp:
        home = Path(tmp)
        install(home)
        install(home)
        check_prefix(home)
        check_unique_history(home)
        check_ctrl_p_keeps_duplicates(home)
        check_accept(home, b"\x1b[C")
        check_accept(home, b"\x06")
    print("pty ok")


if __name__ == "__main__":
    main()
