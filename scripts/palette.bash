#!/usr/bin/env bash
# Machine-readable palette probe. Never source .bashrc or execute sample commands.
set -o pipefail
chroma_source=$1
source "$chroma_source/config/defaults.bash"
chroma_config=${XDG_CONFIG_HOME:-$HOME/.config}/omarchy-chroma/config.bash
# config.bash is deliberately executable, just as in the interactive add-on.
# Keep its output off the NUL-delimited protocol. The Python caller sets a timeout.
# shellcheck disable=SC1090
if [[ -r $chroma_config ]]; then
  source "$chroma_config" >&2 || exit 1
fi
chromarchy::validate_config
source "$chroma_source/lib/theme.bash"
chromarchy::theme_reload || true
printf '%s\0' "$CHROMA_THEME_SOURCE" "$CHROMA_THEME_NAME" \
  "$CHROMA_THEME_MODE" "$CHROMA_THEME_BACKGROUND" "$CHROMA_MIN_CONTRAST" \
  "$CHROMA_THEME_WORST_CONTRAST" "$CHROMA_THEME_ERROR" "$CHROMA_THEME_PATH"
for chroma_category in install remove danger privilege system vcs network container build navigate inspect search editor; do
  printf '%s\0' "$chroma_category" "${CHROMA_STYLES[$chroma_category]}" \
    "${CHROMA_STYLE_CONTRAST[$chroma_category]:-unknown}"
done
printf '%s\0' "${CHROMA_CONFIG_WARNINGS[*]}"
