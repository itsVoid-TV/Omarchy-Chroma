# Screenshot guide

The gallery now includes real terminal captures and actual Qt component renders.
No image-generation model or painted terminal mockup was used. PNG files are
copied byte-for-byte from the corresponding GitHub Actions artifacts.

## Included images

| File | What it actually shows | Source |
| --- | --- | --- |
| `installer-terminal-preview.png` | xterm/Xvfb, after the real ttfx intro, in read-only preview mode | [CI 34593647649](https://github.com/itsVoid-TV/Omarchy-Chroma/actions/runs/34593647649), commit `2f6bdb2cb7eade224a8f28499c77ddcb7f4e8429` |
| `highlighting-catppuccin.png` | Real Bash/ble.sh editing with Omarchy's colorful Catppuccin palette | [CI 34716371852](https://github.com/itsVoid-TV/Omarchy-Chroma/actions/runs/34716371852), commit `35df92190422b240573956ca314b45f126ae654f` |
| `highlighting-vantablack.png` | Real Bash/ble.sh editing on the black theme fixture | [CI 34716085992](https://github.com/itsVoid-TV/Omarchy-Chroma/actions/runs/34716085992), commit `55ec7307d178e9bd462772f95339e40f3771d222` |
| `highlighting-white.png` | Real Bash/ble.sh editing on the white theme fixture | Same run as Vantablack |
| `dashboard-dark-preview.png` | Shipped Qt control view with dark sample status and contrast data | Same run as Vantablack |
| `dashboard-light-preview.png` | Shipped Qt control view with light sample data and a disabled state | Same run as Vantablack |
| `dashboard-first-run-preview.png` | Shipped Qt control view before installation, with sample data | Same run as Vantablack |
| `../../preview.png` | Exact copy of the installer capture for the Marketplace's root preview slot | Same bytes as `installer-terminal-preview.png` |

Terminal captures have no user startup files or history. The example is typed
into the actual line editor without Return; no package, network, Git or removal
command in that example is executed. `chroma legend` is actual Chroma output.
The Qt dashboard values are fixtures, not measurements of a real desktop.

The Catppuccin fixture is copied from [Omarchy's palette at the pinned theme
commit](https://github.com/omacom/omarchy/blob/493067741e081c3b09082da6bfd51e99ec24ef00/themes/catppuccin/colors.toml).
Black and white fixtures intentionally preserve their monochrome appearance.

## Still needed: one native Omarchy desktop image

Save an actual on-device capture as **`docs/images/omarchy-desktop.webp`**:

1. Install/update Chroma and complete **Set up in terminal**.
2. Open a new Bash terminal and check `chroma doctor`.
3. Open the Chroma dashboard from its icon in the Omarchy bar.
4. Capture the bar icon and open dashboard together. Keep the theme name and
   contrast/status visible, with enough surrounding desktop to show placement.
5. Hide notifications and personal paths; aim for readable text around 1280×720.

In the root README, replace `docs/images/dashboard-placeholder.svg` with
`docs/images/omarchy-desktop.webp`, and update its caption to name the actual
Omarchy version/theme. Keep a native capture separate from the Qt sample renders.

An additional native installer image is optional: run `./setup --preview` in
your Omarchy terminal, capture the English review after the logo animation, and
save it as `docs/images/installer.webp`. The existing real xterm screenshot already
illustrates the terminal installer itself.

The older installer/terminal SVG placeholders remain available for layout work,
but the README no longer displays them. Do not relabel Qt fixtures as native
Omarchy screenshots or mark Wayland/multi-monitor acceptance complete from PNGs.

## Reproduce the captures

```bash
xvfb-run -a python3 tests/capture_terminal.py
CHROMA_BLESH_PATH=/path/to/ble.sh xvfb-run -a python3 tests/capture_highlighting.py
```

Use the pinned ble.sh build and capture dependencies recorded in
`.github/workflows/test.yml`. The workflow runs both commands and retains the
resulting images for seven days; the reviewed gallery copies are versioned here.
