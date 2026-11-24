#!/usr/bin/env python3
"""Convert zsh EXTENDED_HISTORY into a new bash history file.

Zsh writes each event as ``: <unix-time>:<elapsed-seconds>;<command>`` and
writes a newline inside the command as a backslash followed by a newline.
Elapsed seconds are dropped. Bash receives ``#<unix-time>`` and the command.

A trailing run of backslashes with an odd length is treated as a continuation.
A command that really ends with an odd number of backslashes cannot be told
apart from that continuation. Non-UTF-8 input is refused because it may be
zsh metafied history. The destination must be missing or empty, must not be a
symlink, and must not be the source file. An existing bash history is never
overwritten or appended to.
"""

from __future__ import annotations

import os
import re
import sys
import tempfile
from pathlib import Path


class ConversionError(Exception):
    pass


_ENTRY = re.compile(r"^: (\d+):(\d+);(.*)$", re.DOTALL)


def logical_lines(text: str) -> list[str]:
    if text == "":
        raise ConversionError("empty history")
    lines = text.split("\n")
    if text.endswith("\n"):
        lines.pop()
    logical: list[str] = []
    pending: str | None = None
    for line in lines:
        count = 0
        index = len(line)
        while index > 0 and line[index - 1] == "\\":
            count += 1
            index -= 1
        if count % 2 == 1:
            piece = line[:-1]
            pending = piece if pending is None else pending + "\n" + piece
            continue
        piece = line
        if pending is not None:
            piece = pending + "\n" + piece
            pending = None
        logical.append(piece)
    if pending is not None:
        raise ConversionError("file ends in a continuation")
    if not logical:
        raise ConversionError("empty history")
    return logical


def parse_extended_history(text: str) -> list[tuple[int, str]]:
    entries: list[tuple[int, str]] = []
    for line in logical_lines(text):
        match = _ENTRY.fullmatch(line)
        if match is None:
            raise ConversionError("line is not zsh extended history")
        command = match.group(3)
        if command == "":
            raise ConversionError("empty command")
        if "\0" in command:
            raise ConversionError("command contains NUL")
        entries.append((int(match.group(1)), command))
    return entries


def render_bash_history(entries: list[tuple[int, str]]) -> str:
    parts: list[str] = []
    for timestamp, command in entries:
        parts.append(f"#{timestamp}\n{command}\n")
    return "".join(parts)


def convert_file(source: Path, dest: Path) -> None:
    if not source.is_file() or source.is_symlink():
        raise ConversionError("source is not a regular file")
    if dest.is_symlink():
        raise ConversionError("destination is a symlink")
    if dest.exists() and dest.stat().st_size > 0:
        raise ConversionError("destination is not empty")
    if dest.exists() and source.resolve() == dest.resolve():
        raise ConversionError("source and destination are the same file")
    if not dest.parent.is_dir():
        raise ConversionError("destination directory does not exist")
    try:
        text = source.read_text(encoding="utf-8")
    except UnicodeDecodeError as exc:
        raise ConversionError("source is not UTF-8") from exc
    payload = render_bash_history(parse_extended_history(text)).encode("utf-8")
    fd, name = tempfile.mkstemp(prefix=".bash_history.", dir=dest.parent)
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(name, 0o600)
        os.replace(name, dest)
    except Exception:
        try:
            os.unlink(name)
        except OSError:
            pass
        raise


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(
            "usage: zsh-history-to-bash.py SOURCE DEST",
            file=sys.stderr,
        )
        return 2
    try:
        convert_file(Path(argv[1]), Path(argv[2]))
    except ConversionError as exc:
        print(f"zsh-history-to-bash: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
