# Testing Command Chroma 0.4

This branch is a development build, not a stable release or an approved
Marketplace entry. The repository is still `itsVoid-TV/Omarchy-Chroma`.

## Try the plugin branch on Omarchy Quattro

Review the source first. Omarchy plugins run unsandboxed in your desktop shell.
Download and extract the
[development ZIP](https://github.com/itsVoid-TV/Omarchy-Chroma/archive/refs/heads/codex/command-chroma-plugin.zip),
then open a terminal inside its folder:

```bash
./setup
```

Use `python3 setup` if the executable bit was lost while extracting. The
bootstrap displays the repository and branch, asks before downloading, validates
the manifest, refuses existing directories or duplicate IDs, and enables the
widget. It clones an independent Git checkout, so the extracted folder can be
deleted afterwards and Omarchy updates continue to work.

Click the Chroma logo. The guided installer previews the colors and then shows
the destination, `.bashrc` loader, backup policy and optional dependency before
asking for final confirmation. Back or Escape makes no Bash changes. Install
backs up `.bashrc`, installs the bundled Bash code, and downloads the pinned
ble.sh only if needed. Previous Chroma configuration is preserved. Open a new
Bash terminal after setup.

No repository rename is needed to use the new display name or plugin ID. Do
not use `omarchy plugin add` against default `main` until the plugin has actually
been merged there; `main` is currently the standalone Bash implementation.
Also note that Omarchy's add command intentionally never executes plugin hooks;
after the future `omarchy plugin add … --enable`, the user opens the logo to
start this guided installer.

## Update the development checkout

```bash
omarchy plugin update io.github.itsvoid-tv.command-chroma
```

Review the update, then open the panel and choose **Set up / update** if it
shows a Bash update. Updating the widget alone never overwrites installed Bash
code. The installed copy remains usable if the widget checkout is removed.

## Acceptance checklist on a real Omarchy session

- [ ] Extracting the ZIP and running `./setup` shows its colored banner, asks
  before cloning, enables the widget, and leaves `.bashrc` untouched.
- [ ] First opening shows the welcome page; Back/Escape is non-mutating, the
  review paths are correct, failure can be retried, and success opens the dashboard.
- [ ] Plugin validate, enable, disable, re-enable and remove behave correctly.
- [ ] The icon opens and closes its panel on top/bottom/left/right bars.
- [ ] Escape closes it, Tab navigates buttons, outside-click and switching to
  another panel dismiss it, and reopening after each route works.
- [ ] Multiple monitors do not duplicate a mutation; another instance sees
  updates on refresh. Removing/hiding the widget does not silently alter Bash.
- [ ] Before setup, enabling/opening the widget leaves `.bashrc` unchanged.
- [ ] Cancel setup leaves `.bashrc` unchanged. Confirm setup produces a backup
  and exactly one marked loader; existing Bash setup and symlinks survive.
- [ ] The panel and terminal remain readable in Vantablack and White, including
  narrow screens and non-default font/scale settings.
- [ ] In a new terminal, `chroma doctor` passes and `chroma legend` looks correct.
- [ ] Wrapper commands, Tab completion, Ctrl-R, and Omarchy aliases still work.
- [ ] Disable stops loading Chroma in a new terminal; re-enable restores it.
- [ ] Theme reload reaches the next prompt in already loaded 0.4+ shells.
- [ ] Failed/missing dependencies show errors; the interface does not hang.
- [ ] Remove Bash integration preserves unrelated `.bashrc` content, user color
  config, ble.sh and backups; a subsequent new terminal starts normally.

An offscreen Qt test validates the control view, not Quickshell's actual
Wayland positioning, host lifecycle, multiple monitors, or your terminal setup.
Do not mark these items done solely from unit-test results.

## Recovery and removal

Use **Remove Bash integration…**, confirm, then:

```bash
omarchy plugin remove io.github.itsvoid-tv.command-chroma
```

If the panel cannot load, the standalone uninstaller remains available:

```bash
bash "${XDG_DATA_HOME:-$HOME/.local/share}/omarchy-chroma/uninstall.sh"
```

Open a fresh terminal afterwards. If Bash startup itself is broken, start
`bash --norc` first. Backups live under
`${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-chroma/backups/`; inspect and compare
them before restoring so newer, unrelated `.bashrc` edits are not lost.

## Automated tests

```bash
bash tests/run.bash
```

Python 3 and Node run the bridge/model tests without third-party packages.
The development bootstrap tests use real local Git repositories plus a simulated
Omarchy host to cover cancel, validation, collisions, branch updates and recovery.
ShellCheck, the pinned ble.sh and the pinned upstream palettes enable further
checks. Qt rendering tests require Qt 6 Quick/Controls/Layouts/QtTest modules:

```bash
CHROMA_QMLTESTRUNNER=/usr/lib/qt6/bin/qmltestrunner bash tests/run.bash
```

The Qt test writes `chroma-dark.png`, `chroma-light.png`, and `chroma-narrow.png`
to its working directory. These are test fixtures, not screenshots of a live
Omarchy session.
