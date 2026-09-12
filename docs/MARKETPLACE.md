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

1. Review the [prepared submission body](MARKETPLACE_SUBMISSION.md), titled
   **`[Plugin]: Command Chroma`**, and confirm all five checklist statements.
   The Marketplace's [AI-agent submission instructions](https://github.com/omacom/omarchy-plugin-marketplace/blob/main/SUBMISSION.md#instructions-for-ai-agents)
   require the owner to approve the completed text and checklist before posting.
2. Finish the real-device checklist in `PLUGIN_TESTING.md`, or explicitly retain
   the pending native-test disclosure in the maintainer notes. Do not claim that
   Qt/Xvfb proves Omarchy/Wayland behavior.
3. Check current `main`, its CI results, and permanent-ID availability immediately
   before posting. Indexed searches found no matching ID/repository submission;
   the full registry exceeded the connector's file-size limit, so this is not a
   guarantee that a historical/reserved ID is available.
4. The main installation command and bootstrap branch are prepared. Root
   `preview.png` is an actual terminal screenshot; its provenance is in
   `images/README.md`. Replace the native-desktop placeholder after a device test.
5. Submit the exact reviewed revision. Validation, a security-baseline result,
   owner approval, and maintainer admission are separate steps. No submission,
   Marketplace approval, or stable release is claimed by these files.

## Facts for the maintainer notes

- Native Quattro bar-widget entry point with a real control panel.
- Branded English terminal installer with the same `ttfx` engine as Omarchy's
  screensaver, explicit review/consent, progress, errors and completion guidance.
  The panel launches it without silently granting install consent.
- ZIP bootstrap creates a validated, updateable checkout of `main`; standard
  installation uses Omarchy's `plugin add` command.
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
