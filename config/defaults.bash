# shellcheck shell=bash

# Graphic specifications use ble.sh's gspec syntax.
if ! declare -p CHROMA_STYLES &>/dev/null; then
  declare -gA CHROMA_STYLES=()
fi

[[ -v 'CHROMA_STYLES[install]' ]]   || CHROMA_STYLES[install]='fg=220,bold'
[[ -v 'CHROMA_STYLES[remove]' ]]    || CHROMA_STYLES[remove]='fg=203,bold'
[[ -v 'CHROMA_STYLES[danger]' ]]    || CHROMA_STYLES[danger]='fg=196,bold,underline'
[[ -v 'CHROMA_STYLES[privilege]' ]] || CHROMA_STYLES[privilege]='fg=208,bold'
[[ -v 'CHROMA_STYLES[system]' ]]    || CHROMA_STYLES[system]='fg=214'
[[ -v 'CHROMA_STYLES[network]' ]]   || CHROMA_STYLES[network]='fg=45'
[[ -v 'CHROMA_STYLES[vcs]' ]]       || CHROMA_STYLES[vcs]='fg=141,bold'
[[ -v 'CHROMA_STYLES[container]' ]] || CHROMA_STYLES[container]='fg=75'
[[ -v 'CHROMA_STYLES[build]' ]]     || CHROMA_STYLES[build]='fg=114'
[[ -v 'CHROMA_STYLES[navigate]' ]]  || CHROMA_STYLES[navigate]='fg=81'
[[ -v 'CHROMA_STYLES[inspect]' ]]   || CHROMA_STYLES[inspect]='fg=117'
[[ -v 'CHROMA_STYLES[search]' ]]    || CHROMA_STYLES[search]='fg=51'
[[ -v 'CHROMA_STYLES[editor]' ]]    || CHROMA_STYLES[editor]='fg=177'

declare -p CHROMA_EXTRA_INSTALL_COMMANDS &>/dev/null || declare -ga CHROMA_EXTRA_INSTALL_COMMANDS=()
declare -p CHROMA_EXTRA_REMOVE_COMMANDS &>/dev/null || declare -ga CHROMA_EXTRA_REMOVE_COMMANDS=()
declare -p CHROMA_EXTRA_DANGER_COMMANDS &>/dev/null || declare -ga CHROMA_EXTRA_DANGER_COMMANDS=()

# Omarchy loads fzf's Readline integration before user additions in .bashrc.
# ble.sh's own adapter keeps Ctrl-R/completion working after it takes over.
: "${CHROMA_FZF_INTEGRATION:=1}"
