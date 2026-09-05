#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)

for file in \
  "$root/chromarchy.bash" \
  "$root/install.sh" \
  "$root/uninstall.sh" \
  "$root/config/defaults.bash" \
  "$root/config/config.example.bash" \
  "$root/lib/parser.bash" \
  "$root/lib/layer.bash" \
  "$root/tests/test_parser.bash" \
  "$root/tests/test_install.bash" \
  "$root/tests/test_ble_integration.bash"; do
  bash -n "$file"
done

bash "$root/tests/test_parser.bash"
bash "$root/tests/test_install.bash"

if [[ ${CHROMA_BLESH_PATH:-} ]]; then
  bash "$root/tests/test_ble_integration.bash"
else
  printf 'note: CHROMA_BLESH_PATH is unset; real ble.sh integration pass skipped\n'
fi

if command -v shellcheck >/dev/null; then
  shellcheck -x \
    "$root/chromarchy.bash" \
    "$root/install.sh" \
    "$root/uninstall.sh" \
    "$root/config/defaults.bash" \
    "$root/lib/parser.bash" \
    "$root/lib/layer.bash" \
    "$root/tests/"*.bash
else
  printf 'note: shellcheck not installed; static ShellCheck pass skipped\n'
fi
