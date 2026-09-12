# Testing Command Chroma 0.4

The plugin is available from `main`, but native Omarchy acceptance and Marketplace
admission remain pending. The repository is still `itsVoid-TV/Omarchy-Chroma`.

## Try the plugin on Omarchy Quattro

```bash
omarchy plugin add https://github.com/itsVoid-TV/Omarchy-Chroma.git --enable
```

Then open the Chroma logo and choose **Set up in terminal**. Existing installations
should update instead of running add again; see the sections below.

Review the source first. Omarchy plugins run unsandboxed in your desktop shell.
As an alternative, download and extract the
[main ZIP](https://github.com/itsVoid-TV/Omarchy-Chroma/archive/refs/heads/main.zip),
then open a terminal inside its folder:

```bash
./setup
```

Use `python3 setup` if the executable bit was lost while extracting. The
bootstrap displays the repository and branch, asks before downloading, validates
the manifest, refuses existing directories or duplicate IDs, and enables the
widget. It clones an independent Git checkout, so the extracted folder can be
deleted afterwards and Omarchy updates continue to work. Interactive setup then
continues into the Bash installer **in the same terminal**, with a second consent
prompt. `./setup --yes` installs only the widget and never bypasses Bash consent.

If the widget is already present, click the Chroma logo and **Set up in terminal**,
or run `./setup --bash` inside its checkout. Every setup screen is English and
runs in the terminal, including the animated Chroma logo (`ttfx`, then `tte` as
a fallback), review, confirmation, progress and result. The review shows the
destination, `.bashrc` loader, backup policy and optional dependency. Enter skips
the intro; Escape cancels. At the review, only `y` installs; Enter / `n` / Escape
cancels. Confirmed setup backs up `.bashrc`, installs the bundled Bash code, and
downloads pinned ble.sh only if needed. Previous configuration is preserved.
Open a new Bash terminal after setup and run `chroma doctor`.

`./setup --preview` is safe for screenshots: neutral sample paths, no config
evaluation, no writes and no downloads. `--no-animation` disables motion;
`NO_COLOR=1` disables color and motion. Missing effects do not block installation.

No repository rename is needed to use the new display name or plugin ID.
Omarchy's add command intentionally never executes plugin hooks; the terminal
installer is opened explicitly from the panel after the widget is enabled.

## Move an existing development checkout to main

Only do this if `git branch --show-current` reports `codex/command-chroma-plugin`
inside the installed plugin directory:

```bash
cd ~/.config/omarchy/plugins/io.github.itsvoid-tv.command-chroma
git status --short
git branch --show-current
```

If `git status --short` prints local changes, preserve/review them before changing
branches. With a clean checkout, add the main tracking branch without removing
the development branch, then switch and update:

```bash
git remote set-branches --add origin main
git fetch origin
git switch main
git branch --set-upstream-to=origin/main main
git pull --ff-only
```

Git refuses conflicting local changes or a divergent update; do not reset or
force it. Then use the normal update command below.

## Update an existing plugin

```bash
omarchy plugin update io.github.itsvoid-tv.command-chroma
```

Review the update, then open the panel and choose **Set up in terminal** if it
shows a Bash update. Updating the widget alone never overwrites installed Bash
code. The installed copy remains usable if the widget checkout is removed.

## Acceptance checklist on a real Omarchy session

- [ ] Extracting the ZIP and running `./setup` shows the animated logo, asks
  before cloning, enables the widget, and continues into a separate Bash review
  in the same terminal. Cancelling that review leaves `.bashrc` untouched.
- [ ] **Set up in terminal** opens the configured Omarchy terminal. It does not
  approve Bash setup on the user's behalf, and closing the panel does not kill it.
- [ ] The English terminal review shows correct paths; Escape/Enter/n cancels,
  y installs, errors remain visible and a later retry is possible.
- [ ] The actual `ttfx` beams animation works; older `tte`, missing tools,
  `--no-animation`, `NO_COLOR`, and a narrow terminal behave sensibly.
- [ ] Skipping the animation cannot approve setup; Ctrl-C / terminal-close
  restores terminal modes and stops only this installer's helper processes.
- [ ] Plugin validate, enable, disable, re-enable and remove behave correctly.
- [ ] The icon opens and closes its panel on top/bottom/left/right bars.
- [ ] Escape closes it, Tab navigates buttons, outside-click and switching to
  another panel dismiss it, and reopening after each route works.
- [ ] Multiple monitors do not duplicate a mutation; another instance sees
  updates on refresh. Removing/hiding the widget does not silently alter Bash.
- [ ] Before setup, enabling/opening the widget or launching its terminal leaves
  `.bashrc` unchanged until confirmation inside that terminal.
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
Terminal tests use real PTYs for consent, Escape, Ctrl-C, mode restoration and
successful setup in isolated paths. CI builds `ttfx` at a pinned commit and tests
the actual effect command and terminal flow, without installing it on a user's machine.
ShellCheck, the pinned ble.sh and the pinned upstream palettes enable further
checks. Qt rendering tests require Qt 6 Quick/Controls/Layouts/QtTest modules:

```bash
CHROMA_QMLTESTRUNNER=/usr/lib/qt6/bin/qmltestrunner bash tests/run.bash
```

The Qt test writes `chroma-dark.png`, `chroma-light.png`, `chroma-narrow.png`, and
`chroma-first-run.png`. These are control-panel fixtures, not live Omarchy screenshots.
CI additionally captures the real installer in an xterm under Xvfb using
`xvfb-run -a python3 tests/capture_terminal.py`. Its `chroma-terminal-installer.png`
is an actual terminal screenshot in safe preview mode, not a generated mockup;
it still does not replace the native Omarchy / Wayland acceptance checks.

`tests/capture_highlighting.py` opens isolated real Bash/ble.sh sessions under
xterm/Xvfb and types a literal example without Return. The Catppuccin, Vantablack
and White captures contain no executed example commands or user history.
The Catppuccin palette is copied from Omarchy commit
`493067741e081c3b09082da6bfd51e99ec24ef00`; the other two use the existing test fixtures.
Reproduce them with `CHROMA_BLESH_PATH=/path/to/ble.sh xvfb-run -a python3 tests/capture_highlighting.py`.
Required capture tools are xterm, Xvfb, xauth, xdotool, xwininfo, ImageMagick and
DejaVu Sans Mono. They are test tools, not plugin runtime dependencies.
