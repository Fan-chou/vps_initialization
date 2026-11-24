#!/usr/bin/env python3
import importlib.util
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "share" / "bash" / "zsh-history-to-bash.py"


def load():
    spec = importlib.util.spec_from_file_location("zhist", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ParseTests(unittest.TestCase):
    def setUp(self):
        self.mod = load()

    def test_extended_history_keeps_order_and_multiline(self):
        text = ": 10:0;echo hello\n: 11:1;echo foo\\\nbar\n: 12:0;pwd\n"
        entries = self.mod.parse_extended_history(text)
        self.assertEqual(
            entries,
            [(10, "echo hello"), (11, "echo foo\nbar"), (12, "pwd")],
        )
        rendered = self.mod.render_bash_history(entries)
        self.assertEqual(
            rendered,
            "#10\necho hello\n#11\necho foo\nbar\n#12\npwd\n",
        )

    def test_plain_history_is_refused(self):
        with self.assertRaises(self.mod.ConversionError):
            self.mod.parse_extended_history("echo hello\n")

    def test_one_trailing_backslash_merges_the_next_event(self):
        text = ": 10:0;echo end\\\n: 11:0;pwd\n"
        entries = self.mod.parse_extended_history(text)
        self.assertEqual(len(entries), 1)
        self.assertEqual(entries[0][0], 10)
        self.assertIn("pwd", entries[0][1])


class FileTests(unittest.TestCase):
    def setUp(self):
        self.mod = load()
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)

    def write_source(self, text: str) -> Path:
        path = self.dir / "zsh_history"
        path.write_text(text, encoding="utf-8")
        return path

    def test_writes_empty_destination_and_refuses_a_second_write(self):
        source = self.write_source(": 10:0;echo hello\n")
        dest = self.dir / "bash_history"
        dest.write_text("", encoding="utf-8")
        self.mod.convert_file(source, dest)
        self.assertEqual(dest.read_text(encoding="utf-8"), "#10\necho hello\n")
        self.assertEqual(dest.stat().st_mode & 0o777, 0o600)
        with self.assertRaises(self.mod.ConversionError):
            self.mod.convert_file(source, dest)
        self.assertEqual(dest.read_text(encoding="utf-8"), "#10\necho hello\n")

    def test_refuses_symlink_and_non_utf8(self):
        source = self.write_source(": 10:0;echo hello\n")
        target = self.dir / "target"
        target.write_text("keep\n", encoding="utf-8")
        link = self.dir / "link"
        link.symlink_to(target)
        with self.assertRaises(self.mod.ConversionError):
            self.mod.convert_file(source, link)
        self.assertEqual(target.read_text(encoding="utf-8"), "keep\n")
        raw = self.dir / "raw"
        raw.write_bytes(b": 10:0;\xff\n")
        dest = self.dir / "out"
        with self.assertRaises(self.mod.ConversionError):
            self.mod.convert_file(raw, dest)
        self.assertFalse(dest.exists())

    def test_cli_does_not_touch_a_nonempty_file(self):
        source = self.write_source(": 10:0;echo hello\n")
        dest = self.dir / "bash_history"
        dest.write_text("already\n", encoding="utf-8")
        result = subprocess.run(
            ["python3", str(SCRIPT), str(source), str(dest)],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 1)
        self.assertEqual(dest.read_text(encoding="utf-8"), "already\n")
        self.assertNotIn(os.environ.get("HOME", ""), str(dest))


if __name__ == "__main__":
    unittest.main()
