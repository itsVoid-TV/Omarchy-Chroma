# Screenshot checklist

The three SVG files in this folder are layout placeholders, not generated
screenshots. Before a Marketplace submission, replace each README reference
with the matching real WebP image below.

## `installer.webp`

- Open Command Chroma before installing the Bash integration.
- Capture the complete welcome page with its Chroma logo, three setup steps and
  semantic command-color preview.
- Use Vantablack or another recognizably dark Omarchy theme.
- Crop to the panel with a small amount of bar context. Target roughly 1280×720.
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
screenshots.
