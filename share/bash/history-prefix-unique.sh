# shellcheck shell=bash
# shellcheck disable=SC2154
# Unique prefix history navigation for ble.sh Up/Down.
# Official history-search / nsearch has no unique option and, on first Up,
# lands on the same latest prefix match already shown as a gray suggestion.
# This is a thin walker over ble history APIs, not a custom line editor.

function ble/widget/history-prefix-unique/.reset {
  _ble_hu_active=
  _ble_hu_needle=
  _ble_hu_orig=
  _ble_hu_orig_ind=0
  _ble_hu_current=
  _ble_hu_index=
  _ble_hu_stack=()
  unset -v _ble_hu_seen
  declare -gA _ble_hu_seen=()
}

function ble/widget/history-prefix-unique/.in-session {
  [[ ${_ble_hu_active-} ]] || return 1
  [[ $_ble_edit_str == "$_ble_hu_orig" || $_ble_edit_str == "$_ble_hu_current" ]]
}

function ble/widget/history-prefix-unique/.mark-seen {
  local line=$1
  _ble_hu_seen[$line]=1
}

function ble/widget/history-prefix-unique/.show {
  local index=$1 line=$2
  ble-edit/content/reset-and-check-dirty "$line"
  _ble_edit_ind=${#line}
  _ble_edit_mark=0
  _ble_edit_mark_active=
  _ble_hu_current=$line
  _ble_hu_index=$index
}

function ble/widget/history-prefix-unique/.init {
  ble/history/initialize
  ble/widget/history-prefix-unique/.reset
  _ble_hu_active=1

  local skip=
  if [[ $_ble_decode_keymap == auto_complete ]]; then
    skip=$_ble_edit_str
    _ble_hu_needle=${_ble_edit_str::_ble_edit_ind}
    _ble_hu_orig=$_ble_hu_needle
    _ble_hu_orig_ind=$_ble_edit_ind
    ble/widget/auto_complete/cancel
  else
    _ble_hu_needle=${_ble_edit_str::_ble_edit_ind}
    _ble_hu_orig=$_ble_edit_str
    _ble_hu_orig_ind=$_ble_edit_ind
  fi
  _ble_hu_current=$_ble_hu_orig

  [[ $skip ]] && ble/widget/history-prefix-unique/.mark-seen "$skip"

  # From a proper prefix (e.g. "l"), the latest matching history entry is
  # already the gray suggestion (or would be).  Do not land on it first.
  if [[ $_ble_hu_orig == "$_ble_hu_needle" && $_ble_hu_needle ]]; then
    local count line
    ble/history/get-count -v count
    local i
    for ((i=count-1; i>=0; i--)); do
      ble/history/get-edited-entry -v line "$i"
      if [[ $line == "$_ble_hu_needle"* ]]; then
        ble/widget/history-prefix-unique/.mark-seen "$line"
        break
      fi
    done
  elif [[ $_ble_hu_orig != "$_ble_hu_needle" && $_ble_hu_orig ]]; then
    ble/widget/history-prefix-unique/.mark-seen "$_ble_hu_orig"
  fi

  local count
  ble/history/get-count -v count
  _ble_hu_index=$count
}

function ble/widget/history-prefix-unique/.search {
  local dir=$1
  local count line i
  ble/history/get-count -v count
  if [[ $dir == backward ]]; then
    local start=$((_ble_hu_index-1))
    for ((i=start; i>=0; i--)); do
      ble/history/get-edited-entry -v line "$i"
      [[ $line == "$_ble_hu_needle"* ]] || continue
      [[ ${_ble_hu_seen[$line]-} ]] && continue
      ble/widget/history-prefix-unique/.mark-seen "$line"
      ble/array#push _ble_hu_stack "$i"
      ble/widget/history-prefix-unique/.show "$i" "$line"
      return 0
    done
    ble/widget/.bell
    return 1
  fi

  # forward: unwind uniquely, then restore the original input
  if ((${#_ble_hu_stack[@]})); then
    local ret
    ble/array#pop _ble_hu_stack
    local leaving=$ret left=
    ble/history/get-edited-entry -v left "$leaving"
    unset -v "_ble_hu_seen[$left]"
    if ((${#_ble_hu_stack[@]})); then
      local rec=${_ble_hu_stack[${#_ble_hu_stack[@]}-1]} line=
      ble/history/get-edited-entry -v line "$rec"
      ble/widget/history-prefix-unique/.show "$rec" "$line"
    else
      ble/widget/history-prefix-unique/.show "$count" "$_ble_hu_orig"
      _ble_edit_ind=$_ble_hu_orig_ind
      _ble_hu_current=$_ble_hu_orig
      _ble_hu_index=$count
      _ble_hu_active=
      unset -v _ble_hu_seen
      declare -gA _ble_hu_seen=()
    fi
    return 0
  fi
  ble/widget/.bell
  return 1
}

function ble/widget/history-prefix-unique-backward {
  ble/widget/history-prefix-unique/.in-session ||
    ble/widget/history-prefix-unique/.init
  ble/widget/history-prefix-unique/.search backward
}

function ble/widget/history-prefix-unique-forward {
  ble/widget/history-prefix-unique/.in-session || return 0
  ble/widget/history-prefix-unique/.search forward
}

ble-bind -f up   history-prefix-unique-backward
ble-bind -f down history-prefix-unique-forward
ble-bind -m auto_complete -f up   history-prefix-unique-backward
ble-bind -m auto_complete -f down history-prefix-unique-forward
