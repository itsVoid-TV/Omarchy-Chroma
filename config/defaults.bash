# shellcheck shell=bash

# Graphic specifications use ble.sh's gspec syntax. The builtin values are
# also used to tell theme-managed styles apart from explicit user overrides.
declare -gA CHROMA_BUILTIN_STYLES=(
  [install]='fg=220,bold'
  [remove]='fg=203,bold'
  [danger]='fg=196,bold,underline'
  [privilege]='fg=208,bold'
  [system]='fg=214,bold'
  [network]='fg=45,bold'
  [vcs]='fg=141,bold'
  [container]='fg=75,bold'
  [build]='fg=114,bold'
  [navigate]='fg=81,bold'
  [inspect]='fg=117,bold'
  [search]='fg=51,bold'
  [editor]='fg=177,bold'
)

if ! declare -p CHROMA_STYLES &>/dev/null; then
  declare -gA CHROMA_STYLES=()
fi

for _chromarchy_category in "${!CHROMA_BUILTIN_STYLES[@]}"; do
  [[ -v "CHROMA_STYLES[$_chromarchy_category]" ]] ||
    CHROMA_STYLES[$_chromarchy_category]=${CHROMA_BUILTIN_STYLES[$_chromarchy_category]}
done
unset _chromarchy_category

declare -p CHROMA_EXTRA_INSTALL_COMMANDS &>/dev/null || declare -ga CHROMA_EXTRA_INSTALL_COMMANDS=()
declare -p CHROMA_EXTRA_REMOVE_COMMANDS &>/dev/null || declare -ga CHROMA_EXTRA_REMOVE_COMMANDS=()
declare -p CHROMA_EXTRA_DANGER_COMMANDS &>/dev/null || declare -ga CHROMA_EXTRA_DANGER_COMMANDS=()

# Omarchy loads fzf's Readline integration before user additions in .bashrc.
# ble.sh's own adapter keeps Ctrl-R/completion working after it takes over.
: "${CHROMA_FZF_INTEGRATION:=1}"

# Keep regular Tab completion, but do not show ble.sh's automatic ghost-text
# suggestions unless the user explicitly opts in.
: "${CHROMA_SUGGESTIONS:=0}"

# Suppress ble.sh's red-background parse/argument faces and its red
# "[ble: exit N]" marker. Chroma's semantic danger colors stay active.
: "${CHROMA_BLE_ERROR_FEEDBACK:=0}"

# Follow Omarchy's active colors.toml and lift low-contrast palette entries
# toward black or white until they remain readable at small terminal sizes.
: "${CHROMA_THEME_INTEGRATION:=1}"
: "${CHROMA_MIN_CONTRAST:=5.5}"

declare -ga CHROMA_CONFIG_WARNINGS=()

chromarchy::config_warning() {
  CHROMA_CONFIG_WARNINGS+=("$1")
}

chromarchy::validate_toggle() {
  local name=$1 fallback=$2 value
  value=${!name-}
  if [[ $value != 0 && $value != 1 ]]; then
    printf -v "$name" '%s' "$fallback"
    chromarchy::config_warning "$name must be 0 or 1; using $fallback"
  fi
}

chromarchy::validate_config() {
  local declaration category array_name whole
  CHROMA_CONFIG_WARNINGS=()

  chromarchy::validate_toggle CHROMA_FZF_INTEGRATION 1
  chromarchy::validate_toggle CHROMA_SUGGESTIONS 0
  chromarchy::validate_toggle CHROMA_BLE_ERROR_FEEDBACK 0
  chromarchy::validate_toggle CHROMA_THEME_INTEGRATION 1

  if [[ $CHROMA_MIN_CONTRAST =~ ^([0-9]+)([.][0-9]+)?$ ]]; then
    whole=${BASH_REMATCH[1]}
    while ((${#whole} > 1)) && [[ ${whole:0:1} == 0 ]]; do
      whole=${whole:1}
    done
    if ((${#whole} > 2)); then
      CHROMA_MIN_CONTRAST=21
      chromarchy::config_warning 'CHROMA_MIN_CONTRAST was above 21; using 21'
    elif ((10#$whole < 3)); then
      CHROMA_MIN_CONTRAST=3
      chromarchy::config_warning 'CHROMA_MIN_CONTRAST was below 3; using 3'
    elif ((10#$whole > 21)) || [[ $whole == 21 && ! $CHROMA_MIN_CONTRAST =~ ^21([.]0+)?$ ]]; then
      CHROMA_MIN_CONTRAST=21
      chromarchy::config_warning 'CHROMA_MIN_CONTRAST was above 21; using 21'
    fi
  else
    CHROMA_MIN_CONTRAST=5.5
    chromarchy::config_warning 'CHROMA_MIN_CONTRAST is not numeric; using 5.5'
  fi

  declaration=$(declare -p CHROMA_STYLES 2>/dev/null || true)
  if [[ $declaration != 'declare -A '* ]]; then
    unset CHROMA_STYLES
    declare -gA CHROMA_STYLES=()
    chromarchy::config_warning 'CHROMA_STYLES must be an associative array; using defaults'
  fi
  for category in "${!CHROMA_BUILTIN_STYLES[@]}"; do
    if [[ ! ${CHROMA_STYLES[$category]:-} ]]; then
      CHROMA_STYLES[$category]=${CHROMA_BUILTIN_STYLES[$category]}
      chromarchy::config_warning "empty style for $category; using its default"
    fi
  done

  for array_name in CHROMA_EXTRA_INSTALL_COMMANDS CHROMA_EXTRA_REMOVE_COMMANDS CHROMA_EXTRA_DANGER_COMMANDS; do
    declaration=$(declare -p "$array_name" 2>/dev/null || true)
    if [[ $declaration != 'declare -a '* ]]; then
      unset "$array_name"
      declare -ga "$array_name=()"
      chromarchy::config_warning "$array_name must be an indexed array; ignoring it"
    fi
  done
}
