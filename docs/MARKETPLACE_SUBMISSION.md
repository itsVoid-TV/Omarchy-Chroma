### Repository URL

https://github.com/itsVoid-TV/Omarchy-Chroma

### Category

Developer Tools

### Tags

bar, quickshell, system

### Suggest a missing tag

terminal

### Maintainer notes

Command Chroma adds theme-aware semantic Bash highlighting and an Omarchy
Quattro bar widget with a control panel. The permanent plugin ID is
`io.github.itsvoid-tv.command-chroma`; this is separate from the existing Chroma
color-picker project. The repository name remains Omarchy-Chroma.

Installation uses `omarchy plugin add https://github.com/itsVoid-TV/Omarchy-Chroma.git --enable`.
Adding/enabling the widget only loads the panel. **Set up in terminal** opens an
English terminal installer, with the Chroma logo animated by the same `ttfx`
engine as Omarchy's screensaver (`tte` or a static logo as fallbacks). This button
does not grant Bash installation consent.

The terminal review requires explicit confirmation before installing bundled
code into the user's XDG data directory and adding a marked `.bashrc` loader.
Existing `.bashrc` content is backed up; configuration, symlinks and disabled
state are preserved. Missing ble.sh is downloaded from a pinned release with
SHA-256 verification. The plugin does not install system packages or use sudo.
Uninstalling the Bash integration is a separate, confirmed panel action; removing
the widget alone does not undo Bash setup.

Runtime dependencies: Omarchy Quattro/Quickshell, Python 3 (standard library),
Bash 4.4+, ble.sh, coreutils, awk, curl, tar/xz and util-linux `script` for isolated
diagnostics. `ttfx`/`tte` is optional. User `config.bash` is executable trusted
configuration; passive status checks and the installation review do not source
it or `.bashrc`. There is no telemetry or terminal-history access by the plugin.

The default-branch source is MIT licensed. Root `preview.png` is an actual
xterm capture of the safe installer preview, with no personal data. README images
include real Bash/ble.sh terminal captures and clearly labelled Qt sample-data
renders; they are not AI-generated product mockups.

Automated verification covers parser/theme behavior, safe install/update/remove,
21 bridge tests, 10 bootstrap tests, 15 terminal/PTY tests, real pinned ttfx and
ble.sh, Qt control-view tests and ShellCheck. See
https://github.com/itsVoid-TV/Omarchy-Chroma/actions/runs/34716371852
and the repository's `docs/REVIEW-2026-09-12.md` for the tested scope.

Native Omarchy/Wayland acceptance is still pending on the owner's computer,
particularly panel placement/focus, configured-terminal launching and multiple
monitors. Please keep this limitation in view during review; no native-device
acceptance or security certification is claimed. The owner will provide the
remaining desktop screenshot and test results.

### Submission checklist

- [x] The repository is public and contains installation and removal instructions.
- [x] I have documented the plugin license and any external dependencies.
- [ ] I confirm that I own or have permission to submit this plugin and its preview assets.
- [x] The plugin does not overwrite user configuration without explicit consent.
- [ ] I understand that approval is for listing and is not a security review.
