#!/usr/bin/env bash
# The inner bash -c strings are for the temporary shell, not this script.
# shellcheck disable=SC2016
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck disable=SC1091
source "$root/vps_initialization.sh"

fail() {
  printf 'FAIL %s\n' "$*" >&2
  exit 1
}

reset_env() {
  unset VPS_INIT_USER VPS_INIT_HOME VPS_INIT_PASSWD_FILE VPS_INIT_LOGIN_SHELL
  unset VPS_INIT_EUID VPS_INIT_CURRENT_USER VPS_INIT_SKIP_CHSH VPS_INIT_SKIP_DOWNLOADS
  unset VPS_INIT_CHSH_BIN VPS_INIT_BASH_VERSION VPS_INIT_BACKUP_STAMP
  unset VPS_ACCOUNT_USER VPS_ACCOUNT_HOME VPS_ACCOUNT_SHELL
  unset SUDO_USER
}

passwd=$(mktemp)
cat >"$passwd" <<'EOF'
root:x:0:0:root:/var/lib/adminhome:/bin/bash
alice:x:1001:1001:Alice:/home/alice:/usr/bin/zsh
bob:x:1002:1002:Bob:/srv/bob:/bin/bash
tester:x:1000:1000:Tester:/nonexistent/tester:/bin/zsh
EOF

reset_env
export VPS_INIT_PASSWD_FILE=$passwd
export VPS_INIT_EUID=0
export VPS_INIT_CURRENT_USER=root
export SUDO_USER=alice
vps_init_resolve_account
[[ $VPS_ACCOUNT_USER == alice ]] || fail "sudo user was ignored"
[[ $VPS_ACCOUNT_HOME == /home/alice ]] || fail "sudo home $VPS_ACCOUNT_HOME"
[[ $VPS_ACCOUNT_SHELL == /usr/bin/zsh ]] || fail "sudo shell $VPS_ACCOUNT_SHELL"

reset_env
export VPS_INIT_PASSWD_FILE=$passwd
export VPS_INIT_EUID=0
export VPS_INIT_CURRENT_USER=root
vps_init_resolve_account
[[ $VPS_ACCOUNT_USER == root ]] || fail "root user $VPS_ACCOUNT_USER"
[[ $VPS_ACCOUNT_HOME == /var/lib/adminhome ]] || fail "root home was rewritten to $VPS_ACCOUNT_HOME"

reset_env
export VPS_INIT_PASSWD_FILE=$passwd
export VPS_INIT_EUID=0
export VPS_INIT_CURRENT_USER=root
export SUDO_USER=alice
export VPS_INIT_USER=bob
vps_init_resolve_account
[[ $VPS_ACCOUNT_USER == bob ]] || fail "explicit user lost"
[[ $VPS_ACCOUNT_HOME == /srv/bob ]] || fail "explicit home $VPS_ACCOUNT_HOME"

reset_env
export VPS_INIT_PASSWD_FILE=$passwd
export VPS_INIT_EUID=1000
export VPS_INIT_CURRENT_USER=alice
export SUDO_USER=bob
vps_init_resolve_account
[[ $VPS_ACCOUNT_USER == alice ]] || fail "non-root followed SUDO_USER ($VPS_ACCOUNT_USER)"

reset_env
export VPS_INIT_PASSWD_FILE=$passwd
export VPS_INIT_USER=tester
export VPS_INIT_HOME=/
if vps_init_resolve_account; then
  fail "accepted / as home"
fi
export VPS_INIT_HOME=relative/home
if vps_init_resolve_account; then
  fail "accepted a relative home"
fi

VPS_INIT_BASH_VERSION=5.2
vps_init_bash_supported || fail "5.2 should pass"
VPS_INIT_BASH_VERSION=5.0
vps_init_bash_supported || fail "5.0 should pass"
VPS_INIT_BASH_VERSION=4.4
if vps_init_bash_supported; then
  fail "4.4 should fail"
fi
VPS_INIT_BASH_VERSION=3.2
if vps_init_bash_supported; then
  fail "3.2 should fail"
fi

install_env() {
  local home=$1
  reset_env
  export VPS_INIT_PASSWD_FILE=$passwd
  export VPS_INIT_USER=tester
  export VPS_INIT_HOME=$home
  export VPS_INIT_LOGIN_SHELL=/bin/zsh
  export VPS_INIT_SKIP_DOWNLOADS=1
  export VPS_INIT_SKIP_CHSH=1
}

