#!/usr/bin/env bash
set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
# shellcheck disable=SC1091
source "$root/config/defaults.bash"

unset CHROMA_FZF_INTEGRATION
CHROMA_SUGGESTIONS=yes
CHROMA_BLE_ERROR_FEEDBACK=2
CHROMA_THEME_INTEGRATION=no
CHROMA_MIN_CONTRAST=99.5
unset CHROMA_STYLES
declare -ga CHROMA_STYLES=(not-an-associative-array)
unset CHROMA_EXTRA_DANGER_COMMANDS
declare -g CHROMA_EXTRA_DANGER_COMMANDS=not-an-array

chromarchy::validate_config

[[ $CHROMA_FZF_INTEGRATION == 1 ]]
[[ $CHROMA_SUGGESTIONS == 0 ]]
[[ $CHROMA_BLE_ERROR_FEEDBACK == 0 ]]
[[ $CHROMA_THEME_INTEGRATION == 1 ]]
[[ $CHROMA_MIN_CONTRAST == 21 ]]
[[ $(declare -p CHROMA_STYLES) == 'declare -A '* ]]
[[ ${CHROMA_STYLES[danger]} == ${CHROMA_BUILTIN_STYLES[danger]} ]]
[[ $(declare -p CHROMA_EXTRA_DANGER_COMMANDS) == 'declare -a '* ]]
((${#CHROMA_CONFIG_WARNINGS[@]} >= 7))

CHROMA_MIN_CONTRAST=not-a-number
chromarchy::validate_config
[[ $CHROMA_MIN_CONTRAST == 5.5 ]]
[[ ${#CHROMA_CONFIG_WARNINGS[@]} == 1 ]]

CHROMA_MIN_CONTRAST=21.00
chromarchy::validate_config
[[ $CHROMA_MIN_CONTRAST == 21.00 ]]
[[ ${#CHROMA_CONFIG_WARNINGS[@]} == 0 ]]

printf 'ok - invalid user configuration is normalized with diagnostics\n'
