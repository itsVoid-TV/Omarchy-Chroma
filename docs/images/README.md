# Screenshot checklist

The three SVG files in this folder are layout placeholders, not generated
screenshots. Before a Marketplace submission, replace each README reference
with the matching real WebP image below.

## Included terminal preview

`installer-terminal-preview.png` is an unedited capture of the actual installer
running in xterm under Xvfb, after the real `ttfx` intro. It was captured by
`tests/capture_terminal.py` in the [verified CI run](https://github.com/itsVoid-TV/Omarchy-Chroma/actions/runs/34593647649)
for commit `2f6bdb2cb7eade224a8f28499c77ddcb7f4e8429`.
It uses safe preview mode and neutral sample paths. It is not a native Omarchy
screenshot; keep the gallery placeholders until you capture the images below.

## `installer.webp`

- Run `./setup --preview` in an Omarchy terminal. This shows neutral sample paths
  without reading config, downloading anything, or installing Chroma.
- Capture the terminal after the ttfx logo animation, with the Chroma wordmark,
  English review and safety notice visible. Use roughly 100 columns × 38 rows.
- Use Vantablack or another recognizably dark Omarchy theme.
- Crop to the terminal with a small amount of desktop context. Target roughly 1280×720.
- Do not show usernames, home paths, notifications, tokens or unrelated apps.

## `dashboard.webp`

- Finish setup, open a new terminal, and make sure `chroma doctor` passes first.
- Capture the enabled dashboard with theme name, contrast values and all actions
  visible. A light Omarchy theme gives the gallery useful visual variety.
- Hide or crop personal filesystem paths and notifications.

## `terminal.webp`

- Use a clean terminal with a neutral prompt and no command history.
- Type safe examples without executing them, such as `pacman -Syu`,
  `git status`, `curl https://example.com`, and `command -v rm`.
- Include `chroma legend` only if the result fits without making text tiny.
- Never stage a real destructive command containing a personal path.

After adding the real files, change these README paths:

- `docs/images/installer-placeholder.svg` → `docs/images/installer.webp`
- `docs/images/dashboard-placeholder.svg` → `docs/images/dashboard.webp`
- `docs/images/terminal-placeholder.svg` → `docs/images/terminal.webp`

Keep the placeholders until every replacement has been reviewed at GitHub's
rendered README size. Do not claim offscreen Qt test renders are real Omarchy
screenshots. CI also captures the actual terminal installer in xterm/Xvfb via
`tests/capture_terminal.py` and publishes `chroma-terminal-installer.png` in the
render artifact. It is a real terminal screenshot in preview mode, not an AI
image, but not evidence of native Omarchy / Wayland behavior.