home=$(mktemp -d)
printf 'echo keep-me\n' >"$home/.bashrc"
printf 'profile-keep\n' >"$home/.profile"
printf 'zsh-secret\n' >"$home/.zsh_history"
printf 'bash-secret\n' >"$home/.bash_history"
install_env "$home"
InstallBashInteractive

grep -q 'echo keep-me' "$home/.bashrc" || fail "custom bashrc lost"
[[ $(grep -c -x -F '# >>> vps-initialization bash >>>' "$home/.bashrc") -eq 1 ]] || fail "bashrc marker count"
grep -q 'profile-keep' "$home/.profile" || fail "profile lost"
[[ $(grep -c -x -F '# >>> vps-initialization bash login >>>' "$home/.profile") -eq 1 ]] || fail "profile marker count"
[[ ! -e $home/.bash_profile ]] || fail "bash_profile shadowed profile"
cmp -s <(printf 'zsh-secret\n') "$home/.zsh_history" || fail "zsh history changed"
cmp -s <(printf 'bash-secret\n') "$home/.bash_history" || fail "bash history changed"
[[ -f $home/.config/bash/history-prefix-unique.sh ]] || fail "history adapter missing"
[[ -f $home/.config/bash/previous-login-shell ]] || fail "shell record missing"
[[ $(head -n 1 "$home/.config/bash/previous-login-shell") == /bin/zsh ]] || fail "recorded shell"
[[ -x $home/.config/bash/zsh-history-to-bash.py ]] || fail "converter not installed"
backup=$(find "$home/.config/bash/backups" -name '.bashrc' -type f)
[[ -n $backup ]] || fail "bashrc was not backed up"
grep -q 'echo keep-me' "$backup" || fail "backup is not the old bashrc"
grep -q 'profile-keep' "$(find "$home/.config/bash/backups" -name '.profile' -type f)" || fail "profile backup"

before=$(cksum "$home/.bashrc" "$home/.profile")
backup_count=$(find "$home/.config/bash/backups" -type f | wc -l)
InstallBashInteractive
after=$(cksum "$home/.bashrc" "$home/.profile")
[[ $before == "$after" ]] || fail "second install changed rc"
[[ $(find "$home/.config/bash/backups" -type f | wc -l) -eq $backup_count ]] || fail "second install added a backup"
[[ $(grep -c -x -F '# >>> vps-initialization bash >>>' "$home/.bashrc") -eq 1 ]] || fail "marker duplicated"
printf 'echo local-keep\n' >"$home/.config/bash/local.sh"
InstallBashInteractive
grep -q 'echo local-keep' "$home/.config/bash/local.sh" || fail "local.sh overwritten"

got=$(
  env -i HOME="$home" PATH="$PATH" TERM=dumb \
    bash --noprofile --rcfile "$home/.bashrc" -ic 'printf %s "$HISTSIZE"' | tail -n 1
)
[[ $got == 50000 ]] || fail "HISTSIZE=$got"
env -i HOME="$home" PATH="$PATH" TERM=dumb \
  bash --noprofile --rcfile "$home/.bashrc" -ic 'shopt -q histappend' || fail "histappend"
got=$(
  env -i HOME="$home" PATH="$PATH" TERM=dumb \
    bash --noprofile --rcfile "$home/.bashrc" -ic 'printf %s "$HISTFILESIZE"' | tail -n 1
)
[[ $got == 50000 ]] || fail "HISTFILESIZE=$got"
got=$(
  env -i HOME="$home" PATH="$PATH" TERM=dumb \
    bash --noprofile --rcfile "$home/.bashrc" -ic 'printf %s "$HISTFILE"' | tail -n 1
)
[[ $got == "$home/.bash_history" ]] || fail "HISTFILE=$got"
env -i HOME="$home" PATH=/usr/bin:/bin \
  bash --noprofile --norc -c 'source "$HOME/.config/bash/bashrc"; case ":$PATH:" in *":$HOME/.local/bin:"*) exit 0;; *) exit 1;; esac' \
  || fail "noninteractive PATH"
env -i HOME="$home" PATH="$PATH" TERM=dumb \
  bash --noprofile --rcfile "$home/.bashrc" -ic 'source "$HOME/.bashrc"; printf ok' >/dev/null \
  || fail "second source failed"

fresh=$(mktemp -d)
install_env "$fresh"
InstallBashInteractive
[[ -f $fresh/.bash_profile ]] || fail "missing bash_profile"
[[ ! -e $fresh/.profile ]] || fail "unexpected profile"
[[ $(grep -c -x -F '# >>> vps-initialization bash login >>>' "$fresh/.bash_profile") -eq 1 ]]

