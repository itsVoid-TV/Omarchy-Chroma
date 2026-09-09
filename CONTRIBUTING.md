# Contributing

Bug reports should include the typed example command, expected category, actual category, Bash version, `ble.sh` version, and the output of `chroma doctor`. Remove usernames, tokens, hostnames, and private paths first.

Before opening a pull request, run:

```bash
bash tests/run.bash
```

Add a parser fixture for every classification change, including both the
positive match and any nearby query/option form that must not be misclassified.
Semantic spans must remain ordered by source position. Keep the per-keystroke
path pure Bash: no `eval`, filesystem scans, network requests, or
subprocesses.

Installer changes must prove that a failed update leaves the previous release
intact and that malformed loader markers cannot consume unrelated `.bashrc`
content. Configuration changes need a fallback assertion in
`tests/test_config.bash`.

Theme changes should include a dark and light fixture. CI additionally sets
`CHROMA_OMARCHY_THEMES_DIR` to a pinned checkout of Omarchy and verifies every
bundled palette. Color tests must assert the composed `ble.sh` ANSI output, not
only parser spans or internal array sizes.
