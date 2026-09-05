#!/usr/bin/env bash
set -euo pipefail

readonly CHROMA_REPOSITORY='https://github.com/itsVoid-TV/omarchy-chroma.git'
readonly BLESH_URL='https://github.com/akinomyoga/ble.sh/releases/download/nightly/ble-nightly-20260818%2B63c23e9.tar.xz'
readonly BLESH_SHA256='f033df78cbe6017b2bc8286852f9e4edd18fbddf0025faf19967726e06577189'
readonly START_MARKER='# >>> omarchy-chroma >>>'
readonly END_MARKER='# <<< omarchy-chroma <<<'

data_home=${XDG_DATA_HOME:-$HOME/.local/share}
config_home=${XDG_CONFIG_HOME:-$HOME/.config}
install_dir=$data_home/omarchy-chroma
bashrc=${CHROMA_BASHRC:-$HOME/.bashrc}
source_dir=
temp_dir=

cleanup() {
  [[ ! ${temp_dir:-} || ! -d $temp_dir ]] || rm -rf -- "$temp_dir"
}
trap cleanup EXIT

say() { printf 'Omarchy Chroma: %s\n' "$*"; }
die() { printf 'Omarchy Chroma: error: %s\n' "$*" >&2; exit 1; }

while (($#)); do
  case $1 in
    --source)
      (($# >= 2)) || die '--source needs a directory'
      source_dir=$2
      shift 2
      ;;
    --no-blesh)
      CHROMA_INSTALL_BLESH=0
      shift
      ;;
    --help|-h)
      printf 'Usage: install.sh [--source DIR] [--no-blesh]\n'
      exit 0
      ;;
    *) die "unknown option: $1" ;;
  esac
done

[[ ${BASH_VERSINFO[0]} -gt 4 || ${BASH_VERSINFO[0]} -eq 4 && ${BASH_VERSINFO[1]} -ge 4 ]] ||
  die 'Bash 4.4 or newer is required'
command -v git >/dev/null || die 'git is required'

if [[ ! $source_dir ]]; then
  if [[ ${BASH_SOURCE[0]:-} ]]; then
    if ! script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P); then
      script_dir=
    fi
  else
    # `bash -c "$(curl ...)"` has no BASH_SOURCE entry. Checking PWD first
    # retains local-checkout behavior without tripping nounset.
    script_dir=$PWD
  fi
  if [[ -r $script_dir/chromarchy.bash && -r $script_dir/lib/parser.bash ]]; then
    source_dir=$script_dir
  else
    temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/omarchy-chroma.XXXXXXXX")
    say 'downloading the repository...'
    git clone --depth 1 --quiet "$CHROMA_REPOSITORY" "$temp_dir/repository"
    source_dir=$temp_dir/repository
  fi
fi

[[ -r $source_dir/chromarchy.bash && -r $source_dir/lib/parser.bash &&
   -r $source_dir/lib/theme.bash ]] ||
  die "invalid source directory: $source_dir"

mkdir -p -- "$install_dir/config" "$install_dir/lib" "$config_home/omarchy-chroma"
install -m 0644 "$source_dir/chromarchy.bash" "$install_dir/chromarchy.bash"
install -m 0644 "$source_dir/config/defaults.bash" "$install_dir/config/defaults.bash"
install -m 0644 "$source_dir/lib/parser.bash" "$install_dir/lib/parser.bash"
install -m 0644 "$source_dir/lib/layer.bash" "$install_dir/lib/layer.bash"
install -m 0644 "$source_dir/lib/theme.bash" "$install_dir/lib/theme.bash"
install -m 0755 "$source_dir/uninstall.sh" "$install_dir/uninstall.sh"

if [[ ! -e $config_home/omarchy-chroma/config.bash ]]; then
  install -m 0644 "$source_dir/config/config.example.bash" "$config_home/omarchy-chroma/config.bash"
fi

if [[ ${CHROMA_INSTALL_BLESH:-1} != 0 && ! -r $data_home/blesh/ble.sh && ! -r /usr/share/blesh/ble.sh ]]; then
  command -v curl >/dev/null || die 'curl is required to install ble.sh'
  command -v sha256sum >/dev/null || die 'sha256sum is required to verify ble.sh'
  command -v tar >/dev/null || die 'tar is required to install ble.sh'
  [[ $temp_dir ]] || temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/omarchy-chroma.XXXXXXXX")
  say 'downloading the pinned ble.sh build...'
  curl --fail --location --silent --show-error "$BLESH_URL" --output "$temp_dir/blesh.tar.xz"
  printf '%s  %s\n' "$BLESH_SHA256" "$temp_dir/blesh.tar.xz" | sha256sum --check --status ||
    die 'ble.sh checksum verification failed'
  mkdir -p -- "$temp_dir/blesh"
  tar --no-same-owner -xJf "$temp_dir/blesh.tar.xz" -C "$temp_dir/blesh" --strip-components=1
  bash "$temp_dir/blesh/ble.sh" --install "$data_home"
fi

if [[ ! -r $data_home/blesh/ble.sh && ! -r /usr/share/blesh/ble.sh ]]; then
  say 'warning: ble.sh is not installed; highlighting will stay off until it is available.'
fi

mkdir -p -- "$(dirname -- "$bashrc")"
touch -- "$bashrc"
if ! grep -Fqx "$START_MARKER" "$bashrc"; then
  [[ ! -s $bashrc ]] || printf '\n' >> "$bashrc"
  {
    printf '%s\n' "$START_MARKER"
    # shellcheck disable=SC2016 # variables must expand when a terminal starts
    printf '%s\n' '[[ $- != *i* ]] || source "${XDG_DATA_HOME:-$HOME/.local/share}/omarchy-chroma/chromarchy.bash"'
    printf '%s\n' "$END_MARKER"
  } >> "$bashrc"
fi

say "installed in $install_dir"
say 'open a new terminal, then run: chroma doctor'
