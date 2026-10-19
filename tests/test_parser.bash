#!/usr/bin/env bash
# shellcheck disable=SC2016 # command examples are literal parser input
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
expect 'docker system prune -a' 'docker:remove,system:remove,prune:remove'
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
expect 'docker --context remote system prune -a' 'docker:remove,system:remove,prune:remove'

# Force options are case sensitive, may be clustered or follow refspecs, and
# option values are data. A leading + forces an individual refspec.
expect 'git push -f origin main' 'git:danger,push:danger'
expect 'git push -fu origin main' 'git:danger,push:danger'
expect 'git push -uf origin main' 'git:danger,push:danger'
expect 'git push origin main -f' 'git:danger,push:danger'
expect 'git push origin +main' 'git:danger,push:danger'
expect 'git push origin +HEAD:main' 'git:danger,push:danger'
expect 'git push --force-if-includes origin main' 'git:vcs,push:vcs'
expect 'git push --no-force origin main' 'git:vcs,push:vcs'
expect 'git push -f --no-force origin main' 'git:vcs,push:vcs'
expect 'git push -f --no-force-with-lease origin main' 'git:danger,push:danger'
expect 'git push --force-with-lease --no-force origin main' 'git:danger,push:danger'
expect 'git push --mirror --no-force origin main' 'git:danger,push:danger'
expect 'git push --force-with-lease --no-force-with-lease origin main' 'git:vcs,push:vcs'
expect 'git push origin main' 'git:vcs,push:vcs'
expect 'git push -u origin main' 'git:vcs,push:vcs'
expect 'git push -o foo origin main' 'git:vcs,push:vcs'
expect 'git push -ofoo origin main' 'git:vcs,push:vcs'
expect 'git push --push-option +foo origin main' 'git:vcs,push:vcs'
expect 'git push --receive-pack -f origin main' 'git:vcs,push:vcs'
expect 'git push -- origin -f' 'git:vcs,push:vcs'
expect 'git push -d origin old' 'git:remove,push:remove'

# Expansions and find placeholders remain words; comments end at a newline.
expect 'echo ${#arr[@]} && rm -rf /tmp/x' 'rm:danger'
expect 'echo ${var#prefix} && rm -rf /tmp/x' 'rm:danger'
expect 'echo ${var:-${#arr[@]}} && rm -rf /tmp/x' 'rm:danger'
expect 'echo "${#arr[@]}" && rm -rf /tmp/x' 'rm:danger'
expect 'echo ${var:-"}"} && rm -rf /tmp/x' 'rm:danger'
expect 'echo ${var:-rm} && git status' 'git:vcs,status:vcs'
expect 'echo "${#arr[@]} && rm -rf /tmp/x"' ''
expect 'echo ${#arr[@]} # rm -rf /tmp/x' ''
expect $'echo ok # ignore rm\nrm -rf /tmp/x' 'rm:danger'
expect $'# comment\nsudo rm -rf /tmp/x' 'sudo:privilege,rm:danger'
expect 'echo word#not-comment && rm -rf /tmp/x' 'rm:danger'
expect 'echo {rm,dd}' ''
expect '{ rm -rf /tmp/x; }' 'rm:danger'

expect 'xargs rm -rf' 'rm:danger'
expect 'xargs -0 -r -n 1 rm -rf' 'rm:danger'
expect 'xargs -rn1 -P2 sudo rm -rf' 'sudo:privilege,rm:danger'
expect 'xargs -I{} rm -rf {}' 'rm:danger'
expect 'xargs -I {} rm -rf {}' 'rm:danger'
expect 'xargs --arg-file files --max-procs 2 -- rm -rf' 'rm:danger'
expect 'xargs --replace rm -rf' 'rm:danger'
expect 'xargs -i rm -rf' 'rm:danger'
expect 'xargs -E rm echo safe' ''
expect 'xargs -I rm echo safe' ''
expect 'xargs --help rm -rf' ''
expect 'xargs --show-limits rm -rf' 'rm:danger'
expect 'xargs echo rm -rf' ''
expect 'find . -exec rm -rf {} \;' 'find:search,rm:danger'
expect 'find . -execdir sudo rm -rf {} +' 'find:search,sudo:privilege,rm:danger'
expect 'find . -ok rm {} \;' 'find:search,rm:danger'
expect 'find . -okdir rm {} \;' 'find:search,rm:danger'
expect 'find . -exec git status \; -exec rm {} +' 'find:search,git:vcs,status:vcs,rm:danger'
expect 'find . -exec echo -delete \;' 'find:search'
expect 'find . -name -delete' 'find:search'
expect 'find . -name -exec rm' 'find:search'
expect 'find . -exec echo rm \;' 'find:search'
expect 'find . -exec echo {} \; -delete' 'find:danger,-delete:danger'
expect 'find . -exec git push origin +main {} +' 'find:search,git:danger,push:danger'

