#!/usr/bin/env bash
set -euo pipefail

readonly START_MARKER='# >>> omarchy-chroma >>>'
readonly END_MARKER='# <<< omarchy-chroma <<<'
data_home=${XDG_DATA_HOME:-$HOME/.local/share}
config_home=${XDG_CONFIG_HOME:-$HOME/.config}
install_dir=$data_home/omarchy-chroma
bashrc=${CHROMA_BASHRC:-$HOME/.bashrc}
purge_config=0
temp_file=

cleanup() {
  [[ ! ${temp_file:-} || ! -e $temp_file ]] || rm -f -- "$temp_file"
}
trap cleanup EXIT

while (($#)); do
  case $1 in
    --purge)
      purge_config=1
      shift
      ;;
    --help|-h)
      printf 'Usage: uninstall.sh [--purge]\n'
      exit 0
      ;;
    *)
      printf 'Omarchy Chroma: error: unknown option: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

if [[ -L $bashrc ]]; then
  command -v readlink >/dev/null || {
    printf 'Omarchy Chroma: error: readlink is required for a symlinked .bashrc\n' >&2
    exit 1
  }
  bashrc=$(readlink -f -- "$bashrc") || {
    printf 'Omarchy Chroma: error: could not resolve .bashrc symlink\n' >&2
    exit 1
  }
fi

if [[ -f $bashrc ]]; then
  temp_file=$(mktemp "$(dirname -- "$bashrc")/.omarchy-chroma-bashrc.XXXXXXXX")
  awk -v start="$START_MARKER" -v end="$END_MARKER" '
    $0 == start {
      if (inside) printf "%s", buffered
      inside=1
      buffered=$0 ORS
      next
    }
    inside && $0 == end { inside=0; buffered=""; next }
    inside              { buffered=buffered $0 ORS; next }
    { print }
    END { if (inside) printf "%s", buffered }
  ' "$bashrc" > "$temp_file"
  chmod --reference="$bashrc" "$temp_file" 2>/dev/null || true
  mv -- "$temp_file" "$bashrc"
  temp_file=
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
