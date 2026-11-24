# shellcheck shell=bash
# colored man pages (bash equivalent of OMZ colored-man-pages)
man() {
  local -x GROFF_NO_SGR=1
  local -x PAGER="${PAGER:-less}"
  local -x LESS_TERMCAP_mb=$'\e[1;31m'
  local -x LESS_TERMCAP_md=$'\e[1;31m'
  local -x LESS_TERMCAP_me=$'\e[0m'
  local -x LESS_TERMCAP_so=$'\e[1;33;44m'
  local -x LESS_TERMCAP_se=$'\e[0m'
  local -x LESS_TERMCAP_us=$'\e[1;32m'
  local -x LESS_TERMCAP_ue=$'\e[0m'
  command man "$@"
}
