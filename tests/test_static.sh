#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
cd -- "$root"

bash -n vps_initialization.sh
bash -n share/bash/install.lib.sh
bash -n share/bash/bashrc
bash -n share/bash/prompt.sh
bash -n share/bash/extract.sh
bash -n share/bash/man-colors.sh
bash -n share/bash/git-helpers.sh
bash -n share/bash/git-aliases.sh
bash -n share/bash/history-prefix-unique.sh
bash -n share/bash/bashrc-stub.sh
bash -n share/bash/login-block.sh
python3 -m py_compile share/bash/zsh-history-to-bash.py

shellcheck \
  share/bash/install.lib.sh \
  share/bash/bashrc \
  share/bash/prompt.sh \
  share/bash/extract.sh \
  share/bash/man-colors.sh \
  share/bash/git-helpers.sh \
  share/bash/git-aliases.sh \
  share/bash/history-prefix-unique.sh \
  share/bash/bashrc-stub.sh \
  share/bash/login-block.sh \
  tests/test_static.sh \
  tests/test_install.sh \
  tests/run.sh

if grep -n -E 'noglob|&!' share/bash/git-aliases.sh; then
  echo "git aliases still contain zsh syntax" >&2
  exit 1
fi
if grep -R -n -E 'RSRS_LIBC|npm-global|(^|[^[:alnum:]])\/root([^[:alnum:]]|$)' share vps_initialization.sh; then
  echo "personal path or hardcoded root leaked" >&2
  exit 1
fi

base=$(awk '/^BaseInstall\(\)/,/^}$/' vps_initialization.sh)
if printf '%s\n' "$base" | grep -E '(^|[^[:alnum:]_])zsh([^[:alnum:]_]|$)' >/dev/null; then
  echo "BaseInstall still installs zsh" >&2
  exit 1
fi

grep -q '152942758f567e51fd17bdc7b3783d27b3c476aa' share/bash/install.lib.sh
grep -q '0.4.0-devel4+1529427' share/bash/install.lib.sh
grep -q 'd37a763a6a30e1b32766fecc3b8ffd6127f8a0fd' share/bash/install.lib.sh
grep -q 'a74bc5976b7dd1adc9efdda3b2b79eaff2bef7d227cf3139959f8df2b89beb72' share/bash/install.lib.sh
grep -q '2.18.0' share/bash/install.lib.sh
grep -q '88bcf85124f77f74f2f2f8bcd16ac4382d807a827ede742a64940c7116aea33f' share/bash/install.lib.sh
grep -q 'vps_init_resolve_account' vps_initialization.sh
grep -q 'bash-rollback' vps_initialization.sh

bash --noprofile --norc -c '
  source "$1"
  type gtl | grep -q "function"
  type gk | grep -q "function"
  type gke | grep -q "function"
  type _git_log_prettily | grep -q "function"
' bash "$root/share/bash/git-aliases.sh"

bash --noprofile --norc -c '
  cd /tmp
  source "$1"
  __pureish_prompt || true
  case $PS1 in
    *"38;2;255;0;0"*"❯"*) ;;
    *) printf "PS1=%s\n" "$PS1" >&2; exit 1 ;;
  esac
' bash "$root/share/bash/prompt.sh"

bash --noprofile --norc -c '
  source "$1"
  extract
  test $? -eq 1
' bash "$root/share/bash/extract.sh"

bash --noprofile --norc -c '
  source "$1"
  type man | grep -q "function"
' bash "$root/share/bash/man-colors.sh"

if git show-ref --verify --quiet refs/heads/main || git show-ref --verify --quiet refs/remotes/origin/main; then
  bash --noprofile --norc -c '
    source "$1"
    test "$(git_main_branch)" = main
  ' bash "$root/share/bash/git-helpers.sh"
fi

echo "static ok"
