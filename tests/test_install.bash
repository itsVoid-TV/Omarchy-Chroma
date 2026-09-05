#!/usr/bin/env bash
set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
fixture=$(mktemp -d "${TMPDIR:-/tmp}/omarchy-chroma-test.XXXXXXXX")
trap 'rm -rf -- "$fixture"' EXIT

export HOME=$fixture/home
export XDG_DATA_HOME=$HOME/.local/share
export XDG_CONFIG_HOME=$HOME/.config
export CHROMA_INSTALL_BLESH=0
mkdir -p "$HOME"
printf '# existing user config\n' > "$HOME/.bashrc"

bash "$root/install.sh" --source "$root" >/dev/null

[[ -r $XDG_DATA_HOME/omarchy-chroma/chromarchy.bash ]]
[[ -r $XDG_CONFIG_HOME/omarchy-chroma/config.bash ]]
[[ $(grep -Fc '# >>> omarchy-chroma >>>' "$HOME/.bashrc") == 1 ]]
grep -Fqx '# existing user config' "$HOME/.bashrc"

printf 'CHROMA_EXTRA_INSTALL_COMMANDS+=(custom-installer)\n' > "$XDG_CONFIG_HOME/omarchy-chroma/config.bash"
bash "$root/install.sh" --source "$root" >/dev/null
[[ $(grep -Fc '# >>> omarchy-chroma >>>' "$HOME/.bashrc") == 1 ]]
grep -Fqx 'CHROMA_EXTRA_INSTALL_COMMANDS+=(custom-installer)' "$XDG_CONFIG_HOME/omarchy-chroma/config.bash"

bash "$XDG_DATA_HOME/omarchy-chroma/uninstall.sh" >/dev/null
[[ ! -e $XDG_DATA_HOME/omarchy-chroma ]]
[[ -r $XDG_CONFIG_HOME/omarchy-chroma/config.bash ]]
! grep -Fq '# >>> omarchy-chroma >>>' "$HOME/.bashrc"
grep -Fqx '# existing user config' "$HOME/.bashrc"

printf 'ok - fresh install, idempotent update, config preservation, uninstall\n'

