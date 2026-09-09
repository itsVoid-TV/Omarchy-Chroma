# shellcheck shell=bash

[[ $- == *i* ]] || return 0
[[ ${TERM:-} != dumb ]] || return 0

if ((BASH_VERSINFO[0] < 4 || BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4)); then
  printf 'Omarchy Chroma needs Bash 4.4 or newer.\n' >&2
  return 1
fi

CHROMA_ROOT=$(builtin cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && builtin pwd -P) || {
  printf 'Omarchy Chroma: could not resolve its installation directory.\n' >&2
  return 1
}
CHROMA_VERSION=0.3.0
_chromarchy_should_attach=0

for _chromarchy_required in \
  config/defaults.bash \
  lib/theme.bash \
  lib/parser.bash \
  lib/layer.bash; do
  if [[ ! -r $CHROMA_ROOT/$_chromarchy_required ]]; then
    printf 'Omarchy Chroma: incomplete installation in %s; run install.sh again.\n' \
      "$CHROMA_ROOT" >&2
    unset _chromarchy_required
    return 1
  fi
done
unset _chromarchy_required

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
chromarchy::validate_config
source "$CHROMA_ROOT/lib/theme.bash"
chromarchy::theme_apply

# ble.sh enables fish-like automatic suggestions by default. Chroma only needs
# its highlighting engine, so leave normal Tab completion intact and disable
# automatic ghost text unless it was explicitly requested in the user config.
if [[ $CHROMA_SUGGESTIONS != 1 ]]; then
  bleopt complete_auto_complete=
fi

# ble.sh normally paints parse/argument errors with a red or pink background
# and prints a red "[ble: exit N]" marker after failed commands. Chroma keeps
# semantic danger colors, but defaults these unrelated overlays to quiet.
if [[ $CHROMA_BLE_ERROR_FEEDBACK != 1 ]]; then
  bleopt exec_errexit_mark=
  ble-face -s syntax_error none
  ble-face -s argument_error none
fi

if [[ $CHROMA_FZF_INTEGRATION == 1 ]] && command -v fzf &>/dev/null; then
  ble-import -d integration/fzf-completion
  ble-import -d integration/fzf-key-bindings
fi

source "$CHROMA_ROOT/lib/parser.bash"
source "$CHROMA_ROOT/lib/layer.bash"

chromarchy::style_escape() {
  local g
  ble/color/gspec2g "$1"
  g=$ret
  ble/color/g2sgr "$g"
  CHROMA_STYLE_ESCAPE=$ret
}

chromarchy::legend_line() {
  local category=$1 label=$2 example=$3
  chromarchy::style_escape "${CHROMA_STYLES[$category]}"
  printf '  %s%-12s\e[0m %s\n' "$CHROMA_STYLE_ESCAPE" "$label" "$example"
}

chromarchy::legend() {
  printf '\n'
  chromarchy::legend_line install INSTALL 'pacman -S, flatpak install, npm install'
  chromarchy::legend_line remove REMOVE 'pacman -R, flatpak uninstall'
  chromarchy::legend_line danger DANGER 'rm, dd, mkfs, shutdown'
  chromarchy::legend_line privilege PRIVILEGE 'sudo, doas, pkexec'
  chromarchy::legend_line system SYSTEM 'systemctl, mount, chmod'
  chromarchy::legend_line vcs 'GIT / VCS' 'git, gh, lazygit'
  chromarchy::legend_line network NETWORK 'curl, wget, ssh, rsync'
  chromarchy::legend_line container CONTAINER 'docker, podman, kubectl'
  chromarchy::legend_line build BUILD 'make, cargo, go, cmake'
  chromarchy::legend_line navigate NAVIGATE 'cd, ls, zoxide'
  chromarchy::legend_line inspect INSPECT 'cat, ps, command -v'
  chromarchy::legend_line search SEARCH 'rg, find, fzf'
  chromarchy::legend_line editor EDITOR 'nvim, vim, helix'
  printf '\n'
}

