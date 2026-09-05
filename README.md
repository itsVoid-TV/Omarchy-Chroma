# Omarchy Chroma

Semantic command colors for the stock **Omarchy Bash terminal**.

Chroma colors what a command *does* while you type it. Package installation is yellow, removal is red, privileged wrappers are orange, Git is purple, network commands are cyan, and destructive commands are bright red and underlined.

It works in Foot, Ghostty, Alacritty, Kitty, and other 256-color terminals because the feature lives in Bash rather than in one terminal emulator.

## Install

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/itsVoid-TV/omarchy-chroma/main/install.sh)"
```

Then open a new terminal and check the installation:

```bash
chroma doctor
chroma legend
```

The installer uses only user-owned XDG directories, adds one marked block to `~/.bashrc`, and does **not** call `sudo`. If `ble.sh` is missing, it downloads one pinned build and verifies its SHA-256 checksum before installing it locally.

Prefer reviewing before running? Clone the repository first:

```bash
git clone https://github.com/itsVoid-TV/omarchy-chroma.git
cd omarchy-chroma
./install.sh
```

## Colors

| Meaning | Default style | Examples |
|---|---|---|
| Install / update | Yellow, bold | `pacman -Syu`, `flatpak install`, `npm install` |
| Remove | Coral red, bold | `pacman -Rns`, `flatpak uninstall`, `docker rm` |
| Dangerous | Bright red, bold, underlined | `rm`, `dd`, `mkfs`, `git reset --hard` |
| Privileged | Orange, bold | `sudo`, `doas`, `pkexec` |
| System | Amber | `systemctl`, `mount`, `chmod` |
| Git / VCS | Purple, bold | `git`, `gh`, `lazygit` |
| Network | Cyan | `curl`, `wget`, `ssh`, `rsync` |
| Containers | Blue | `docker`, `podman`, `kubectl` |
| Build / runtime | Green | `make`, `cargo`, `go`, `node` |
| Navigation / inspection / search / editors | Blue-green variants | `cd`, `bat`, `rg`, `nvim` |

Chroma understands wrappers and shell chains. For example, in:

```bash
sudo env LANG=C pacman -Syu firefox && git status
```

`sudo` is orange, `pacman -Syu` is yellow, and `git status` is purple. Arguments such as `firefox` keep normal `ble.sh` syntax highlighting.

## Customize

Edit:

```text
~/.config/omarchy-chroma/config.bash
```

Examples:

```bash
CHROMA_STYLES[install]='fg=yellow,bold'
CHROMA_STYLES[danger]='fg=white,bg=red,bold'

CHROMA_EXTRA_INSTALL_COMMANDS+=(my-installer)
CHROMA_EXTRA_REMOVE_COMMANDS+=(my-uninstaller)
CHROMA_EXTRA_DANGER_COMMANDS+=(my-disk-wiper)
```

Open a new terminal after changing the configuration.

## Update

Re-run the installer; your config file is preserved:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/itsVoid-TV/omarchy-chroma/main/install.sh)"
```

For a cloned checkout, use `git pull` and run `./install.sh` again.

## Uninstall

```bash
~/.local/share/omarchy-chroma/uninstall.sh
```

Add `--purge` to remove the user color configuration too. The uninstaller deliberately keeps `ble.sh`, because other Bash add-ons may use it.

## Troubleshooting

Run:

```bash
chroma doctor
```

If Bash input ever behaves incorrectly, open a clean recovery shell with:

```bash
bash --norc
```

You can then run the uninstaller or temporarily comment out the marked `omarchy-chroma` block in `~/.bashrc`.

Chroma is a visual hint, not a security boundary. It never blocks a command, and a heuristic cannot understand every script, alias, shell function, or program-specific option.

## Design and privacy

- Built for Omarchy's current Bash initialization; it does not switch your login shell.
- Adds a semantic layer after `ble.sh`'s normal syntax/error highlighting.
- Uses `ble.sh`'s fzf adapter so Omarchy's completion and history bindings keep working.
- No `eval` in the parser, no subprocess per keystroke, no telemetry, and no network requests while typing.
- No OpenAI API key is needed. Deterministic local classification is faster and avoids exposing typed terminal input.
- User changes stay in `~/.bashrc` and `~/.config`; `/usr/share/omarchy` is never modified.

The approach follows the current [Omarchy Bash configuration](https://github.com/omacom/omarchy/blob/quattro/default/bashrc), the [Omarchy dotfiles guidance](https://github.com/omacom/omarchy/blob/quattro/manual/31-dotfiles.md), and the official [`ble.sh` extension model](https://github.com/akinomyoga/ble.sh).

## Development

```bash
bash tests/run.bash
```

The suite covers semantic parsing, shell wrappers, operators, quotes, redirections, comments, fresh installation, idempotent update, config preservation, uninstall, ShellCheck, and a render test against the exact pinned `ble.sh` build.

## License

MIT. `ble.sh` is a separate BSD-3-Clause dependency and is not vendored into this repository.
