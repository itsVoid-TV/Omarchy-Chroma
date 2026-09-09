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
expect 'python -m pip uninstall requests' 'python:remove,pip:remove,uninstall:remove'
expect 'uv pip install ruff' 'uv:install,pip:install,install:install'
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
expect 'command -v rm' 'command:inspect,rm:inspect'
expect 'sudo --list rm -rf /' 'sudo:privilege'
expect 'doas -C /etc/doas.conf rm -rf /' 'doas:privilege'
expect 'env -u LANG pacman -S firefox' 'pacman:install,-S:install'
expect 'env --chdir /tmp sudo rm -rf cache' 'sudo:privilege,rm:danger'
expect 'env -S "rm -rf /"' ''
expect 'stdbuf -oL sudo rm -rf cache' 'sudo:privilege,rm:danger'
expect 'ionice -c 3 rsync source target' 'rsync:network'
expect 'ionice -p 1234' ''
expect 'taskset -c 0-3 make test' 'make:build'
expect 'chrt -r 10 shutdown now' 'shutdown:danger'
expect 'time -p pacman -Q' 'pacman:inspect'
expect 'exec -a cleaner rm -rf cache' 'rm:danger'
expect 'systemctl reboot' 'systemctl:danger,reboot:danger'
expect 'git push --force-with-lease origin main' 'git:danger,push:danger'
expect 'git -C /srv/repo push --force origin main' 'git:danger,push:danger'
expect 'git push --delete origin old' 'git:remove,push:remove'
expect 'git branch -D old' 'git:danger,branch:danger'
expect 'git branch -d old' 'git:remove,branch:remove'
expect 'pipx inject poetry plugin' 'pipx:install,inject:install'
expect 'pipx uninject poetry plugin' 'pipx:remove,uninject:remove'
expect 'nix profile install nixpkgs#ripgrep' 'nix:install,profile:install,install:install'
expect 'nix store delete /nix/store/example' 'nix:remove,store:remove,delete:remove'
expect 'type -a rm' 'type:inspect,rm:inspect'
expect 'truncate -s 0 important.db' 'truncate:danger'
expect 'npm --prefix /srv/app install' 'npm:install,install:install'
expect 'kubectl --namespace demo delete pod example' 'kubectl:remove,delete:remove'
expect 'docker --context remote system prune -a' 'docker:remove,prune:remove'

explanation=$(chromarchy::explain 'sudo systemctl reboot')
if [[ $explanation != *'CATEGORY'* || $explanation != *'privilege'* ||
      $explanation != *'danger'* || $explanation != *'systemctl'* ]]; then
  ((tests++))
  printf 'not ok %d - explain output\n  actual: %s\n' "$tests" "$explanation"
  ((failures++))
else
  ((tests++))
  printf 'ok %d - explain output\n' "$tests"
fi

((tests++))
prefix_failure=
for prefix_line in \
  'sudo -u root pacman -Rns package' \
  'env --chdir /tmp stdbuf -oL command -v rm' \
  'timeout --kill-after 2s 5s wget https://example.com' \
  'ionice -c 3 taskset -c 0-3 make test' \
  'chrt --sched-runtime 100 -r 10 systemctl reboot'; do
  for ((prefix_length=0; prefix_length<=${#prefix_line}; prefix_length++)); do
    prefix=${prefix_line:0:prefix_length}
    if ! (set -e; chromarchy::classify_line "$prefix"); then
      prefix_failure=$prefix
      break 2
    fi
  done
done
if [[ $prefix_failure ]]; then
  printf 'not ok %d - every partial command is safe to classify\n  prefix: %q\n' "$tests" "$prefix_failure"
  ((failures++))
else
  printf 'ok %d - every partial command is safe to classify\n' "$tests"
fi

printf '1..%d\n' "$tests"
((failures == 0))
