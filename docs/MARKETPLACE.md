# Marketplace review

The active submission is [omacom/omarchy-plugin-marketplace#8501](https://github.com/omacom/omarchy-plugin-marketplace/issues/8501).
The requested listing name is **Omarchy-Chroma**; the manifest still uses
**Command Chroma** and permanent ID `io.github.itsvoid-tv.command-chroma`.
These identify the same terminal-highlighting project. No repository or ID
rename is part of this fix.

## Revision 0.4.3

The maintainer found that the mandatory pinned ble.sh download still lacked a
response-size bound. `install.sh` now caps that response at 8 MiB while it is
received: curl rejects known or streaming oversize responses, and `head`
limits the temporary file to at most 8 MiB plus one byte even with older curl.
The installer checks the final byte count before the unchanged SHA-256
verification, then extracts only the verified archive. Oversized or failed
transfers abort before activation, preserve the original `.bashrc`, and clean
the temporary file. A local no-Content-Length streaming server exercises both
the current curl path and a shim emulating older curl behavior.

Omarchy's stock `starship.toml` separately enables `add_newline`, which creates
an empty line before the first terminal prompt. The README gives the one-line
user configuration change; the plugin does not silently change Starship.

## Revision 0.4.2

The maintainer's follow-up identified unbounded `Popen.communicate()` output
in the Python control bridge. It now reads stdout and stderr incrementally with
a shared 64 KiB cap and a deadline. On excess output or timeout it stops the
entire helper process group, closes both pipes and reports an error. Regression
tests cover a looping `config.bash`, stderr floods and ordinary small output.
The earlier installer fix remains in place.

## Revision 0.4.1

The maintainer blocked the previous revision because `setup` and the fallback
in `install.sh` cloned mutable `main`. Both remote Chroma-fetch paths are removed:

- `setup` copies the local source without Git metadata, validates the staged
  snapshot and enables that copy. It preserves consent, collision checks and
  activation recovery. ZIP snapshots require explicit replacement; use
  Omarchy's `plugin add` command for Git-managed updates.
- `install.sh` requires complete local sources beside itself or via `--source
  DIR`. Missing, detached and incomplete sources fail before installation
  changes; there is no remote fallback.
- Missing ble.sh remains the only installer download: its existing immutable
  asset name and SHA-256 verification are unchanged.
- Enter accepts multiline input in Emacs and Vi keymaps, configurable through
  `CHROMA_ENTER_ACCEPT`. Bracketed paste remains enabled; Doctor and README
  explain the settings and Ctrl+C recovery.

See [the verification and fork audit](REVIEW-2026-09-19.md),
[security boundaries](../SECURITY.md), and [native test checklist](PLUGIN_TESTING.md).
The original 0.4.0 submission draft is retained in `MARKETPLACE_SUBMISSION.md`
for history; it is not the current review evidence.

## Review handoff

Post the complete tested 40-character commit SHA, link its successful CI run,
and explain both bounded helper output and the ble.sh download cap in the
existing issue. Approval
and listing remain the maintainer's decision. Automated test success does not
establish native Omarchy/Wayland acceptance or a security certification.

No sudo, system package installation, telemetry, or terminal-history access is
introduced. Enabling the widget does not install the Bash integration. The
terminal installer still requires its separate confirmation and retains
configuration, disabled state, backups and unrelated `.bashrc` contents.
