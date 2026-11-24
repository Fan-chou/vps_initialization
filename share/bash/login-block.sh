# shellcheck shell=bash
if [ -n "${BASH_VERSION:-}" ]; then
  case ":${PATH}:" in
    *":${HOME}/.local/bin:"*) ;;
    *) PATH="${HOME}/.local/bin:${PATH}" ;;
  esac
  export PATH
  if [ -f "${HOME}/.bashrc" ]; then
    # shellcheck disable=SC1091
    . "${HOME}/.bashrc"
  fi
fi
