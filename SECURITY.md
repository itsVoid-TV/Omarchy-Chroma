# Security

## Reporting

Please report a suspected vulnerability privately through GitHub's security advisory feature for this repository. Do not include secrets or real command history in a public issue.

## Security model

Omarchy Chroma is presentation software, not a command sandbox. A color never guarantees that a command is safe, and an uncolored command is not necessarily harmless.

The parser does not call `eval`, execute the typed line, launch a subprocess,
send telemetry, or make network requests. Omarchy's `colors.toml` is parsed as
data and is never sourced.

The installer modifies only user-owned paths, stages a complete release before
activation, preserves the previous installation until the `.bashrc` update
succeeds, and never follows malformed loader markers past a verified closing
marker. It pins the downloaded `ble.sh` archive and verifies its SHA-256
checksum before extraction. GitHub Actions dependencies are pinned to immutable
revisions.

## Command Chroma plugin boundary

The QML widget and Bash integration are separate. Enabling the widget performs
only passive local status checks. Setup, enable/disable and removal require an
explicit confirmation; setup uses the bundled checkout and saves a `.bashrc`
backup. No plugin action calls sudo or installs system packages. Setup can
download the pinned, SHA-256-verified ble.sh archive from GitHub when missing.

Omarchy's `plugin add` intentionally never executes plugin hooks. Chroma does
not bypass that boundary: its first-run installer is UI only until the user
reviews the changes and presses the final install button. The separate `./setup`
development bootstrap only clones, validates and enables the widget; it does
not install the Bash engine or touch `.bashrc`.

The Python bridge invokes fixed argv lists, serializes mutations with a lock,
and bounds helper execution time. It removes BASH_ENV/ENV from helper
environments and never sources `.bashrc`. Palette inspection and the explicit
Doctor **do** execute the user's trusted Chroma `config.bash`. It is executable
Bash configuration, not an untrusted data format or a sandbox boundary.

The panel collects no command history, terminal contents, credentials or
telemetry. Legend examples are display-only. Doctor uses a fresh PTY and does
not introspect other terminal processes. Custom styles are excluded from the
reported theme-managed contrast minimum.

Removing the widget does not run uninstall hooks or remove the Bash integration.
Use its explicit removal action first if both should be removed. User settings,
ble.sh and `.bashrc` backups are retained. Disabling the Bash add-on affects new
shells; already open shells keep their loaded state.
