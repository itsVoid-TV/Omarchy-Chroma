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
