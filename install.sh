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
stage_dir=
bashrc_temp=
backup_dir=

cleanup() {
  [[ ! ${temp_dir:-} || ! -d $temp_dir ]] || rm -rf -- "$temp_dir"
  [[ ! ${stage_dir:-} || ! -d $stage_dir ]] || rm -rf -- "$stage_dir"
  [[ ! ${bashrc_temp:-} || ! -e $bashrc_temp ]] || rm -f -- "$bashrc_temp"
  if [[ ${backup_dir:-} && -e $backup_dir/omarchy-chroma ]]; then
    printf 'Omarchy Chroma: previous installation preserved at %s\n' \
      "$backup_dir/omarchy-chroma" >&2
  elif [[ ${backup_dir:-} && -d $backup_dir ]]; then
    rmdir -- "$backup_dir" 2>/dev/null || true
  fi
}
trap cleanup EXIT

say() { printf 'Omarchy Chroma: %s\n' "$*"; }
die() { printf 'Omarchy Chroma: error: %s\n' "$*" >&2; exit 1; }

blesh_available() {
  [[ -r $data_home/blesh/ble.sh ||
     -r /usr/share/blesh/ble.sh ||
     -r /usr/local/share/blesh/ble.sh ]]
}

prepare_bashrc() {
  local bashrc_dir start_count end_count
  bashrc_dir=$(dirname -- "$bashrc")
  mkdir -p -- "$bashrc_dir"

  if [[ -L $bashrc ]]; then
    command -v readlink >/dev/null || die 'readlink is required for a symlinked .bashrc'
    bashrc=$(readlink -f -- "$bashrc") || die "could not resolve symlink: $bashrc"
    bashrc_dir=$(dirname -- "$bashrc")
  fi
  [[ ! -e $bashrc || -f $bashrc ]] || die "not a regular file: $bashrc"

  bashrc_temp=$(mktemp "$bashrc_dir/.omarchy-chroma-bashrc.XXXXXXXX")
  if [[ -f $bashrc ]]; then
    start_count=$(grep -Fxc "$START_MARKER" "$bashrc" || true)
    end_count=$(grep -Fxc "$END_MARKER" "$bashrc" || true)
    if [[ $start_count != "$end_count" ]]; then
      say 'warning: unmatched Chroma marker in .bashrc was preserved.'
    fi
    # Buffer marked sections until their closing marker appears. A malformed,
    # unterminated section is emitted unchanged instead of swallowing user data.
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
    ' "$bashrc" > "$bashrc_temp"
    chmod --reference="$bashrc" "$bashrc_temp" 2>/dev/null || chmod 0644 "$bashrc_temp"
  else
    chmod 0644 "$bashrc_temp"
  fi

  if [[ -s $bashrc_temp ]] && [[ $(tail -n 1 -- "$bashrc_temp") ]]; then
    printf '\n' >> "$bashrc_temp"
  fi
  {
    printf '%s\n' "$START_MARKER"
    # shellcheck disable=SC2016 # variables must expand when a terminal starts
    printf '%s\n' 'if [[ $- == *i* && -r ${XDG_DATA_HOME:-$HOME/.local/share}/omarchy-chroma/chromarchy.bash ]]; then'
    # shellcheck disable=SC2016 # keep the loader portable between user sessions
    printf '%s\n' '  source "${XDG_DATA_HOME:-$HOME/.local/share}/omarchy-chroma/chromarchy.bash"'
    printf '%s\n' 'fi'
    printf '%s\n' "$END_MARKER"
  } >> "$bashrc_temp"
}

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
    command -v git >/dev/null || die 'git is required when no local source is available'
    temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/omarchy-chroma.XXXXXXXX")
    say 'downloading the repository...'
    git clone --depth 1 --quiet "$CHROMA_REPOSITORY" "$temp_dir/repository"
    source_dir=$temp_dir/repository
  fi
fi

