# shellcheck shell=bash
# Archive extractor, bash equivalent of the Oh My Zsh extract plugin for common formats.
extract() {
  if [[ $# -eq 0 ]]; then
    printf 'usage: extract <archive>\n' >&2
    return 1
  fi
  local file
  for file in "$@"; do
    if [[ ! -f $file ]]; then
      printf 'extract: not a file: %s\n' "$file" >&2
      return 1
    fi
    case $file in
      *.tar.bz2|*.tbz|*.tbz2) tar xjf "$file" ;;
      *.tar.gz|*.tgz) tar xzf "$file" ;;
      *.tar.xz|*.txz) tar xJf "$file" ;;
      *.tar.zst) tar --zstd -xf "$file" ;;
      *.tar.lz) tar --lzip -xf "$file" ;;
      *.tar) tar xf "$file" ;;
      *.bz2) bunzip2 -k "$file" ;;
      *.gz) gunzip -k "$file" ;;
      *.xz) unxz -k "$file" ;;
      *.zst) unzstd "$file" ;;
      *.zip) unzip "$file" ;;
      *.7z) 7z x "$file" ;;
      *.rar) unrar x "$file" ;;
      *.Z) uncompress "$file" ;;
      *) printf 'extract: unknown archive type: %s\n' "$file" >&2; return 1 ;;
    esac
  done
}
