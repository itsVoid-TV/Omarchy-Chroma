# shellcheck shell=bash

# Omarchy Chroma theme integration. Theme files are parsed as data and are
# never sourced. The only external work happens on shell start or after a
# theme switch; the per-keystroke highlighting path remains pure Bash.

declare -p CHROMA_THEME_COLORS &>/dev/null || declare -gA CHROMA_THEME_COLORS=()
declare -p CHROMA_THEME_MANAGED &>/dev/null || declare -gA CHROMA_THEME_MANAGED=()
declare -p CHROMA_THEME_LAST_STYLES &>/dev/null || declare -gA CHROMA_THEME_LAST_STYLES=()
declare -p CHROMA_STYLE_CONTRAST &>/dev/null || declare -gA CHROMA_STYLE_CONTRAST=()

: "${CHROMA_THEME_SOURCE:=builtin}"
: "${CHROMA_THEME_NAME:=unknown}"
: "${CHROMA_THEME_MODE:=unknown}"
: "${CHROMA_THEME_BACKGROUND:=unknown}"
: "${CHROMA_THEME_WORST_CONTRAST:=unknown}"
: "${CHROMA_THEME_PATH:=}"
: "${CHROMA_THEME_SNAPSHOT:=}"
: "${CHROMA_THEME_ERROR:=}"
: "${CHROMA_THEME_APPLIED:=0}"

