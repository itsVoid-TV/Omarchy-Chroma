#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
: "${CHROMA_BLESH_PATH:?set CHROMA_BLESH_PATH to the tested ble.sh file}"
command -v script >/dev/null || { printf 'script(1) is required for the PTY test\n' >&2; exit 1; }

export CHROMA_TEST_ROOT=$root
output=$(script -qfec "bash --noprofile --rcfile '$root/tests/ble-integration.rc' -i" /dev/null)
printf '%s\n' "$output"
grep -Fq 'ok - real ble.sh layer registration and render' <<< "$output"

