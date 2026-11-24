#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
cd -- "$root"
bash tests/test_static.sh
bash tests/test_install.sh
python3 tests/test_zsh_history.py
python3 tests/test_history_pty.py
echo "all tests ok"