old=$(mktemp -d)
install_env "$old"
export VPS_INIT_BASH_VERSION=4.2
set +e
InstallBashInteractive
old_status=$?
set -e
[[ $old_status -eq 2 ]] || fail "old bash status $old_status"
[[ ! -e $old/.bashrc ]] || fail "old bash wrote bashrc"
[[ ! -e $old/.config/bash/bashrc ]] || fail "old bash wrote managed bashrc"

locked=$(mktemp -d)
install_env "$locked"
unset VPS_INIT_BASH_VERSION
chmod a-w "$locked"
set +e
InstallBashInteractive
locked_status=$?
set -e
chmod u+w "$locked"
[[ $locked_status -ne 0 ]] || fail "unwritable home succeeded"

broken=$(mktemp -d)
printf '%s\n' '# >>> vps-initialization bash >>>' 'partial' >"$broken/.bashrc"
sum_before=$(cksum "$broken/.bashrc")
install_env "$broken"
set +e
InstallBashInteractive
broken_status=$?
set -e
[[ $broken_status -ne 0 ]] || fail "broken marker succeeded"
[[ $(cksum "$broken/.bashrc") == "$sum_before" ]] || fail "broken bashrc was edited"

chsh_home=$(mktemp -d)
cat >"$chsh_home/chsh" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$CHSH_LOG"
exit 1
EOF
chmod +x "$chsh_home/chsh"
install_env "$chsh_home"
unset VPS_INIT_SKIP_CHSH
export VPS_INIT_CHSH_BIN=$chsh_home/chsh
export CHSH_LOG=$chsh_home/log
set +e
InstallBashInteractive
chsh_status=$?
set -e
[[ $chsh_status -ne 0 ]] || fail "failing chsh returned success"
[[ -f $chsh_home/.bashrc ]] || fail "rc missing after chsh failure"
[[ $(head -n 1 "$chsh_home/.config/bash/previous-login-shell") == /bin/zsh ]] || fail "record missing after chsh failure"
grep -q -- '-s' "$chsh_home/log" || fail "chsh was not invoked"
grep -q -- 'tester' "$chsh_home/log" || fail "chsh user"
grep -q -E -- '-s (/usr/bin/bash|/bin/bash) tester' "$chsh_home/log" || fail "chsh args $(cat "$chsh_home/log")"

already=$(mktemp -d)
: >"$already/log"
install_env "$already"
unset VPS_INIT_SKIP_CHSH
export VPS_INIT_LOGIN_SHELL=/bin/bash
export VPS_INIT_CHSH_BIN=$chsh_home/chsh
export CHSH_LOG=$already/log
InstallBashInteractive
[[ ! -s $already/log ]] || fail "chsh ran for an account already on bash"

rollback_home=$(mktemp -d)
install_env "$rollback_home"
export VPS_INIT_LOGIN_SHELL=/usr/bin/rbash
InstallBashInteractive
printf '%s\n' /bin/bash >"$rollback_home/.config/bash/previous-login-shell"
cat >"$rollback_home/chsh" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$CHSH_LOG"
exit 0
EOF
chmod +x "$rollback_home/chsh"
unset VPS_INIT_SKIP_CHSH
export VPS_INIT_CHSH_BIN=$rollback_home/chsh
export CHSH_LOG=$rollback_home/called
RollbackBashShell
grep -q -- '-s /bin/bash tester' "$rollback_home/called" || fail "rollback args $(cat "$rollback_home/called")"

missing_record=$(mktemp -d)
install_env "$missing_record"
export VPS_INIT_LOGIN_SHELL=/bin/bash
InstallBashInteractive
rm -f -- "$missing_record/.config/bash/previous-login-shell"
set +e
RollbackBashShell
missing_status=$?
set -e
[[ $missing_status -ne 0 ]] || fail "rollback without a record succeeded"

isolated=$(mktemp -d)
mkdir -p "$isolated/bin"
cat >"$isolated/bin/chsh" <<'EOF'
#!/bin/sh
echo called >"$ISOLATED_MARK"
exit 99
EOF
chmod +x "$isolated/bin/chsh"
install_env "$isolated"
export VPS_INIT_LOGIN_SHELL=/bin/zsh
unset VPS_INIT_SKIP_CHSH
unset VPS_INIT_CHSH_BIN
export ISOLATED_MARK=$isolated/called
PATH="$isolated/bin:$PATH" InstallBashInteractive
[[ ! -e $isolated/called ]] || fail "isolated install called real chsh"

echo "install ok"
