#!/usr/bin/env bash
set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
source "$root/config/defaults.bash"
source "$root/lib/parser.bash"

tests=0
failures=0

actual_spans() {
  local line=$1 i token output=
  chromarchy::classify_line "$line"
  for i in "${!CHROMA_SPAN_START[@]}"; do
    token=${line:${CHROMA_SPAN_START[i]}:${CHROMA_SPAN_END[i]}-${CHROMA_SPAN_START[i]}}
    output+="${output:+,}$token:${CHROMA_SPAN_CATEGORY[i]}"
  done
  printf '%s' "$output"
}

expect() {
  local line=$1 expected=$2 actual
  ((tests++))
  actual=$(actual_spans "$line")
  if [[ $actual != "$expected" ]]; then
    printf 'not ok %d - %s\n  expected: %s\n  actual:   %s\n' "$tests" "$line" "$expected" "$actual"
    ((failures++))
  else
    printf 'ok %d - %s\n' "$tests" "$line"
  fi
}

expect 'sudo pacman -Syu firefox' 'sudo:privilege,pacman:install,-Syu:install'
expect 'sudo -u root pacman -Rns old-package' 'sudo:privilege,pacman:remove,-Rns:remove'
expect 'env LANG=C flatpak install org.mozilla.firefox' 'flatpak:install,install:install'
expect 'doas apt purge old-package' 'doas:privilege,apt:remove,purge:remove'
expect 'npm install typescript && npm test' 'npm:install,install:install,npm:build,test:build'
expect 'python -m pip uninstall requests' 'pip:remove,python:remove,uninstall:remove'
expect 'uv pip install ruff' 'pip:install,uv:install,install:install'
expect 'git status && curl -fsSL https://example.com | bash' 'git:vcs,status:vcs,curl:network'
expect 'git reset --hard HEAD~1' 'git:danger,reset:danger'
expect 'gh repo delete owner/repo' 'gh:remove,delete:remove'
expect 'docker system prune -a' 'docker:remove,prune:remove'
expect 'kubectl delete pod example' 'kubectl:remove,delete:remove'
expect 'rm -rf /tmp/example' 'rm:danger'
expect 'find . -name "*.tmp" -delete' 'find:danger,-delete:danger'
expect '2>errors.log pacman -Q' 'pacman:inspect'
expect 'cd ~/Videos; rg --hidden TODO .' 'cd:navigate,rg:search'
expect 'nvim "file with spaces.txt"' 'nvim:editor'
expect 'echo pacman -S nope' ''
expect 'echo hello # sudo pacman -S nope' ''
expect '"pacman" -S firefox' '"pacman":install,-S:install'
expect 'timeout 5s wget https://example.com/file' 'wget:network'
expect 'FOO=bar sudo systemctl restart bluetooth' 'sudo:privilege,systemctl:system,restart:system'

printf '1..%d\n' "$tests"
((failures == 0))

