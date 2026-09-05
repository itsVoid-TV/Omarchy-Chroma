#!/usr/bin/env bash
set -uo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
fixtures=$root/tests/fixtures
categories=(install remove danger privilege system network vcs container build navigate inspect search editor)

source "$root/config/defaults.bash"
source "$root/lib/theme.bash"

tests=0
failures=0
failure_detail=

pass() {
  ((tests++))
  printf 'ok %d - %s\n' "$tests" "$1"
}

fail() {
  ((tests++))
  ((failures++))
  printf 'not ok %d - %s%s\n' "$tests" "$1" "${2:+: $2}"
}

expect_equal() {
  local label=$1 actual=$2 expected=$3
  if [[ $actual == "$expected" ]]; then
    pass "$label"
  else
    fail "$label" "expected '$expected', got '$actual'"
  fi
}

contrast_ratio() {
  local foreground=$1 background=$2
  LC_ALL=C awk -v foreground="$foreground" -v background="$background" '
    function digit(char) { return index("0123456789abcdef", tolower(char)) - 1 }
    function byte(hex, offset) { return digit(substr(hex, offset, 1)) * 16 + digit(substr(hex, offset + 1, 1)) }
    function linear(value) { value /= 255; return value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ^ 2.4 }
    function lum(hex) { return 0.2126 * linear(byte(hex, 2)) + 0.7152 * linear(byte(hex, 4)) + 0.0722 * linear(byte(hex, 6)) }
    BEGIN {
      first = lum(foreground)
      second = lum(background)
      ratio = first > second ? (first + 0.05) / (second + 0.05) : (second + 0.05) / (first + 0.05)
      printf "%.6f\n", ratio
    }
  '
}

reset_theme() {
  local category
  CHROMA_STYLES=()
  for category in "${categories[@]}"; do
    CHROMA_STYLES[$category]=${CHROMA_BUILTIN_STYLES[$category]}
  done
  CHROMA_THEME_COLORS=()
  CHROMA_THEME_MANAGED=()
  CHROMA_THEME_LAST_STYLES=()
  CHROMA_STYLE_CONTRAST=()
  CHROMA_THEME_SOURCE=builtin
  CHROMA_THEME_NAME=unknown
  CHROMA_THEME_MODE=unknown
  CHROMA_THEME_BACKGROUND=unknown
  CHROMA_THEME_WORST_CONTRAST=unknown
  CHROMA_THEME_PATH=
  CHROMA_THEME_SNAPSHOT=
  CHROMA_THEME_INTEGRATION=1
  CHROMA_MIN_CONTRAST=5.5
  unset CHROMA_THEME_FILE
}

