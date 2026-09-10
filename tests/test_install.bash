#!/usr/bin/env bash
set -euo pipefail

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
[[ -r $XDG_DATA_HOME/omarchy-chroma/lib/theme.bash ]]
[[ -r $XDG_CONFIG_HOME/omarchy-chroma/config.bash ]]
[[ $(grep -Fc '# >>> omarchy-chroma >>>' "$HOME/.bashrc") == 1 ]]
grep -Fqx '# existing user config' "$HOME/.bashrc"

bashrc_before=$(cksum "$HOME/.bashrc")
printf 'CHROMA_EXTRA_INSTALL_COMMANDS+=(custom-installer)\n' > "$XDG_CONFIG_HOME/omarchy-chroma/config.bash"
bash "$root/install.sh" --source "$root" >/dev/null
[[ $(grep -Fc '# >>> omarchy-chroma >>>' "$HOME/.bashrc") == 1 ]]
[[ $(cksum "$HOME/.bashrc") == "$bashrc_before" ]]
grep -Fqx 'CHROMA_EXTRA_INSTALL_COMMANDS+=(custom-installer)' "$XDG_CONFIG_HOME/omarchy-chroma/config.bash"

inline_home=$fixture/inline-home
mkdir -p "$inline_home"
if ! inline_output=$(
  cd -- "$root" || exit
  HOME=$inline_home \
  XDG_DATA_HOME=$inline_home/.local/share \
  XDG_CONFIG_HOME=$inline_home/.config \
  CHROMA_INSTALL_BLESH=0 \
    bash -c "$(<"$root/install.sh")" 2>&1
); then
  printf '%s\n' "$inline_output" >&2
  exit 1
fi
[[ $inline_output != *'unbound variable'* ]]
[[ -r $inline_home/.local/share/omarchy-chroma/lib/theme.bash ]]

if bash "$XDG_DATA_HOME/omarchy-chroma/uninstall.sh" --purge unexpected >/dev/null 2>&1; then
  printf 'uninstaller accepted an unexpected argument\n' >&2
  exit 1
fi
[[ -r $XDG_DATA_HOME/omarchy-chroma/chromarchy.bash ]]
[[ -r $XDG_CONFIG_HOME/omarchy-chroma/config.bash ]]

bash "$XDG_DATA_HOME/omarchy-chroma/uninstall.sh" >/dev/null
[[ ! -e $XDG_DATA_HOME/omarchy-chroma ]]
[[ -r $XDG_CONFIG_HOME/omarchy-chroma/config.bash ]]
if grep -Fq '# >>> omarchy-chroma >>>' "$HOME/.bashrc"; then
  printf 'uninstaller left a managed Bash loader behind\n' >&2
  exit 1
fi
grep -Fqx '# existing user config' "$HOME/.bashrc"

# shellcheck disable=SC2030,SC2031 # each fixture intentionally has a subshell-local HOME
(
  export HOME=$fixture/malformed-home
  export XDG_DATA_HOME=$HOME/.local/share
  export XDG_CONFIG_HOME=$HOME/.config
  export CHROMA_INSTALL_BLESH=0
  mkdir -p "$HOME"
  printf '%s\n' \
    '# before malformed marker' \
    '# >>> omarchy-chroma >>>' \
    '# user data after malformed marker' \
    'export KEEP_THIS=1' > "$HOME/.bashrc"

  malformed_output=$(bash "$root/install.sh" --source "$root")
  [[ $malformed_output == *'unmatched Chroma marker'* ]]
  bash "$root/install.sh" --source "$root" >/dev/null
  [[ $(grep -Fc '# >>> omarchy-chroma >>>' "$HOME/.bashrc") == 2 ]]
  [[ $(grep -Fc '# <<< omarchy-chroma <<<' "$HOME/.bashrc") == 1 ]]
  grep -Fqx 'export KEEP_THIS=1' "$HOME/.bashrc"

  bash "$XDG_DATA_HOME/omarchy-chroma/uninstall.sh" >/dev/null
  grep -Fqx '# before malformed marker' "$HOME/.bashrc"
  grep -Fqx '# user data after malformed marker' "$HOME/.bashrc"
  grep -Fqx 'export KEEP_THIS=1' "$HOME/.bashrc"
  [[ $(grep -Fc '# >>> omarchy-chroma >>>' "$HOME/.bashrc") == 1 ]]
)

