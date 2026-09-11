#!/usr/bin/env python3
"""Capture the actual terminal installer in xterm/Xvfb; no image synthesis.

Run with: xvfb-run -a python3 tests/capture_terminal.py
The preview is read-only and contains neutral sample paths, never user data.
"""
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent


def terminal_child(marker):
    result = subprocess.run([sys.executable, str(ROOT / "scripts/chroma-installer"), "--preview"], check=False)
    if result.returncode:
        return result.returncode
    print("\n  Press Enter to close this preview.", flush=True)
    marker.write_text("ready", encoding="utf-8")
    try:
        input()
    except EOFError:
        pass
    return 0


def capture():
    with tempfile.TemporaryDirectory(prefix="chroma-terminal-capture-") as temporary:
        marker = Path(temporary) / "ready"
        terminal = subprocess.Popen([
            "xterm", "-title", "Chroma Terminal Installer Preview", "-geometry", "100x38",
            "-fa", "DejaVu Sans Mono", "-fs", "12", "-bg", "#111018", "-fg", "#edeaf4",
            "-xrm", "XTerm*internalBorder: 18", "-e", sys.executable, str(Path(__file__).resolve()),
            "--child", str(marker)], env={**os.environ, "COLORTERM": "truecolor"})
        try:
            deadline = time.monotonic() + 25
            while not marker.exists():
                if terminal.poll() is not None:
                    raise RuntimeError("xterm exited before the installer preview was ready")
                if time.monotonic() > deadline:
                    raise RuntimeError("The terminal preview did not finish rendering")
                time.sleep(0.1)
            tree = subprocess.check_output(["xwininfo", "-root", "-tree"], text=True)
            match = re.search(r'(0x[0-9a-f]+) "Chroma Terminal Installer Preview"', tree)
            if not match:
                raise RuntimeError("Could not find the preview terminal window")
            time.sleep(0.3)  # Let the final glyphs reach Xvfb before grabbing pixels.
            output = ROOT / "chroma-terminal-installer.png"
            subprocess.run(["import", "-window", match.group(1), str(output)], check=True, timeout=10)
            print(f"Actual xterm screenshot saved: {output}")
        finally:
            terminal.terminate()
            try:
                terminal.wait(timeout=5)
            except subprocess.TimeoutExpired:
                terminal.kill()
                terminal.wait(timeout=5)


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--child":
        sys.exit(terminal_child(Path(sys.argv[2])))
    capture()
