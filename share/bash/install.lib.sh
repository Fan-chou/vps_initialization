# shellcheck shell=bash
# Sourced by vps_initialization.sh. Msg_* is set there.

: "${Msg_Info:=}"
: "${Msg_Warning:=}"
: "${Msg_Error:=}"
: "${Msg_Success:=}"

VPS_INIT_BLESH_COMMIT=152942758f567e51fd17bdc7b3783d27b3c476aa
VPS_INIT_BLESH_VERSION_TEXT=0.4.0-devel4+1529427
VPS_INIT_RUPA_Z_COMMIT=d37a763a6a30e1b32766fecc3b8ffd6127f8a0fd
VPS_INIT_RUPA_Z_SHA256=a74bc5976b7dd1adc9efdda3b2b79eaff2bef7d227cf3139959f8df2b89beb72
VPS_INIT_BASH_COMPLETION_VERSION=2.18.0
VPS_INIT_BASH_COMPLETION_SHA256=88bcf85124f77f74f2f2f8bcd16ac4382d807a827ede742a64940c7116aea33f

VPS_MARK_BASH_BEGIN='# >>> vps-initialization bash >>>'
VPS_MARK_BASH_END='# <<< vps-initialization bash <<<'
VPS_MARK_LOGIN_BEGIN='# >>> vps-initialization bash login >>>'
VPS_MARK_LOGIN_END='# <<< vps-initialization bash login <<<'

vps_init_euid() {
  if [[ -n ${VPS_INIT_EUID-} ]]; then
    printf '%s\n' "$VPS_INIT_EUID"
    return 0
  fi
  id -u
}

vps_init_current_user() {
  if [[ -n ${VPS_INIT_CURRENT_USER-} ]]; then
    printf '%s\n' "$VPS_INIT_CURRENT_USER"
    return 0
  fi
  id -un
}

vps_init_lookup_passwd() {
  local user=$1
  if [[ -n ${VPS_INIT_PASSWD_FILE-} ]]; then
    awk -F: -v u="$user" '$1 == u { print; found = 1; exit } END { exit !found }' "$VPS_INIT_PASSWD_FILE"
    return
  fi
  getent passwd "$user"
}

