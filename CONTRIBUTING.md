# Contributing

Bug reports should include the typed example command, expected category, actual category, Bash version, `ble.sh` version, and the output of `chroma doctor`. Remove usernames, tokens, hostnames, and private paths first.

Before opening a pull request, run:

```bash
bash tests/run.bash
```

Add a parser fixture for every classification change. Keep the per-keystroke path pure Bash: no `eval`, filesystem scans, network requests, or subprocesses.

