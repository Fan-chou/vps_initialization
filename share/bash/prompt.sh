# shellcheck shell=bash
# Pure-like bash prompt: red path (#FF0000), optional git branch, two lines, ❯
# This is an approximation of sindresorhus/pure, not a source of the zsh theme.

__pureish_git_info() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  local branch dirty=""
  branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null) || return 0
  if ! git diff --quiet --ignore-submodules -- 2>/dev/null || \
     ! git diff --cached --quiet --ignore-submodules -- 2>/dev/null; then
    dirty="*"
  fi
  printf ' %s%s' "$branch" "$dirty"
}

__pureish_prompt() {
  local ex=$?
  local red='\[\e[38;2;255;0;0m\]'
  local muted='\[\e[38;2;128;128;128m\]'
  local rst='\[\e[0m\]'
  local ok='\[\e[35m\]'
  local bad='\[\e[31m\]'
  local charcolor="$ok"
  (( ex != 0 )) && charcolor="$bad"
  local gitinfo
  gitinfo=$(__pureish_git_info)
  PS1="${red}\w${rst}"
  if [[ -n $gitinfo ]]; then
    PS1+="${muted}${gitinfo}${rst}"
  fi
  PS1+=$'\n'"${charcolor}❯${rst} "
  return "$ex"
}

# Prepend so other PROMPT_COMMAND hooks still run; keep our prompt last-ish by appending.
case "${PROMPT_COMMAND-}" in
  *__pureish_prompt*) ;;
  "") PROMPT_COMMAND=__pureish_prompt ;;
  *) PROMPT_COMMAND="${PROMPT_COMMAND%;};__pureish_prompt" ;;
esac