vps_init_accept_home() {
  local home=$1
  [[ $home == /* ]] || return 1
  [[ $home != / ]] || return 1
  [[ $home != *$'\n'* ]] || return 1
}

vps_init_resolve_account() {
  local user euid
  if [[ -n ${VPS_INIT_USER-} ]]; then
    user=$VPS_INIT_USER
  else
    euid=$(vps_init_euid) || return 1
    if [[ $euid == 0 && -n ${SUDO_USER-} && $SUDO_USER != root ]]; then
      user=$SUDO_USER
    else
      user=$(vps_init_current_user) || return 1
    fi
  fi
  [[ -n $user && $user != *$'\n'* ]] || return 1
  local rec home shell
  if ! rec=$(vps_init_lookup_passwd "$user"); then
    echo -e "${Msg_Error}找不到账户 ${user} 的 passwd 记录" >&2
    return 1
  fi
  home=$(printf '%s\n' "$rec" | awk -F: '{ print $6 }')
  shell=$(printf '%s\n' "$rec" | awk -F: '{ print $7 }')
  if [[ -n ${VPS_INIT_HOME-} ]]; then
    home=$VPS_INIT_HOME
  fi
  if [[ -n ${VPS_INIT_LOGIN_SHELL-} ]]; then
    shell=$VPS_INIT_LOGIN_SHELL
  fi
  if ! vps_init_accept_home "$home"; then
    echo -e "${Msg_Error}拒绝使用家目录: ${home}" >&2
    return 1
  fi
  [[ -n $shell && $shell != *$'\n'* ]] || return 1
  if [[ -d $home ]]; then
    home=$(cd -- "$home" && pwd) || return 1
  fi
  VPS_ACCOUNT_USER=$user
  VPS_ACCOUNT_HOME=$home
  VPS_ACCOUNT_SHELL=$shell
}

vps_init_bash_version() {
  if [[ -n ${VPS_INIT_BASH_VERSION-} ]]; then
    printf '%s\n' "$VPS_INIT_BASH_VERSION"
    return 0
  fi
  bash -c 'printf "%s.%s\n" "${BASH_VERSINFO[0]}" "${BASH_VERSINFO[1]}"'
}

vps_init_bash_supported() {
  local ver major
  ver=$(vps_init_bash_version) || return 1
  major=${ver%%.*}
  [[ $major =~ ^[0-9]+$ ]] || return 1
  ((major >= 5))
}

vps_init_login_bash() {
  local shells=/etc/shells candidate
  candidate=$(command -v bash || true)
  if [[ -n $candidate && -f $shells ]] && grep -q -x -F -- "$candidate" "$shells"; then
    printf '%s\n' "$candidate"
    return 0
  fi
  if [[ -x /bin/bash && -f $shells ]] && grep -q -x -F -- /bin/bash "$shells"; then
    printf '%s\n' /bin/bash
    return 0
  fi
  return 1
}

vps_init_chsh() {
  local shell=$1 user=$2
  if [[ ${VPS_INIT_SKIP_CHSH-} == 1 ]]; then
    return 0
  fi
  if [[ -n ${VPS_INIT_CHSH_BIN-} ]]; then
    "$VPS_INIT_CHSH_BIN" -s "$shell" "$user"
    return
  fi
  if [[ -n ${VPS_INIT_HOME-} ]]; then
    echo -e "${Msg_Info}隔离家目录 ${VPS_INIT_HOME}，不调用真正的 chsh。"
    return 0
  fi
  if [[ $(id -un) == "$user" ]]; then
    chsh -s "$shell"
  else
    chsh -s "$shell" "$user"
  fi
}

vps_init_atomic_write() {
  local dest=$1 mode=${2:-644}
  local dir tmp
  dir=$(dirname -- "$dest")
  mkdir -p -- "$dir" || return 1
  tmp=$(mktemp "${dir}/.vps-init.XXXXXX") || return 1
  if ! cat >"$tmp"; then
    rm -f -- "$tmp"
    return 1
  fi
  chmod "$mode" "$tmp" || {
    rm -f -- "$tmp"
    return 1
  }
  if [[ -f $dest ]] && cmp -s -- "$tmp" "$dest"; then
    rm -f -- "$tmp"
    return 0
  fi
  mv -f -- "$tmp" "$dest"
}

vps_init_backup_once() {
  local file=$1
  local home=${VPS_ACCOUNT_HOME-} stamp=${VPS_INIT_BACKUP_STAMP-}
  [[ -n $home && -n $stamp && -f $file ]] || return 0
  local rel dest
  case $file in
    "$home"/*) rel=${file#"$home"/} ;;
    *) rel=$(basename -- "$file") ;;
  esac
  dest="$home/.config/bash/backups/$stamp/$rel"
  mkdir -p -- "$(dirname -- "$dest")" || return 1
  if [[ ! -e $dest ]]; then
    cp -a -- "$file" "$dest" || return 1
  fi
}

vps_init_upsert_block() {
  local file=$1 begin=$2 end=$3 payload=$4
  local dir tmp
  dir=$(dirname -- "$file")
  mkdir -p -- "$dir" || return 1
  tmp=$(mktemp "${dir}/.vps-init.XXXXXX") || return 1
  if [[ -f $file ]] && grep -q -x -F -e "$begin" -- "$file"; then
    if ! grep -q -x -F -e "$end" -- "$file"; then
      rm -f -- "$tmp"
      echo -e "${Msg_Error}标记不完整，未修改 ${file}" >&2
      return 1
    fi
    if ! VPS_BEGIN=$begin VPS_END=$end VPS_PAYLOAD=$payload awk '
      function dump(   line) {
        while ((getline line < ENVIRON["VPS_PAYLOAD"]) > 0) print line
        close(ENVIRON["VPS_PAYLOAD"])
      }
      $0 == ENVIRON["VPS_BEGIN"] {
        print
        dump()
        skip = 1
        next
      }
      $0 == ENVIRON["VPS_END"] {
        skip = 0
        print
        next
      }
      skip != 1 { print }
    ' "$file" >"$tmp"; then
      rm -f -- "$tmp"
      return 1
    fi
  else
    if [[ -f $file ]]; then
      cat -- "$file" >"$tmp" || {
        rm -f -- "$tmp"
        return 1
      }
      if [[ -s $file && $(tail -c 1 -- "$file" | wc -l) -eq 0 ]]; then
        echo >>"$tmp"
      fi
    fi
    {
      printf '%s\n' "$begin"
      cat -- "$payload"
      printf '%s\n' "$end"
    } >>"$tmp" || {
      rm -f -- "$tmp"
      return 1
    }
  fi
  if [[ -f $file ]] && cmp -s -- "$tmp" "$file"; then
    rm -f -- "$tmp"
    return 0
  fi
  if [[ -f $file ]]; then
    chmod --reference="$file" "$tmp" || chmod 644 "$tmp"
    if ! vps_init_backup_once "$file"; then
      rm -f -- "$tmp"
      return 1
    fi
  else
    chmod 644 "$tmp"
  fi
  mv -f -- "$tmp" "$file"
}

vps_init_install_file() {
  local src=$1 dest=$2 mode=$3
  local dir tmp
  dir=$(dirname -- "$dest")
  mkdir -p -- "$dir" || return 1
  tmp=$(mktemp "${dir}/.vps-init.XXXXXX") || return 1
  if ! cp -- "$src" "$tmp"; then
    rm -f -- "$tmp"
    return 1
  fi
  chmod "$mode" "$tmp" || {
    rm -f -- "$tmp"
    return 1
  }
  if [[ -f $dest ]] && cmp -s -- "$tmp" "$dest"; then
    rm -f -- "$tmp"
    return 0
  fi
  mv -f -- "$tmp" "$dest"
}

vps_init_asset_root() {
  if [[ -n ${VPS_INIT_ROOT-} && -f ${VPS_INIT_ROOT}/share/bash/bashrc ]]; then
    printf '%s\n' "$VPS_INIT_ROOT"
    return 0
  fi
  return 1
}

vps_init_stage_asset() {
  local name=$1 dest=$2
  local root
  if root=$(vps_init_asset_root); then
    cp -- "$root/share/bash/$name" "$dest"
    return
  fi
  local url
  url="https://raw.githubusercontent.com/Fan-chou/vps_initialization/${VPS_INIT_REF:-main}/share/bash/$name"
  curl -fsSL -o "$dest" -- "$url"
}

vps_init_login_target() {
  local home=$1
  if [[ -f $home/.bash_profile ]]; then
    printf '%s\n' "$home/.bash_profile"
  elif [[ -f $home/.bash_login ]]; then
    printf '%s\n' "$home/.bash_login"
  elif [[ -f $home/.profile ]]; then
    printf '%s\n' "$home/.profile"
  else
    printf '%s\n' "$home/.bash_profile"
  fi
}

vps_init_install_rc() {
  local home=$1
  local stage name status login
  stage=$(mktemp -d) || return 1
  status=0
  for name in \
    bashrc prompt.sh extract.sh man-colors.sh git-helpers.sh git-aliases.sh \
    history-prefix-unique.sh zsh-history-to-bash.py bashrc-stub.sh login-block.sh
  do
    if ! vps_init_stage_asset "$name" "$stage/$name"; then
      status=1
      break
    fi
  done
  if [[ $status -eq 0 ]]; then
    for name in bashrc prompt.sh extract.sh man-colors.sh git-helpers.sh git-aliases.sh history-prefix-unique.sh; do
      if ! vps_init_install_file "$stage/$name" "$home/.config/bash/$name" 644; then
        status=1
        break
      fi
    done
  fi
  if [[ $status -eq 0 ]]; then
    vps_init_install_file "$stage/zsh-history-to-bash.py" "$home/.config/bash/zsh-history-to-bash.py" 755 || status=1
  fi
  if [[ $status -eq 0 ]]; then
    vps_init_upsert_block "$home/.bashrc" "$VPS_MARK_BASH_BEGIN" "$VPS_MARK_BASH_END" "$stage/bashrc-stub.sh" || status=1
  fi
  if [[ $status -eq 0 ]]; then
    login=$(vps_init_login_target "$home") || status=1
  fi
  if [[ $status -eq 0 ]]; then
    vps_init_upsert_block "$login" "$VPS_MARK_LOGIN_BEGIN" "$VPS_MARK_LOGIN_END" "$stage/login-block.sh" || status=1
  fi
  if [[ $status -eq 0 ]]; then
    printf '%s\n' \
      "blesh=$VPS_INIT_BLESH_COMMIT" \
      "rupa_z=$VPS_INIT_RUPA_Z_COMMIT" \
      "bash_completion=$VPS_INIT_BASH_COMPLETION_VERSION" |
      vps_init_atomic_write "$home/.config/bash/pinned-versions" || status=1
  fi
  rm -rf -- "$stage"
  return "$status"
}

vps_init_record_shell() {
  local home=$1 shell=$2
  local dest="$home/.config/bash/previous-login-shell"
  if [[ -f $dest ]]; then
    return 0
  fi
  printf '%s\n' "$shell" | vps_init_atomic_write "$dest" 600
}

vps_init_give_files() {
  local user=$1 home=$2
  [[ $(id -u) -eq 0 ]] || return 0
  [[ $user != root ]] || return 0
  if ! id -u -- "$user" >/dev/null 2>&1; then
    echo -e "${Msg_Warning}系统里没有账户 ${user}，跳过 chown。"
    return 0
  fi
  local spec path
  spec=$(id -u -- "$user"):$(id -g -- "$user") || return 1
  for path in \
    "$home/.local" \
    "$home/.cache/vps-initialization" \
    "$home/.config/bash" \
    "$home/.bashrc" \
    "$home/.bash_profile" \
    "$home/.bash_login" \
    "$home/.profile"
  do
    [[ -e $path ]] || continue
    chown -R -- "$spec" "$path" || return 1
  done
}

vps_init_require_tools() {
  local missing=0 tool
  for tool in "$@"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      echo -e "${Msg_Error}缺少命令: ${tool}" >&2
      missing=1
    fi
  done
  return "$missing"
}

vps_init_blesh_src_ready() {
  local src=$1 got
  [[ -f $src/contrib/contrib.mk ]] || return 1
  got=$(git -C "$src" rev-parse HEAD 2>/dev/null) || return 1
  [[ $got == "$VPS_INIT_BLESH_COMMIT" ]]
}

vps_init_build_blesh() {
  local home=$1 src=$2
  (
    set -e
    # The build must not write into the operator's home.
    HOME=$home
    export HOME
    export GIT_CONFIG_COUNT=1
    export GIT_CONFIG_KEY_0=safe.directory
    export GIT_CONFIG_VALUE_0='*'
    export GIT_TERMINAL_PROMPT=0
    if ! vps_init_blesh_src_ready "$src"; then
      rm -rf -- "$src"
      mkdir -p -- "$src"
      git -C "$src" init
      git -C "$src" remote add origin https://github.com/akinomyoga/ble.sh.git
      git -C "$src" fetch --depth 1 origin "$VPS_INIT_BLESH_COMMIT"
      git -C "$src" checkout --detach FETCH_HEAD
      git -C "$src" submodule update --init --recursive
    fi
    [[ $(git -C "$src" rev-parse HEAD) == "$VPS_INIT_BLESH_COMMIT" ]]
    make -C "$src" -f GNUmakefile install PREFIX="$home/.local" USE_DOC=no
  )
}

vps_init_install_blesh() {
  local home=$1 cache=$2
  local dest="$home/.local/share/blesh/ble.sh"
  local stamp="$home/.local/share/blesh/.vps-init-commit"
  if [[ -f $dest && -f $stamp ]] && [[ $(<"$stamp") == "$VPS_INIT_BLESH_COMMIT" ]]; then
    grep -q -F -- "$VPS_INIT_BLESH_VERSION_TEXT" "$dest" && return 0
  fi
  local src="$cache/blesh-$VPS_INIT_BLESH_COMMIT"
  [[ $cache == /* && $src == "$cache"/blesh-* ]] || return 1
  vps_init_build_blesh "$home" "$src" || return 1
  [[ -f $dest ]] || return 1
  grep -q -F -- "$VPS_INIT_BLESH_VERSION_TEXT" "$dest" || return 1
  printf '%s\n' "$VPS_INIT_BLESH_COMMIT" | vps_init_atomic_write "$stamp"
}

vps_init_install_rupa_z() {
  local home=$1
  local dest="$home/.local/share/rupa-z/z.sh"
  local stamp="$home/.local/share/rupa-z/.vps-init-commit"
  if [[ -f $dest && -f $stamp ]] && [[ $(<"$stamp") == "$VPS_INIT_RUPA_Z_COMMIT" ]]; then
    printf '%s  %s\n' "$VPS_INIT_RUPA_Z_SHA256" "$dest" | sha256sum -c - >/dev/null && return 0
  fi
  local tmp
  tmp=$(mktemp) || return 1
  if ! curl -fsSL -o "$tmp" -- "https://raw.githubusercontent.com/rupa/z/${VPS_INIT_RUPA_Z_COMMIT}/z.sh"; then
    rm -f -- "$tmp"
    return 1
  fi
  if ! printf '%s  %s\n' "$VPS_INIT_RUPA_Z_SHA256" "$tmp" | sha256sum -c -; then
    rm -f -- "$tmp"
    return 1
  fi
  mkdir -p -- "$(dirname -- "$dest")" || {
    rm -f -- "$tmp"
    return 1
  }
  chmod 644 "$tmp"
  mv -f -- "$tmp" "$dest"
  printf '%s\n' "$VPS_INIT_RUPA_Z_COMMIT" | vps_init_atomic_write "$stamp"
}

vps_init_install_bash_completion() {
  local home=$1 cache=$2
  local dest="$home/.local/share/bash-completion/bash_completion"
  local stamp="$home/.local/share/bash-completion/.vps-init-version"
  local ver=$VPS_INIT_BASH_COMPLETION_VERSION
  if [[ -f $dest && -f $stamp ]] && [[ $(<"$stamp") == "$ver" ]]; then
    return 0
  fi
  local tarball="$cache/bash-completion-$ver.tar.xz"
  local src="$cache/bash-completion-$ver"
  local url="https://github.com/scop/bash-completion/releases/download/${ver}/bash-completion-${ver}.tar.xz"
  [[ $cache == /* && $src == "$cache"/bash-completion-* ]] || return 1
  if ! curl -fsSL -o "$tarball" -- "$url"; then
    return 1
  fi
  if ! printf '%s  %s\n' "$VPS_INIT_BASH_COMPLETION_SHA256" "$tarball" | sha256sum -c -; then
    rm -f -- "$tarball"
    return 1
  fi
  rm -rf -- "$src"
  tar -xJf "$tarball" -C "$cache" || return 1
  mkdir -p -- "$home/.local"
  (
    set -e
    HOME=$home
    export HOME
    cd -- "$src"
    ./configure --prefix="$home/.local"
    make
    make install
  ) || return 1
  [[ -f $dest ]] || return 1
  printf '%s\n' "$ver" | vps_init_atomic_write "$stamp"
}

vps_init_install_deps() {
  local home=$1
  vps_init_require_tools git curl make gawk tar xz sha256sum || return 1
  local cache=${VPS_INIT_SRC_CACHE:-$home/.cache/vps-initialization}
  mkdir -p -- "$cache" || return 1
  vps_init_install_blesh "$home" "$cache" || return 1
  vps_init_install_rupa_z "$home" || return 1
  vps_init_install_bash_completion "$home" "$cache" || return 1
}

vps_init_maybe_chsh() {
  local user=$1 current=$2
  local bash_path base
  if ! bash_path=$(vps_init_login_bash); then
    echo -e "${Msg_Error}在 /etc/shells 里找不到 bash，登录 shell 未改。" >&2
    return 1
  fi
  base=$(basename -- "$current")
  if [[ $base == bash ]]; then
    echo -e "${Msg_Info}账户 ${user} 的登录 shell 已是 ${current}"
    return 0
  fi
  echo -e "${Msg_Info}把账户 ${user} 的登录 shell 从 ${current} 改为 ${bash_path}"
  if ! vps_init_chsh "$bash_path" "$user"; then
    echo -e "${Msg_Error}chsh 失败。登录 shell 仍是 ${current}。" >&2
    return 1
  fi
}

InstallBashInteractive() {
  vps_init_resolve_account || return 1
  local home=$VPS_ACCOUNT_HOME user=$VPS_ACCOUNT_USER shell=$VPS_ACCOUNT_SHELL
  if [[ ! -d $home ]]; then
    echo -e "${Msg_Error}家目录不存在: ${home}" >&2
    return 1
  fi
  if ! vps_init_bash_supported; then
    local ver
    ver=$(vps_init_bash_version || true)
    echo -e "${Msg_Warning}当前 Bash 是 ${ver}。Bash 交互配置需要 Bash 5，已跳过下载、rc 和登录 shell 切换。" >&2
    return 2
  fi
  VPS_INIT_BACKUP_STAMP=$(date -u +%Y%m%dT%H%M%SZ)
  if [[ ${VPS_INIT_SKIP_DOWNLOADS-} == 1 ]]; then
    echo -e "${Msg_Warning}已跳过 ble.sh、rupa/z 和 bash-completion 下载。"
  elif ! vps_init_install_deps "$home"; then
    return 1
  fi
  vps_init_install_rc "$home" || return 1
  vps_init_record_shell "$home" "$shell" || return 1
  vps_init_give_files "$user" "$home" || return 1
  vps_init_maybe_chsh "$user" "$shell" || return 1
  echo -e "${Msg_Success}Bash 交互配置已安装到 ${home}"
}

RollbackBashShell() {
  vps_init_resolve_account || return 1
  local home=$VPS_ACCOUNT_HOME user=$VPS_ACCOUNT_USER
  local record="$home/.config/bash/previous-login-shell"
  if [[ ! -f $record ]]; then
    echo -e "${Msg_Error}没有找到 ${record}，无法回退登录 shell。" >&2
    return 1
  fi
  local saved
  saved=$(head -n 1 -- "$record")
  if [[ -z $saved || ! -x $saved ]]; then
    echo -e "${Msg_Error}记录的 shell 不能执行: ${saved}" >&2
    return 1
  fi
  if [[ $VPS_ACCOUNT_SHELL == "$saved" ]]; then
    echo -e "${Msg_Info}登录 shell 已是 ${saved}"
    return 0
  fi
  echo -e "${Msg_Info}把账户 ${user} 的登录 shell 改回 ${saved}"
  vps_init_chsh "$saved" "$user"
}