# shellcheck disable=SC2030,SC2031 # each fixture intentionally has a subshell-local HOME
(
  export HOME=$fixture/duplicate-home
  export XDG_DATA_HOME=$HOME/.local/share
  export XDG_CONFIG_HOME=$HOME/.config
  export CHROMA_INSTALL_BLESH=0
  mkdir -p "$HOME"
  printf '%s\n' \
    '# >>> omarchy-chroma >>>' \
    'old loader one' \
    '# <<< omarchy-chroma <<<' \
    '# keep between blocks' \
    '# >>> omarchy-chroma >>>' \
    'old loader two' \
    '# <<< omarchy-chroma <<<' > "$HOME/.bashrc"

  bash "$root/install.sh" --source "$root" >/dev/null
  [[ $(grep -Fc '# >>> omarchy-chroma >>>' "$HOME/.bashrc") == 1 ]]
  [[ $(grep -Fc '# <<< omarchy-chroma <<<' "$HOME/.bashrc") == 1 ]]
  grep -Fqx '# keep between blocks' "$HOME/.bashrc"
  ! grep -Fq 'old loader' "$HOME/.bashrc"
)

# shellcheck disable=SC2030,SC2031 # each fixture intentionally has a subshell-local HOME
(
  export HOME=$fixture/transaction-home
  export XDG_DATA_HOME=$HOME/.local/share
  export XDG_CONFIG_HOME=$HOME/.config
  export CHROMA_INSTALL_BLESH=0
  mkdir -p "$HOME" "$fixture/incomplete-source"
  printf '# incomplete source\n' > "$fixture/incomplete-source/chromarchy.bash"

  bash "$root/install.sh" --source "$root" >/dev/null
  before=$(cksum "$XDG_DATA_HOME/omarchy-chroma/chromarchy.bash")
  if bash "$root/install.sh" --source "$fixture/incomplete-source" >/dev/null 2>&1; then
    printf 'incomplete source unexpectedly replaced a working install\n' >&2
    exit 1
  fi
  after=$(cksum "$XDG_DATA_HOME/omarchy-chroma/chromarchy.bash")
  [[ $before == "$after" ]]
)

# shellcheck disable=SC2030,SC2031 # each fixture intentionally has a subshell-local HOME
(
  export HOME=$fixture/symlink-home
  export XDG_DATA_HOME=$HOME/.local/share
  export XDG_CONFIG_HOME=$HOME/.config
  export CHROMA_INSTALL_BLESH=0
  mkdir -p "$HOME/shell"
  printf '# symlinked user config\n' > "$HOME/shell/bashrc"
  ln -s shell/bashrc "$HOME/.bashrc"

  bash "$root/install.sh" --source "$root" >/dev/null
  [[ -L $HOME/.bashrc ]]
  grep -Fqx '# symlinked user config' "$HOME/shell/bashrc"
  grep -Fqx '# >>> omarchy-chroma >>>' "$HOME/shell/bashrc"
  bash "$XDG_DATA_HOME/omarchy-chroma/uninstall.sh" >/dev/null
  [[ -L $HOME/.bashrc ]]
  grep -Fqx '# symlinked user config' "$HOME/shell/bashrc"
  ! grep -Fq '# >>> omarchy-chroma >>>' "$HOME/shell/bashrc"
)

printf 'ok - safe fresh/update/inline install, rollback, marker repair, symlink and uninstall paths\n'