for required_file in \
  chromarchy.bash \
  config/defaults.bash \
  config/config.example.bash \
  lib/parser.bash \
  lib/layer.bash \
  lib/theme.bash \
  uninstall.sh; do
  [[ -r $source_dir/$required_file ]] ||
    die "invalid source directory (missing $required_file): $source_dir"
done

# Assemble a complete release beside the destination. The live installation is
# replaced only after every source file has been validated and copied.
mkdir -p -- "$data_home"
stage_dir=$(mktemp -d "$data_home/.omarchy-chroma-stage.XXXXXXXX")
staged_install=$stage_dir/omarchy-chroma
mkdir -p -- "$staged_install/config" "$staged_install/lib" "$config_home/omarchy-chroma"
install -m 0644 "$source_dir/chromarchy.bash" "$staged_install/chromarchy.bash"
install -m 0644 "$source_dir/config/defaults.bash" "$staged_install/config/defaults.bash"
install -m 0644 "$source_dir/lib/parser.bash" "$staged_install/lib/parser.bash"
install -m 0644 "$source_dir/lib/layer.bash" "$staged_install/lib/layer.bash"
install -m 0644 "$source_dir/lib/theme.bash" "$staged_install/lib/theme.bash"
install -m 0755 "$source_dir/uninstall.sh" "$staged_install/uninstall.sh"

if [[ ! -e $config_home/omarchy-chroma/config.bash ]]; then
  install -m 0644 "$source_dir/config/config.example.bash" "$config_home/omarchy-chroma/config.bash"
fi

if [[ ${CHROMA_INSTALL_BLESH:-1} != 0 ]] && ! blesh_available; then
  command -v curl >/dev/null || die 'curl is required to install ble.sh'
  command -v sha256sum >/dev/null || die 'sha256sum is required to verify ble.sh'
  command -v tar >/dev/null || die 'tar is required to install ble.sh'
  [[ $temp_dir ]] || temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/omarchy-chroma.XXXXXXXX")
  say 'downloading the pinned ble.sh build...'
  curl --fail --location --silent --show-error \
    --connect-timeout 15 --max-time 180 --retry 3 --retry-all-errors \
    "$BLESH_URL" --output "$temp_dir/blesh.tar.xz"
  printf '%s  %s\n' "$BLESH_SHA256" "$temp_dir/blesh.tar.xz" | sha256sum --check --status ||
    die 'ble.sh checksum verification failed'
  mkdir -p -- "$temp_dir/blesh"
  tar --no-same-owner -xJf "$temp_dir/blesh.tar.xz" -C "$temp_dir/blesh" --strip-components=1
  bash "$temp_dir/blesh/ble.sh" --install "$data_home"
fi

if ! blesh_available; then
  say 'warning: ble.sh is not installed; highlighting will stay off until it is available.'
fi

prepare_bashrc

# Keep the previous release available until both atomic replacements succeed.
if [[ -e $install_dir ]]; then
  backup_dir=$(mktemp -d "$data_home/.omarchy-chroma-backup.XXXXXXXX")
  mv -- "$install_dir" "$backup_dir/omarchy-chroma"
fi
if ! mv -- "$staged_install" "$install_dir"; then
  [[ ! $backup_dir || ! -e $backup_dir/omarchy-chroma ]] ||
    mv -- "$backup_dir/omarchy-chroma" "$install_dir"
  die 'could not activate the staged installation'
fi
if ! mv -- "$bashrc_temp" "$bashrc"; then
  rm -rf -- "$install_dir"
  [[ ! $backup_dir || ! -e $backup_dir/omarchy-chroma ]] ||
    mv -- "$backup_dir/omarchy-chroma" "$install_dir"
  die "could not update $bashrc"
fi
bashrc_temp=
[[ ! $backup_dir || ! -d $backup_dir ]] || rm -rf -- "$backup_dir"
backup_dir=

say "installed in $install_dir"
say 'open a new terminal, then run: chroma doctor'
