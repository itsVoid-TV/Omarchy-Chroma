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

# Follow Omarchy's active colors.toml and lift low-contrast palette entries
# toward black or white until they remain readable at small terminal sizes.
: "${CHROMA_THEME_INTEGRATION:=1}"
: "${CHROMA_MIN_CONTRAST:=5.5}"
