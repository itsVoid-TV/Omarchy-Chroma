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
  "$root/lib/theme.bash" \
  "$root/scripts/palette.bash" \
  "$root/scripts/doctor.rc" \
  "$root/tests/test_config.bash" \
  "$root/tests/test_parser.bash" \
  "$root/tests/test_theme.bash" \
  "$root/tests/test_install.bash" \
  "$root/tests/test_ble_integration.bash"; do
  bash -n "$file"
done

bash "$root/tests/test_config.bash"
bash "$root/tests/test_parser.bash"
bash "$root/tests/test_theme.bash"
bash "$root/tests/test_install.bash"
python3 "$root/tests/test_plugin.py"
python3 "$root/tests/test_setup.py"
python3 "$root/tests/test_terminal_installer.py"
node "$root/tests/test_model.js"

if [[ ${CHROMA_QMLTESTRUNNER:-} ]]; then
  QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QUICK_CONTROLS_STYLE=Basic \
    "$CHROMA_QMLTESTRUNNER" -input "$root/tests/qml"
else
  printf 'note: CHROMA_QMLTESTRUNNER unset; Qt control-view render tests skipped\n'
fi

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
    "$root/lib/theme.bash" \
    "$root/scripts/palette.bash" \
    "$root/scripts/doctor.rc" \
    "$root/tests/"*.bash
else
  printf 'note: shellcheck not installed; static ShellCheck pass skipped\n'
fi
