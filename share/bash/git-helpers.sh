# shellcheck shell=bash
# Small bash helpers used by common Oh My Zsh git aliases.
git_current_branch() {
  git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null
}

git_main_branch() {
  local ref
  for ref in refs/heads/main refs/heads/master refs/remotes/origin/main refs/remotes/origin/master refs/remotes/upstream/main refs/remotes/upstream/master; do
    if git show-ref --quiet --verify "$ref" 2>/dev/null; then
      printf '%s\n' "${ref##*/}"
      return 0
    fi
  done
  printf 'main\n'
}

git_develop_branch() {
  local ref
  for ref in refs/heads/develop refs/heads/dev refs/heads/devel refs/remotes/origin/develop refs/remotes/origin/dev; do
    if git show-ref --quiet --verify "$ref" 2>/dev/null; then
      printf '%s\n' "${ref##*/}"
      return 0
    fi
  done
  printf 'develop\n'
}
