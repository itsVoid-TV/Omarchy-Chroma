#!/usr/bin/env bash
set -euo pipefail

readonly START_MARKER='# >>> omarchy-chroma >>>'
readonly END_MARKER='# <<< omarchy-chroma <<<'
data_home=${XDG_DATA_HOME:-$HOME/.local/share}
config_home=${XDG_CONFIG_HOME:-$HOME/.config}
install_dir=$data_home/omarchy-chroma
bashrc=${CHROMA_BASHRC:-$HOME/.bashrc}
purge_config=0

if [[ ${1:-} == --purge ]]; then
  purge_config=1
elif [[ ${1:-} == --help || ${1:-} == -h ]]; then
  printf 'Usage: uninstall.sh [--purge]\n'
  exit 0
elif (($#)); then
  printf 'Omarchy Chroma: error: unknown option: %s\n' "$1" >&2
  exit 2
fi

if [[ -f $bashrc ]]; then
  temp_file=$(mktemp "${TMPDIR:-/tmp}/omarchy-chroma-bashrc.XXXXXXXX")
  awk -v start="$START_MARKER" -v end="$END_MARKER" '
    $0 == start { skipping=1; next }
    $0 == end   { skipping=0; next }
    !skipping   { print }
  ' "$bashrc" > "$temp_file"
  chmod --reference="$bashrc" "$temp_file" 2>/dev/null || true
  mv -- "$temp_file" "$bashrc"
fi

case $install_dir in
  */omarchy-chroma) [[ ! -d $install_dir ]] || rm -rf -- "$install_dir" ;;
  *) printf 'Omarchy Chroma: refusing unsafe install path: %s\n' "$install_dir" >&2; exit 1 ;;
esac

if ((purge_config)); then
  case $config_home/omarchy-chroma in
    */omarchy-chroma) rm -rf -- "$config_home/omarchy-chroma" ;;
  esac
fi

printf 'Omarchy Chroma: uninstalled. ble.sh was kept because other shell add-ons may use it.\n'

