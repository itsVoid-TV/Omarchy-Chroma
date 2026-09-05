# Changelog

## 0.2.0 — 2026-09-05

- Follow Omarchy's active semantic `colors.toml` on shell start and after theme
  switches.
- Emit theme-native 24-bit foreground colors and lift faint palette entries to
  a default minimum contrast ratio of 5.5:1.
- Preserve explicit user style overrides and add `chroma reload` plus expanded
  theme diagnostics.
- Keep automatic ghost-text suggestions disabled while preserving Tab
  completion.
- Audit every bundled Omarchy theme at pinned commit
  `493067741e081c3b09082da6bfd51e99ec24ef00`.
- Verify real `ble.sh` RGB/ANSI output in Vantablack and White pseudo-terminals,
  in addition to parser, installer, and ShellCheck tests.

## 0.1.1 — 2026-09-05

- Disable automatic ghost-text suggestions by default while preserving Tab completion.
- Extend `chroma doctor` to verify that the semantic render layer is registered.
- Exercise the complete loader and suggestion setting in the real `ble.sh` integration test.

## 0.1.0 — 2026-09-04

- Initial semantic highlighting layer for Omarchy's Bash shell.
- Package, removal, danger, privilege, system, Git, network, container, build, navigation, inspection, search, and editor categories.
- Wrapper awareness for `sudo`, `doas`, `env`, `command`, `timeout`, and related commands.
- Safe user-local installer with pinned, checksummed `ble.sh` dependency.
- Idempotent install/update, config preservation, diagnostics, and clean uninstall.
- Parser, installer, ShellCheck, and real `ble.sh` render tests.
