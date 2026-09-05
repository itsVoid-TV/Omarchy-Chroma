#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
: "${CHROMA_BLESH_PATH:?set CHROMA_BLESH_PATH to the tested ble.sh file}"
command -v script >/dev/null || { printf 'script(1) is required for the PTY test\n' >&2; exit 1; }

export CHROMA_TEST_ROOT=$root

run_case() {
  local theme=$1 file=$2 background=$3 install=$4 rgb=$5 output
  if ! output=$(
    TERM=xterm-256color \
    COLORTERM=truecolor \
    CHROMA_THEME_FILE=$file \
    CHROMA_EXPECTED_THEME=$theme \
    CHROMA_EXPECTED_BACKGROUND=$background \
    CHROMA_EXPECTED_INSTALL=$install \
    CHROMA_EXPECTED_INSTALL_RGB=$rgb \
      script -qfec "bash --noprofile --rcfile '$root/tests/ble-integration.rc' -i" /dev/null
  ); then
    printf '%s\n' "$output"
    exit 1
  fi
  printf '%s\n' "$output"
  grep -Fq "ok - real ble.sh ANSI render: $theme" <<< "$output"
}

run_case vantablack "$root/tests/fixtures/vantablack/colors.toml" \
  '#000000' '#cecece' '206;206;206'
run_case white "$root/tests/fixtures/white/colors.toml" \
  '#ffffff' '#4a4a4a' '74;74;74'
