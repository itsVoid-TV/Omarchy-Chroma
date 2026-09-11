# Marketplace preparation — not submitted

Proposed metadata:

- Display name: **Command Chroma**
- Repository: `https://github.com/itsVoid-TV/Omarchy-Chroma`
- Permanent plugin ID: `io.github.itsvoid-tv.command-chroma`
- Category: **Developer Tools**
- Tag: **system**
- Suggested additional reusable tag: **terminal**

Keep the repository URL until the owner explicitly chooses a rename. The new
name distinguishes the terminal add-on from existing Chroma color-picker
projects. Recheck permanent-ID availability before submitting.

## Before submission

1. Complete the real-device acceptance checklist in `PLUGIN_TESTING.md`.
2. Review the final CI results and record the exact tested commit SHA.
3. Merge the reviewed plugin to the repository's default branch; update the
   development ZIP wording and `setup` branch constant at that time. The README
   already contains the standard `omarchy plugin add … --enable` release flow.
4. Add an actual, representative preview screenshot without personal data.
5. Re-read the current Marketplace submission/security rules and submit the
   exact final revision. An automated validation pass is not approval or a
   security guarantee.

## Facts for the maintainer notes

- Native Quattro bar-widget entry point with a real control panel.
- Branded English terminal installer with the same `ttfx` engine as Omarchy's
  screensaver, explicit review/consent, progress, errors and completion guidance.
  The panel launches it without silently granting install consent.
- Development ZIP bootstrap creates a validated, updateable Git checkout; the
  release installation remains Omarchy's standard `plugin add` command.
- Bash 4.4+, ble.sh, Python 3 standard library, coreutils/awk and util-linux.
  An existing `ttfx` / `tte` is optional; a static logo works without either.
- No sudo, system package installation, telemetry, or terminal-history access.
- Enabling the widget does not install anything or edit `.bashrc`.
- Explicit setup confirmation explains the marked `.bashrc` change and the
  pinned/checksummed GitHub download of ble.sh if absent.
- Existing configuration and `.bashrc` symlinks survive; pre-change backups
  are retained. Malformed managed blocks are refused by the shared local bridge.
- Changes to `.bashrc`, downloads, and executable Chroma config must be disclosed
  for review. QML plugins and Bash config are not sandboxed.
- Widget lifecycle and Bash lifecycle are distinct and documented. Removal of
  the Bash integration is explicit; existing shells are not forcefully changed.

References:

- [Submission guide](https://github.com/omacom/omarchy-plugin-marketplace/blob/main/SUBMISSION.md)
- [Marketplace security policy](https://github.com/omacom/omarchy-plugin-marketplace/blob/main/SECURITY.md)
- [Omarchy shell contract](https://github.com/omacom/omarchy/blob/quattro/shell/README.md)
