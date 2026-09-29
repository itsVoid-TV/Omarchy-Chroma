# Changelog

## 0.4.3 — 2026-09-29

- Limited the pinned ble.sh archive to 8 MiB while downloading. curl rejects
  oversized responses, and a bounded output pipe protects even older curl
  versions or responses without Content-Length. The checksum still validates
  the complete archive before extraction; failed downloads leave the live
  installation and `.bashrc` untouched. Tested an oversized streaming response.
- Documented how to disable Omarchy's Starship blank line above the first
  terminal prompt without changing unrelated user settings in the installer.

## 0.4.2 — 2026-09-29

- Bounded the control panel helper's combined stdout and stderr to 64 KiB
  while reading, including palette inspection of executable user configuration.
  A noisy or looping helper is stopped with a clear error instead of filling
  the bridge's memory before the timeout. Added stdout/stderr flood regressions.

## 0.4.1 — 2026-09-19

- Removed mutable-branch fetches from both shipped installers. Setup validates
  and installs a local snapshot; standalone installation requires local sources.
  ZIP snapshots have no Git metadata; Git-managed installs use Omarchy plugin add.
- Enter accepts multiline buffers in Emacs and Vi modes, with normal unfinished
  command continuation in Emacs/Vi insert. `CHROMA_ENTER_ACCEPT=0` preserves
  upstream or custom bindings. Bracketed paste and speed detection stay intact.
- Added live MULTILINE/paste diagnostics and documented Ctrl+C recovery, safe
  pasting, opt-out and snapshot updates.
- Added installer no-fetch regressions and actual ble.sh PTY input tests,
  including delayed keymaps, opt-out, cancellation and diagnostic side effects.
- Made configuration regression assertions fail the suite immediately.

## 0.4.0 — Command Chroma plugin (development)

- Prepared publication on main with the standard Omarchy add command, a main
  ZIP bootstrap and a documented transition for existing development checkouts.
- Added verified terminal captures in Catppuccin, Vantablack and White, clearly
  labelled Qt dashboard examples, root Marketplace preview and a sourced review.
- Prepared a Marketplace request with native-device limitations disclosed;
  owner checklist/text approval and Marketplace admission remain pending.
- Moved the first-run installer entirely into the terminal, in English, using
  Omarchy's `ttfx` screensaver engine (original `tte` fallback) for the Chroma logo.
- Added review, explicit terminal consent, real progress, visible errors, safe
  preview mode, no-motion/no-color options, narrow-layout and static fallbacks.
- Removed the superseded QML setup wizard; the panel now opens the terminal
  without granting Bash consent or tying the installer to the panel's lifetime.
- Added a short colored `./setup` bootstrap for testing the non-default branch;
  it creates a validated Git checkout, then interactively continues to a separate
  Bash review in the same terminal. `--yes` alone still confirms only the widget.
- Added an Omarchy Quattro bar-widget manifest, terminal icon and native panel.
- Added opt-in setup/update, enable/disable for new shells, theme refresh,
  isolated Doctor, color legend and separate Bash removal.
- Added pre-change `.bashrc` backups, serialized mutations, argument-based
  process launching, timeouts and machine-readable errors.
- Kept existing `omarchy-chroma` paths and the `chroma` command for compatibility.
- Made the `.bashrc` loader tolerate a missing installation and honor a pause flag.
- Added XDG-aware theme discovery and a next-prompt reload request token.
- Added offline lifecycle, real terminal/PTY, pinned-ttfx and Qt control-view tests,
  plus actual xterm screenshots in CI; the installer suite
  now fails immediately when an assertion fails.
- Marketplace submission and native Omarchy/Wayland acceptance remain separate
  release gates; adding the widget never silently sets up Bash.

## 0.3.0 — 2026-09-09

- Add `chroma explain` for inspecting token categories and source ranges
  without executing the command.
- Distinguish command lookups such as `command -v rm` from execution, keep
  render spans ordered, and understand option-bearing `env`, `exec`, `time`,
  `nice`, `stdbuf`, `ionice`, `taskset`, and `chrt` wrappers.
- Recognize forced Git pushes, forced branch deletion, power-state actions,
  additional disk tools, Pipx actions, and modern Nix subcommands.
- Validate user toggles, arrays, styles, and contrast values; expose any
  recoveries through the expanded `chroma doctor` report.
- Make theme reload failures actionable and include every semantic category in
  the interactive legend.
- Stage and atomically activate installations, preserve symlinked `.bashrc`
  files, detect system ble.sh under `/usr/local`, and require Git only when a
  repository clone is actually needed.
- Prevent malformed loader markers from deleting unrelated `.bashrc` content
  during an update or uninstall, while normalizing duplicate complete blocks.
- Expand regression coverage for parsing, config recovery, theme reload,
  rollback, loader-marker corruption, and symlink-safe lifecycle operations.
- Pin the GitHub Actions checkout step to a reviewed commit.

## 0.2.1 — 2026-09-05

- Resolve the installation directory with Bash built-ins so Omarchy's
  output-producing `cd`/`zd` alias cannot corrupt `CHROMA_ROOT` at startup.
- Validate the installation before sourcing modules, reducing a partial
  install to one actionable error instead of a cascade of shell messages.
- Disable ble.sh's red parse/argument backgrounds and `[ble: exit N]` marker
  by default while preserving Chroma's semantic danger highlighting.
- Reproduce the stock Omarchy alias in the real pseudo-terminal integration
  test and assert silent startup, registered rendering, and neutral error faces.

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