chromarchy::theme_trim() {
  ret=$1
  ret=${ret#"${ret%%[![:space:]]*}"}
  ret=${ret%"${ret##*[![:space:]]}"}
}

chromarchy::theme_find_file() {
  local candidate
  ret=

  if [[ ${CHROMA_THEME_FILE:-} ]]; then
    [[ -f $CHROMA_THEME_FILE && -r $CHROMA_THEME_FILE ]] && ret=$CHROMA_THEME_FILE
    [[ $ret ]]
    return
  fi

  for candidate in \
    "${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/current/theme/colors.toml" \
    "${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/current/theme/colors.toml"; do
    if [[ -f $candidate && -r $candidate ]]; then
      ret=$candidate
      return 0
    fi
  done
  return 1
}

chromarchy::theme_parse_file() {
  local file=$1 line key value
  CHROMA_THEME_COLORS=()

  while IFS= read -r line || [[ $line ]]; do
    [[ $line == *'='* ]] || continue
    key=${line%%=*}
    value=${line#*=}
    chromarchy::theme_trim "$key"; key=$ret
    chromarchy::theme_trim "$value"; value=$ret
    [[ $key =~ ^[a-zA-Z0-9_-]+$ && $key != \#* ]] || continue

    if [[ $value == \"* ]]; then
      value=${value#\"}
      value=${value%%\"*}
    elif [[ $value == \'* ]]; then
      value=${value#\'}
      value=${value%%\'*}
    else
      value=${value%%[[:space:]#]*}
    fi
    CHROMA_THEME_COLORS[$key]=$value
  done < "$file"
}

chromarchy::theme_resolve_aliases() {
  local hex red green blue sum

  [[ ${CHROMA_THEME_COLORS[mode]:-} ]] ||
    CHROMA_THEME_COLORS[mode]=${CHROMA_THEME_COLORS[theme_type]:-}
  [[ ${CHROMA_THEME_COLORS[background]:-} ]] ||
    CHROMA_THEME_COLORS[background]=${CHROMA_THEME_COLORS[bg]:-${CHROMA_THEME_COLORS[color0]:-}}
  [[ ${CHROMA_THEME_COLORS[foreground]:-} ]] ||
    CHROMA_THEME_COLORS[foreground]=${CHROMA_THEME_COLORS[fg]:-${CHROMA_THEME_COLORS[color7]:-}}

  [[ ${CHROMA_THEME_COLORS[red]:-} ]] || CHROMA_THEME_COLORS[red]=${CHROMA_THEME_COLORS[color1]:-}
  [[ ${CHROMA_THEME_COLORS[green]:-} ]] || CHROMA_THEME_COLORS[green]=${CHROMA_THEME_COLORS[color2]:-}
  [[ ${CHROMA_THEME_COLORS[yellow]:-} ]] || CHROMA_THEME_COLORS[yellow]=${CHROMA_THEME_COLORS[color3]:-}
  [[ ${CHROMA_THEME_COLORS[blue]:-} ]] || CHROMA_THEME_COLORS[blue]=${CHROMA_THEME_COLORS[color4]:-}
  [[ ${CHROMA_THEME_COLORS[magenta]:-} ]] ||
    CHROMA_THEME_COLORS[magenta]=${CHROMA_THEME_COLORS[purple]:-${CHROMA_THEME_COLORS[color5]:-}}
  [[ ${CHROMA_THEME_COLORS[cyan]:-} ]] || CHROMA_THEME_COLORS[cyan]=${CHROMA_THEME_COLORS[color6]:-}
  [[ ${CHROMA_THEME_COLORS[orange]:-} ]] || CHROMA_THEME_COLORS[orange]=${CHROMA_THEME_COLORS[yellow]:-}
  [[ ${CHROMA_THEME_COLORS[accent]:-} ]] || CHROMA_THEME_COLORS[accent]=${CHROMA_THEME_COLORS[blue]:-}

  [[ ${CHROMA_THEME_COLORS[bright_red]:-} ]] || CHROMA_THEME_COLORS[bright_red]=${CHROMA_THEME_COLORS[color9]:-${CHROMA_THEME_COLORS[red]:-}}
  [[ ${CHROMA_THEME_COLORS[bright_green]:-} ]] || CHROMA_THEME_COLORS[bright_green]=${CHROMA_THEME_COLORS[color10]:-${CHROMA_THEME_COLORS[green]:-}}
  [[ ${CHROMA_THEME_COLORS[bright_yellow]:-} ]] || CHROMA_THEME_COLORS[bright_yellow]=${CHROMA_THEME_COLORS[color11]:-${CHROMA_THEME_COLORS[yellow]:-}}
  [[ ${CHROMA_THEME_COLORS[bright_blue]:-} ]] || CHROMA_THEME_COLORS[bright_blue]=${CHROMA_THEME_COLORS[color12]:-${CHROMA_THEME_COLORS[blue]:-}}
  [[ ${CHROMA_THEME_COLORS[bright_magenta]:-} ]] || CHROMA_THEME_COLORS[bright_magenta]=${CHROMA_THEME_COLORS[color13]:-${CHROMA_THEME_COLORS[magenta]:-}}
  [[ ${CHROMA_THEME_COLORS[bright_cyan]:-} ]] || CHROMA_THEME_COLORS[bright_cyan]=${CHROMA_THEME_COLORS[color14]:-${CHROMA_THEME_COLORS[cyan]:-}}
  [[ ${CHROMA_THEME_COLORS[bright_foreground]:-} ]] || CHROMA_THEME_COLORS[bright_foreground]=${CHROMA_THEME_COLORS[color15]:-${CHROMA_THEME_COLORS[foreground]:-}}

  [[ ${CHROMA_THEME_COLORS[background]:-} =~ ^#[0-9A-Fa-f]{6}$ ]] || return 1
  if [[ ${CHROMA_THEME_COLORS[mode]:-} != light && ${CHROMA_THEME_COLORS[mode]:-} != dark ]]; then
    hex=${CHROMA_THEME_COLORS[background]#\#}
    red=$((16#${hex:0:2}))
    green=$((16#${hex:2:2}))
    blue=$((16#${hex:4:2}))
    sum=$((red + green + blue))
    ((sum > 382)) && CHROMA_THEME_COLORS[mode]=light || CHROMA_THEME_COLORS[mode]=dark
  fi
}

chromarchy::theme_pick_color() {
  local key
  ret=
  for key in "$@"; do
    if [[ ${CHROMA_THEME_COLORS[$key]:-} =~ ^#[0-9A-Fa-f]{6}$ ]]; then
      ret=${CHROMA_THEME_COLORS[$key]}
      return 0
    fi
  done
  return 1
}

chromarchy::theme_category_color() {
  case $1 in
    install)   chromarchy::theme_pick_color yellow bright_yellow foreground ;;
    remove)    chromarchy::theme_pick_color red bright_red foreground ;;
    danger)    chromarchy::theme_pick_color bright_red red foreground ;;
    privilege) chromarchy::theme_pick_color orange yellow foreground ;;
    system)    chromarchy::theme_pick_color bright_yellow orange yellow foreground ;;
    network)   chromarchy::theme_pick_color bright_cyan cyan foreground ;;
    vcs)       chromarchy::theme_pick_color bright_magenta magenta foreground ;;
    container) chromarchy::theme_pick_color bright_blue blue foreground ;;
    build)     chromarchy::theme_pick_color bright_green green foreground ;;
    navigate)  chromarchy::theme_pick_color blue bright_blue foreground ;;
    inspect)   chromarchy::theme_pick_color accent bright_foreground foreground ;;
    search)    chromarchy::theme_pick_color cyan bright_cyan foreground ;;
    editor)    chromarchy::theme_pick_color magenta bright_magenta foreground ;;
    *) ret=; return 1 ;;
  esac
}

chromarchy::theme_adjust_candidates() {
  local background=$1 minimum=$2 category
  shift 2

  for category in "$@"; do
    printf '%s\t%s\n' "$category" "${CHROMA_THEME_CANDIDATES[$category]}"
  done | LC_ALL=C awk -F '\t' -v background="$background" -v minimum="$minimum" '
    function hex_value(char) {
      return index("0123456789abcdef", tolower(char)) - 1
    }
    function component(hex, offset) {
      return hex_value(substr(hex, offset, 1)) * 16 + hex_value(substr(hex, offset + 1, 1))
    }
    function linear(value) {
      value /= 255
      return value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ^ 2.4
    }
    function luminance(hex) {
      return 0.2126 * linear(component(hex, 2)) + 0.7152 * linear(component(hex, 4)) + 0.0722 * linear(component(hex, 6))
    }
    function contrast(first, second, a, b) {
      a = luminance(first)
      b = luminance(second)
      return a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05)
    }
    function format_color(red, green, blue) {
      return sprintf("#%02x%02x%02x", red, green, blue)
    }
    function mix(color, target, amount, red, green, blue) {
      red = int(component(color, 2) * (1 - amount) + target * amount + 0.5)
      green = int(component(color, 4) * (1 - amount) + target * amount + 0.5)
      blue = int(component(color, 6) * (1 - amount) + target * amount + 0.5)
      return format_color(red, green, blue)
    }
    function adjusted(color, low, high, middle, result, target, step) {
      result = format_color(component(color, 2), component(color, 4), component(color, 6))
      if (contrast(result, background) >= minimum) return result

      target = contrast("#000000", background) >= contrast("#ffffff", background) ? 0 : 255
      low = 0
      high = 1
      for (step = 0; step < 32; step++) {
        middle = (low + high) / 2
        result = mix(color, target, middle)
        if (contrast(result, background) >= minimum) high = middle
        else low = middle
      }
      result = mix(color, target, high)
      for (step = 1; contrast(result, background) < minimum && step <= 255; step++) {
        middle = high + step / 255
        if (middle > 1) middle = 1
        result = mix(color, target, middle)
      }
      return result
    }
    BEGIN {
      if (minimum !~ /^[0-9]+([.][0-9]+)?$/) minimum = 5.5
      if (minimum < 3) minimum = 3
      if (minimum > 21) minimum = 21
    }
    {
      color = adjusted($2)
      printf "%s\t%s\t%.3f\n", $1, color, contrast(color, background)
    }
  '
}

chromarchy::theme_apply() {
  local file=${1:-} category decoration line color ratio scaled adjusted
  local worst_scaled=999999
  local categories=(install remove danger privilege system network vcs container build navigate inspect search editor)
  local candidate_categories=()
  declare -gA CHROMA_THEME_CANDIDATES=()
  CHROMA_THEME_APPLIED=0

  [[ $CHROMA_THEME_INTEGRATION == 1 ]] || return 0
  [[ $file ]] || { chromarchy::theme_find_file || return 0; file=$ret; }
  command -v awk &>/dev/null || return 0
  chromarchy::theme_parse_file "$file"
  chromarchy::theme_resolve_aliases || return 0

  for category in "${categories[@]}"; do
    if [[ ! -v "CHROMA_THEME_MANAGED[$category]" ]]; then
      [[ ${CHROMA_STYLES[$category]} == "${CHROMA_BUILTIN_STYLES[$category]}" ]] &&
        CHROMA_THEME_MANAGED[$category]=1 || CHROMA_THEME_MANAGED[$category]=0
    elif [[ ${CHROMA_THEME_MANAGED[$category]} == 1 &&
            ${CHROMA_STYLES[$category]} != "${CHROMA_THEME_LAST_STYLES[$category]:-}" ]]; then
      CHROMA_THEME_MANAGED[$category]=0
    fi
    chromarchy::theme_category_color "$category" || continue
    CHROMA_THEME_CANDIDATES[$category]=$ret
    candidate_categories+=("$category")
  done

  ((${#candidate_categories[@]})) || return 0
  adjusted=$(chromarchy::theme_adjust_candidates \
    "${CHROMA_THEME_COLORS[background]}" "$CHROMA_MIN_CONTRAST" "${candidate_categories[@]}") || return 0
  [[ $adjusted ]] || return 0

  CHROMA_STYLE_CONTRAST=()
  CHROMA_THEME_WORST_CONTRAST=unknown
  while IFS=$'\t' read -r category color ratio; do
    [[ $category && $color =~ ^#[0-9a-f]{6}$ && $ratio =~ ^[0-9]+[.][0-9]{3}$ ]] || continue
    if [[ ${CHROMA_THEME_MANAGED[$category]:-0} == 1 ]]; then
      decoration=${CHROMA_BUILTIN_STYLES[$category]#*,}
      [[ $decoration == "${CHROMA_BUILTIN_STYLES[$category]}" ]] && decoration=
      CHROMA_STYLES["$category"]="fg=$color${decoration:+,$decoration}"
      CHROMA_THEME_LAST_STYLES[$category]=${CHROMA_STYLES[$category]}
      CHROMA_STYLE_CONTRAST[$category]=$ratio
      scaled=${ratio/./}
      if ((10#$scaled < worst_scaled)); then
        worst_scaled=$((10#$scaled))
        CHROMA_THEME_WORST_CONTRAST=$ratio
      fi
    fi
  done <<< "$adjusted"

  CHROMA_THEME_PATH=$file
  CHROMA_THEME_SNAPSHOT=$(<"$file")
  CHROMA_THEME_BACKGROUND=${CHROMA_THEME_COLORS[background]}
  CHROMA_THEME_MODE=${CHROMA_THEME_COLORS[mode]}
  CHROMA_THEME_SOURCE=omarchy

  local theme_dir=${file%/colors.toml} state_dir name_file
  CHROMA_THEME_NAME=${theme_dir%/}
  CHROMA_THEME_NAME=${CHROMA_THEME_NAME##*/}
  state_dir=${file%/theme/colors.toml}
  name_file=$state_dir/theme.name
  if [[ $state_dir != "$file" && -r $name_file ]]; then
    IFS= read -r line < "$name_file" || true
    [[ $line =~ ^[a-zA-Z0-9._\ -]+$ ]] && CHROMA_THEME_NAME=$line
  fi
  CHROMA_THEME_APPLIED=1
  CHROMA_THEME_ERROR=
  return 0
}

chromarchy::theme_refresh() {
  local file content reload_file reload_token
  # The control panel requests a refresh, never injects input into terminals.
  # Bash reads this small token itself; there is no subprocess per prompt.
  reload_file=${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-chroma/reload
  if [[ -f $reload_file && -r $reload_file ]]; then
    IFS= read -r reload_token < "$reload_file" || reload_token=
    if [[ $reload_token != "${CHROMA_RELOAD_TOKEN:-}" ]]; then
      CHROMA_RELOAD_TOKEN=$reload_token
      CHROMA_THEME_SNAPSHOT=
    fi
  fi
  [[ $CHROMA_THEME_INTEGRATION == 1 ]] || return 0
  chromarchy::theme_find_file || return 0
  file=$ret
  content=$(<"$file")
  [[ $file == "$CHROMA_THEME_PATH" && $content == "$CHROMA_THEME_SNAPSHOT" ]] && return 0
  chromarchy::theme_apply "$file"
}

chromarchy::theme_reload() {
  local file
  CHROMA_THEME_ERROR=

  if [[ $CHROMA_THEME_INTEGRATION != 1 ]]; then
    CHROMA_THEME_ERROR='theme integration is disabled in config.bash'
    return 1
  fi
  if ! command -v awk &>/dev/null; then
    CHROMA_THEME_ERROR='awk is required to calculate accessible theme colors'
    return 1
  fi
  if ! chromarchy::theme_find_file; then
    CHROMA_THEME_ERROR='no readable Omarchy colors.toml was found'
    return 1
  fi
  file=$ret
  chromarchy::theme_apply "$file"
  if [[ $CHROMA_THEME_APPLIED != 1 || $CHROMA_THEME_PATH != "$file" ]]; then
    CHROMA_THEME_ERROR="could not parse a usable background from $file"
    return 1
  fi
  return 0
}