expect 'docker volume rm cache' 'docker:remove,volume:remove,rm:remove'
expect 'docker compose down' 'docker:remove,compose:remove,down:remove'
expect 'docker compose -f compose.yaml down' 'docker:remove,compose:remove,down:remove'
expect 'docker compose --project-name demo --profile dev down' 'docker:remove,compose:remove,down:remove'
expect 'docker container rm demo' 'docker:remove,container:remove,rm:remove'
expect 'podman image rm demo' 'podman:remove,image:remove,rm:remove'
expect 'docker volume ls' 'docker:container,volume:container,ls:container'
expect 'docker compose up' 'docker:container,compose:container,up:container'
expect 'docker run image rm -rf /tmp/x' 'docker:container,run:container'
expect 'docker inspect prune' 'docker:container,inspect:container'
expect 'docker volume inspect delete' 'docker:container,volume:container,inspect:container'

expect 'systemctl --user stop x' 'systemctl:remove,stop:remove'
expect 'systemctl --user --no-pager status x' 'systemctl:system,status:system'
expect 'systemctl --host server stop x' 'systemctl:remove,stop:remove'
expect 'flatpak --user uninstall app' 'flatpak:remove,uninstall:remove'
expect 'kubectl --user admin delete pod example' 'kubectl:remove,delete:remove'

expect 'pacman -Ss firefox' 'pacman:search,-Ss:search'
expect 'pacman -S -s firefox' 'pacman:search,-S:search'
expect 'pacman --sync --search firefox' 'pacman:search,--sync:search'
expect 'pacman -Si firefox' 'pacman:search,-Si:search'
expect 'pacman -Scc' 'pacman:remove,-Scc:remove'
expect 'pacman --sync --clean --clean' 'pacman:remove,--sync:remove'
expect 'pacman -Q' 'pacman:inspect'
expect 'pacman -Sp firefox' 'pacman:inspect'
expect 'pacman -Sw firefox' 'pacman:install,-Sw:install'
expect 'pacman -Swc' 'pacman:remove,-Swc:remove'
expect 'pacman --root /tmp/root -Syu' 'pacman:install,-Syu:install'
expect 'pacman -sS firefox' 'pacman:search,-sS:search'
expect 'npm ci' 'npm:install,ci:install'
expect 'npm --prefix /srv/app ci' 'npm:install,ci:install'
expect 'npm config get ci' 'npm:build,config:build'

expect 'sudo -nu root rm -rf /tmp/x' 'sudo:privilege,rm:danger'
expect 'sudo -nuroot rm -rf /tmp/x' 'sudo:privilege,rm:danger'
expect 'sudo -un rm -rf /tmp/x' 'sudo:privilege,rm:danger'
expect 'sudo -nEu root rm -rf /tmp/x' 'sudo:privilege,rm:danger'
expect 'sudo -nlu root rm -rf /tmp/x' 'sudo:privilege'
expect 'sudo -u rm echo safe' 'sudo:privilege'

# Data named like an action must not turn scripts or branch names into actions.
expect 'python report.py pip uninstall' 'python:build'
expect 'python -c "print(1)" pip uninstall' 'python:build'
expect 'python -m example pip uninstall' 'python:build'
expect 'python -I -m pip uninstall package' 'python:remove,pip:remove,uninstall:remove'
expect 'python -W ignore -m pip install package' 'python:install,pip:install,install:install'
expect 'python -mpip install package' 'python:install,-mpip:install,install:install'
expect 'uv pip uninstall package' 'uv:remove,pip:remove,uninstall:remove'
expect 'uv pip list' 'uv:build,pip:build,list:build'
expect 'git push -f origin delete' 'git:danger,push:danger'
expect 'git push origin delete' 'git:vcs,push:vcs'
expect 'git show delete' 'git:vcs,show:vcs'
expect 'gh repo view delete' 'gh:vcs,repo:vcs'
expect 'gh release delete old' 'gh:remove,delete:remove'

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
  'chrt --sched-runtime 100 -r 10 systemctl reboot' \
  'echo ${var:-${#arr[@]}} && rm -rf /tmp/x' \
  'find . -execdir sudo -nu root rm -rf {} +' \
  'xargs -0rn 1 sudo rm -rf' \
  'git push -uf origin +main' \
  'docker compose -f compose.yaml down'; do
  for ((prefix_length=0; prefix_length<=${#prefix_line}; prefix_length++)); do
    prefix=${prefix_line:0:prefix_length}
    if ! (
      set -e
      chromarchy::classify_line "$prefix" || exit 1
      previous_end=0
      for span in "${!CHROMA_SPAN_START[@]}"; do
        ((CHROMA_SPAN_START[span] >= previous_end &&
          CHROMA_SPAN_START[span] < CHROMA_SPAN_END[span] &&
          CHROMA_SPAN_END[span] <= ${#prefix})) || exit 1
        previous_end=${CHROMA_SPAN_END[span]}
      done
      for token in "${!CHROMA_TOKEN_START[@]}"; do
        ((CHROMA_TOKEN_START[token] < CHROMA_TOKEN_END[token] &&
          CHROMA_TOKEN_END[token] <= ${#prefix})) || exit 1
      done
    ); then
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
