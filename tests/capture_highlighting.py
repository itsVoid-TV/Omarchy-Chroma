#!/usr/bin/env python3
"""Capture real Bash/ble.sh editing in xterm, with dark and light theme fixtures.

Requires Xvfb, xterm, xdotool, xwininfo, ImageMagick and the pinned ble.sh.
Run: CHROMA_BLESH_PATH=/path/to/ble.sh xvfb-run -a python3 tests/capture_highlighting.py
The example is typed without Return; no example command is executed.
"""
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
EXAMPLE = "sudo pacman -Syu firefox && git status && curl https://example.com && command -v rm"


def capture(theme, background, foreground):
    ble = Path(os.environ["CHROMA_BLESH_PATH"]).resolve(strict=True)
    title = f"Chroma Bash Highlighting - {theme}"
    with tempfile.TemporaryDirectory(prefix="chroma-highlight-capture-") as temporary:
        folder = Path(temporary)
        marker = folder / "ready"
        env = os.environ.copy()
        for name in ("BASH_ENV", "ENV", "PROMPT_COMMAND", "BLE_VERSION", "CHROMA_ROOT",
                     "CHROMA_LAYER_READY", "CHROMA_THEME_HOOK_READY"):
            env.pop(name, None)
        env.update({"LC_ALL": "C.UTF-8", "COLORTERM": "truecolor", "INPUTRC": "/dev/null",
                    "HISTFILE": "/dev/null", "XDG_CONFIG_HOME": str(folder / "config"),
                    "XDG_DATA_HOME": str(folder / "data"), "XDG_STATE_HOME": str(folder / "state"),
                    "XDG_CACHE_HOME": str(folder / "cache"), "CHROMA_BLESH_PATH": str(ble),
                    "CHROMA_CAPTURE_ROOT": str(ROOT), "CHROMA_CAPTURE_READY": str(marker),
                    "CHROMA_THEME_FILE": str(ROOT / "tests/fixtures" / theme / "colors.toml")})
        terminal = subprocess.Popen([
            "xterm", "-title", title, "-geometry", "110x32", "-fa", "DejaVu Sans Mono",
            "-fs", "12", "-bg", background, "-fg", foreground, "-cr", foreground,
            "-xrm", "XTerm*internalBorder: 18", "-e", "bash", "--noprofile", "--rcfile",
            str(ROOT / "tests/capture_highlighting.rc"), "-i"], cwd=folder, env=env)
        try:
            deadline = time.monotonic() + 25
            while not marker.exists():
                if terminal.poll() is not None:
                    raise RuntimeError(f"The {theme} Bash session exited before its first prompt")
                if time.monotonic() > deadline:
                    raise RuntimeError(f"The {theme} Bash prompt did not become ready")
                time.sleep(0.1)
            tree = subprocess.check_output(["xwininfo", "-root", "-tree"], text=True)
            match = re.search(r'(0x[0-9a-f]+) "' + re.escape(title) + '"', tree)
            if not match:
                raise RuntimeError("The screenshot terminal window was not found")
            window = match.group(1)
            subprocess.run(["xdotool", "windowfocus", "--sync", window], check=True, timeout=5)
            time.sleep(0.3)
            # Only literal text is sent to this isolated Xvfb session. No Return,
            # newline, paste wrapper, shell evaluation or actual package operation.
            subprocess.run(["xdotool", "type", "--clearmodifiers", "--delay", "8", "--", EXAMPLE],
                           check=True, timeout=10)
            time.sleep(0.8)
            output = ROOT / f"chroma-highlighting-{theme}.png"
            subprocess.run(["import", "-window", window, str(output)], check=True, timeout=10)
            print(f"Actual Bash/ble.sh screenshot saved: {output}")
        finally:
            terminal.terminate()
            try:
                terminal.wait(timeout=5)
            except subprocess.TimeoutExpired:
                terminal.kill()
                terminal.wait(timeout=5)


if __name__ == "__main__":
    capture("vantablack", "#000000", "#eeeeee")
    capture("white", "#ffffff", "#222222")