chromarchy::doctor() {
  local failures=0 data_home=${XDG_DATA_HOME:-$HOME/.local/share}
  local layer_status='NOT REGISTERED' suggestions='disabled' error_feedback='disabled' theme_status
  local bashrc_file=${CHROMA_BASHRC:-$HOME/.bashrc} line warning
  local start_count=0 end_count=0
  printf 'Omarchy Chroma %s\n' "$CHROMA_VERSION"
  printf '  %-18s %s\n' 'Bash' "${BASH_VERSION:-missing}"
  if [[ ${BLE_VERSION:-} ]]; then
    printf '  %-18s %s\n' 'ble.sh' "$BLE_VERSION"
  else
    printf '  %-18s %s\n' 'ble.sh' 'NOT LOADED'
    ((++failures))
  fi
  if [[ ${CHROMA_LAYER_READY:-0} == 1 ]]; then
    printf '  %-18s %s\n' 'semantic layer' 'ready'
  else
    printf '  %-18s %s\n' 'semantic layer' 'NOT READY'
    ((++failures))
  fi
  # shellcheck disable=SC2154 # provided by ble.sh
  if declare -p _ble_highlight_layer_list &>/dev/null &&
     [[ " ${_ble_highlight_layer_list[*]} " == *' omarchy_chroma '* ]]; then
    layer_status=registered
  else
    ((++failures))
  fi
  printf '  %-18s %s\n' 'render layer' "$layer_status"
  [[ $CHROMA_SUGGESTIONS == 1 ]] && suggestions=enabled
  printf '  %-18s %s\n' 'auto suggestions' "$suggestions"
  [[ $CHROMA_BLE_ERROR_FEEDBACK == 1 ]] && error_feedback=enabled
  printf '  %-18s %s\n' 'red error feedback' "$error_feedback"
  theme_status=$CHROMA_THEME_SOURCE
  if [[ $CHROMA_THEME_SOURCE == omarchy ]]; then
    theme_status="$CHROMA_THEME_NAME ($CHROMA_THEME_MODE)"
  fi
  printf '  %-18s %s\n' 'theme colors' "$theme_status"
  printf '  %-18s %s\n' 'theme background' "$CHROMA_THEME_BACKGROUND"
  printf '  %-18s %s\n' 'worst contrast' "$CHROMA_THEME_WORST_CONTRAST"
  printf '  %-18s %s\n' 'minimum contrast' "$CHROMA_MIN_CONTRAST"
  if [[ ${CHROMA_THEME_ERROR:-} ]]; then
    printf '  %-18s %s\n' 'theme error' "$CHROMA_THEME_ERROR"
    ((++failures))
  fi
  if ((${#CHROMA_CONFIG_WARNINGS[@]})); then
    printf '  %-18s %d warning(s)\n' 'configuration' "${#CHROMA_CONFIG_WARNINGS[@]}"
    for warning in "${CHROMA_CONFIG_WARNINGS[@]}"; do
      printf '    - %s\n' "$warning"
    done
    ((++failures))
  else
    printf '  %-18s %s\n' 'configuration' 'valid'
  fi
  if [[ -r $bashrc_file ]]; then
    while IFS= read -r line || [[ $line ]]; do
      [[ $line == '# >>> omarchy-chroma >>>' ]] && ((++start_count))
      [[ $line == '# <<< omarchy-chroma <<<' ]] && ((++end_count))
    done < "$bashrc_file"
    if ((start_count == end_count && start_count <= 1)); then
      if ((start_count == 1)); then
        printf '  %-18s %s\n' '.bashrc loader' 'managed'
      else
        printf '  %-18s %s\n' '.bashrc loader' 'not managed'
      fi
    else
      printf '  %-18s %s\n' '.bashrc loader' "MALFORMED ($start_count start, $end_count end)"
      ((++failures))
    fi
  else
    printf '  %-18s %s\n' '.bashrc loader' 'not readable'
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
    reload)
      CHROMA_THEME_SNAPSHOT=
      if chromarchy::theme_reload; then
        printf 'Omarchy Chroma: theme colors reloaded from %s.\n' "$CHROMA_THEME_PATH"
      else
        printf 'Omarchy Chroma: theme reload failed: %s\n' "$CHROMA_THEME_ERROR" >&2
        return 1
      fi
      ;;
    explain)
      shift
      chromarchy::explain "$@"
      ;;
    version|--version|-v) printf 'Omarchy Chroma %s\n' "$CHROMA_VERSION" ;;
    help|--help|-h)
      printf '%s\n' \
        'Usage: chroma COMMAND [ARGS...]' \
        '' \
        'Commands:' \
        '  legend                 Show semantic colors and examples' \
        '  doctor                 Diagnose the live shell integration' \
        '  explain COMMAND...     Explain highlights without running the command' \
        '  reload                 Reload the active Omarchy theme' \
        '  version                Print the installed version' \
        '  help                   Show this help'
      ;;
    *)
      printf 'chroma: unknown command: %s\n' "$1" >&2
      printf 'Run "chroma help" for usage.\n' >&2
      return 2
      ;;
  esac
}

if [[ $CHROMA_THEME_INTEGRATION == 1 && ${CHROMA_THEME_HOOK_READY:-0} != 1 ]]; then
  blehook PRECMD+=chromarchy::theme_refresh
  CHROMA_THEME_HOOK_READY=1
fi

if ((_chromarchy_should_attach)); then
  ble-attach
fi
unset _chromarchy_should_attach _chromarchy_blesh _chromarchy_candidate _chromarchy_config