styles_are_visible() {
  local background=$1 category style color ratio
  failure_detail=
  for category in "${categories[@]}"; do
    style=${CHROMA_STYLES[$category]:-}
    color=${style#fg=}
    color=${color%%,*}
    if [[ ! $color =~ ^#[0-9a-fA-F]{6}$ ]]; then
      failure_detail="$category has no RGB foreground ($style)"
      return 1
    fi
    ratio=$(contrast_ratio "$color" "$background")
    if ! LC_ALL=C awk -v ratio="$ratio" -v minimum="$CHROMA_MIN_CONTRAST" \
      'BEGIN { exit !(ratio >= minimum) }'; then
      failure_detail="$category $color has contrast $ratio against $background"
      return 1
    fi
  done
}

check_theme_visibility() {
  local label=$1 file=$2
  reset_theme
  CHROMA_THEME_FILE=$file
  chromarchy::theme_apply
  if [[ $CHROMA_THEME_SOURCE != omarchy ]]; then
    fail "$label" 'theme was not loaded'
  elif styles_are_visible "$CHROMA_THEME_BACKGROUND"; then
    pass "$label"
  else
    fail "$label" "$failure_detail"
  fi
}

reset_theme
CHROMA_THEME_FILE=$fixtures/vantablack/colors.toml
chromarchy::theme_apply
expect_equal 'Vantablack is detected as dark' "$CHROMA_THEME_MODE" dark
expect_equal 'Vantablack background is detected exactly' "$CHROMA_THEME_BACKGROUND" '#000000'
expect_equal 'install uses Vantablack yellow' "${CHROMA_STYLES[install]}" 'fg=#cecece,bold'
expect_equal 'danger uses visible Vantablack red' "${CHROMA_STYLES[danger]}" 'fg=#a4a4a4,bold,underline'
if styles_are_visible "$CHROMA_THEME_BACKGROUND"; then
  pass 'every Vantablack semantic color clears 5.5:1'
else
  fail 'every Vantablack semantic color clears 5.5:1' "$failure_detail"
fi

reset_theme
CHROMA_THEME_FILE=$fixtures/white/colors.toml
chromarchy::theme_apply
expect_equal 'White is detected as light' "$CHROMA_THEME_MODE" light
expect_equal 'White background is detected exactly' "$CHROMA_THEME_BACKGROUND" '#ffffff'
expect_equal 'install stays dark on the White theme' "${CHROMA_STYLES[install]}" 'fg=#4a4a4a,bold'
if styles_are_visible "$CHROMA_THEME_BACKGROUND"; then
  pass 'every White semantic color clears 5.5:1'
else
  fail 'every White semantic color clears 5.5:1' "$failure_detail"
fi

reset_theme
CHROMA_THEME_FILE=$fixtures/low-contrast/colors.toml
chromarchy::theme_apply
if [[ ${CHROMA_STYLES[install]} != 'fg=#303030,bold' ]]; then
  pass 'a faint theme color is lifted instead of copied blindly'
else
  fail 'a faint theme color is lifted instead of copied blindly'
fi
if styles_are_visible "$CHROMA_THEME_BACKGROUND"; then
  pass 'lifted low-contrast colors clear 5.5:1'
else
  fail 'lifted low-contrast colors clear 5.5:1' "$failure_detail"
fi

reset_theme
CHROMA_STYLES[install]='fg=#123456,bold'
CHROMA_THEME_FILE=$fixtures/vantablack/colors.toml
chromarchy::theme_apply
expect_equal 'an explicit user style is preserved' "${CHROMA_STYLES[install]}" 'fg=#123456,bold'

state=$(mktemp -d "${TMPDIR:-/tmp}/omarchy-chroma-theme.XXXXXXXX")
trap 'rm -rf -- "$state"' EXIT
mkdir -p "$state/current/theme"
cp -- "$fixtures/vantablack/colors.toml" "$state/current/theme/colors.toml"
printf 'Vantablack\n' > "$state/current/theme.name"
reset_theme
CHROMA_THEME_FILE=$state/current/theme/colors.toml
chromarchy::theme_apply
expect_equal 'active Omarchy theme.name is used' "$CHROMA_THEME_NAME" Vantablack
before=${CHROMA_STYLES[install]}
cp -- "$fixtures/white/colors.toml" "$state/current/theme/colors.toml"
printf 'White\n' > "$state/current/theme.name"
chromarchy::theme_refresh
expect_equal 'theme switching refreshes the background' "$CHROMA_THEME_BACKGROUND" '#ffffff'
if [[ ${CHROMA_STYLES[install]} != "$before" ]]; then
  pass 'theme switching refreshes rendered styles'
else
  fail 'theme switching refreshes rendered styles'
fi

saved_home=$HOME
HOME=$state/home
mkdir -p "$HOME/.local/state/omarchy/current/theme"
cp -- "$fixtures/vantablack/colors.toml" "$HOME/.local/state/omarchy/current/theme/colors.toml"
printf 'Vantablack\n' > "$HOME/.local/state/omarchy/current/theme.name"
reset_theme
chromarchy::theme_apply
expect_equal 'current Omarchy state path is discovered automatically' \
  "$CHROMA_THEME_PATH" "$HOME/.local/state/omarchy/current/theme/colors.toml"
expect_equal 'auto-discovered black theme stays readable' \
  "${CHROMA_STYLES[install]}" 'fg=#cecece,bold'
HOME=$saved_home

reset_theme
CHROMA_THEME_INTEGRATION=0
CHROMA_THEME_FILE=$fixtures/vantablack/colors.toml
chromarchy::theme_apply
expect_equal 'theme integration can be disabled' "$CHROMA_THEME_SOURCE" builtin
expect_equal 'disabled integration keeps builtin colors' "${CHROMA_STYLES[install]}" 'fg=220,bold'

if [[ ${CHROMA_OMARCHY_THEMES_DIR:-} ]]; then
  mapfile -t upstream_themes < <(find "$CHROMA_OMARCHY_THEMES_DIR" -mindepth 2 -maxdepth 2 -name colors.toml -print | LC_ALL=C sort)
  expect_equal 'pinned Omarchy audit contains 22 themes' "${#upstream_themes[@]}" 22
  for theme_file in "${upstream_themes[@]}"; do
    theme_name=${theme_file%/colors.toml}
    theme_name=${theme_name##*/}
    check_theme_visibility "official Omarchy theme: $theme_name" "$theme_file"
  done
else
  printf 'note: CHROMA_OMARCHY_THEMES_DIR is unset; full upstream palette audit skipped\n'
fi

printf '1..%d\n' "$tests"
((failures == 0))
