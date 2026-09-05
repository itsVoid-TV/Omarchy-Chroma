# shellcheck shell=bash

[[ $- == *i* ]] || return 0
[[ ${TERM:-} != dumb ]] || return 0

if ((BASH_VERSINFO[0] < 4 || BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4)); then
  printf 'Omarchy Chroma needs Bash 4.4 or newer.\n' >&2
  return 1
fi

CHROMA_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
CHROMA_VERSION=0.1.0
_chromarchy_should_attach=0

if [[ ! ${BLE_VERSION:-} ]]; then
  _chromarchy_blesh=
  for _chromarchy_candidate in \
    "${XDG_DATA_HOME:-$HOME/.local/share}/blesh/ble.sh" \
    /usr/share/blesh/ble.sh \
    /usr/local/share/blesh/ble.sh; do
    if [[ -r $_chromarchy_candidate ]]; then
      _chromarchy_blesh=$_chromarchy_candidate
      break
    fi
  done
  if [[ ! $_chromarchy_blesh ]]; then
    printf 'Omarchy Chroma: ble.sh was not found. Run %s/install.sh again.\n' "$CHROMA_ROOT" >&2
    return 1
  fi
  # Loading detached lets Chroma register its layer before the first render.
  # shellcheck disable=SC1090 # resolved from known user/system data paths
  source "$_chromarchy_blesh" --attach=none
  _chromarchy_should_attach=1
fi

source "$CHROMA_ROOT/config/defaults.bash"
_chromarchy_config=${XDG_CONFIG_HOME:-$HOME/.config}/omarchy-chroma/config.bash
# shellcheck disable=SC1090 # intentionally user-configurable path
[[ ! -r $_chromarchy_config ]] || source "$_chromarchy_config"

if [[ $CHROMA_FZF_INTEGRATION == 1 ]] && command -v fzf &>/dev/null; then
  ble-import -d integration/fzf-completion
  ble-import -d integration/fzf-key-bindings
fi

source "$CHROMA_ROOT/lib/parser.bash"
source "$CHROMA_ROOT/lib/layer.bash"

chromarchy::legend() {
  printf '\n  \e[38;5;220;1m%-12s\e[0m %s\n' 'INSTALL' 'pacman -S, flatpak install, npm install'
  printf '  \e[38;5;203;1m%-12s\e[0m %s\n' 'REMOVE' 'pacman -R, flatpak uninstall'
  printf '  \e[38;5;196;1;4m%-12s\e[0m %s\n' 'DANGER' 'rm, dd, mkfs, shutdown'
  printf '  \e[38;5;208;1m%-12s\e[0m %s\n' 'PRIVILEGE' 'sudo, doas, pkexec'
  printf '  \e[38;5;141;1m%-12s\e[0m %s\n' 'GIT / VCS' 'git, gh, lazygit'
  printf '  \e[38;5;45m%-12s\e[0m %s\n' 'NETWORK' 'curl, wget, ssh, rsync'
  printf '  \e[38;5;75m%-12s\e[0m %s\n' 'CONTAINER' 'docker, podman, kubectl'
  printf '  \e[38;5;114m%-12s\e[0m %s\n\n' 'BUILD' 'make, cargo, go, cmake'
}

chromarchy::doctor() {
  local failures=0 data_home=${XDG_DATA_HOME:-$HOME/.local/share}
  printf 'Omarchy Chroma %s\n' "$CHROMA_VERSION"
  printf '  %-18s %s\n' 'Bash' "${BASH_VERSION:-missing}"
  if [[ ${BLE_VERSION:-} ]]; then
    printf '  %-18s %s\n' 'ble.sh' "$BLE_VERSION"
  else
    printf '  %-18s %s\n' 'ble.sh' 'NOT LOADED'
    ((failures++))
  fi
  if [[ ${CHROMA_LAYER_READY:-0} == 1 ]]; then
    printf '  %-18s %s\n' 'semantic layer' 'ready'
  else
    printf '  %-18s %s\n' 'semantic layer' 'NOT READY'
    ((failures++))
  fi
  if [[ -r $data_home/omarchy-chroma/chromarchy.bash ]]; then
    printf '  %-18s %s\n' 'installation' "$data_home/omarchy-chroma"
  else
    printf '  %-18s %s\n' 'installation' 'custom/source checkout'
  fi
  return "$failures"
}

chroma() {
  case ${1:-legend} in
    legend|colors) chromarchy::legend ;;
    doctor|status) chromarchy::doctor ;;
    version|--version|-v) printf 'Omarchy Chroma %s\n' "$CHROMA_VERSION" ;;
    help|--help|-h)
      printf 'Usage: chroma [legend|doctor|version|help]\n'
      ;;
    *)
      printf 'chroma: unknown command: %s\n' "$1" >&2
      printf 'Usage: chroma [legend|doctor|version|help]\n' >&2
      return 2
      ;;
  esac
}

if ((_chromarchy_should_attach)); then
  ble-attach
fi
unset _chromarchy_should_attach _chromarchy_blesh _chromarchy_candidate _chromarchy_config
