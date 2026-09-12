"""English terminal presentation shared by the bootstrap and Bash installer.

Animation is optional and uses the same program as Omarchy's screensaver:
ttfx, or the original tte on older systems. Nothing is downloaded here.
"""
from contextlib import contextmanager
import os
from pathlib import Path
import re
import select
import shutil
import signal
import subprocess
import sys
import termios
import textwrap
import time
import tty

ROOT = Path(__file__).resolve().parent.parent
LOGO = ROOT / "assets/chroma.txt"
GRADIENT = ("a970ff", "ff5da2", "52d6ff")


class Cancelled(Exception):
    """An explicit Escape, no, or end-of-input, before any installation."""


def safe(text):
    """Make paths and external diagnostics inert on an interactive terminal."""
    text = str(text)
    text = re.sub(r"\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)", "", text)
    text = re.sub(r"\x1b\[[0-?]*[ -/]*[@-~]", "", text)
    text = re.sub(r"\x1b[ -/]*[0-~]", "", text)
    return re.sub(r"[\x00-\x08\x0b-\x1f\x7f-\x9f\u202a-\u202e\u2066-\u2069]", "", text)


def child_env():
    env = os.environ.copy()
    env.pop("BASH_ENV", None)
    env.pop("ENV", None)
    # Dependency diagnostics are English too, even on a localized desktop.
    env["LC_ALL"] = "C.UTF-8"
    return env


def stop_process(process):
    """Stop only our own process group, never other ttfx/screensaver sessions."""
    if process.poll() is not None:
        return
    try:
        os.killpg(process.pid, signal.SIGTERM)
        process.wait(timeout=3)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait(timeout=3)
    except ProcessLookupError:
        pass


@contextmanager
def keyboard():
    descriptor = sys.stdin.fileno()
    original = termios.tcgetattr(descriptor)
    try:
        tty.setcbreak(descriptor)
        yield descriptor
    finally:
        termios.tcsetattr(descriptor, termios.TCSADRAIN, original)


def effect_command(binary, logo=LOGO):
    # Terminal options precede the effect; effect options follow it in both CLIs.
    return [binary, "-i", str(logo), "--frame-rate", "120", "--canvas-width", "-1",
            "--canvas-height", "-1", "beams", "--beam-delay", "1",
            "--final-gradient-stops", *GRADIENT, "--final-gradient-direction",
            "horizontal", "--final-gradient-frames", "2"]


class Terminal:
    def __init__(self, *, no_animation=False):
        self.interactive = sys.stdin.isatty() and sys.stdout.isatty()
        self.color = (sys.stdout.isatty() and "NO_COLOR" not in os.environ
                      and os.environ.get("TERM", "dumb") != "dumb")
        self.no_animation = no_animation
        self.width = max(20, min(92, shutil.get_terminal_size((80, 24)).columns - 4))

    def paint(self, text, color="a970ff", *, bold=False):
        text = safe(text)
        if not self.color:
            return text
        rgb = tuple(int(color[n:n + 2], 16) for n in (0, 2, 4))
        return f"\033[{1 if bold else 0};38;2;{rgb[0]};{rgb[1]};{rgb[2]}m{text}\033[0m"

    def say(self, text="", color=None, *, bold=False):
        for line in safe(text).split("\n"):
            for part in textwrap.wrap(line, self.width, replace_whitespace=False) or [""]:
                print("  " + (self.paint(part, color, bold=bold) if color else part), flush=True)

    def rule(self):
        self.say("─" * self.width, "a970ff")

    def restore(self):
        if self.color:
            print("\033[0m\033[?25h", end="", flush=True)

    def animate(self):
        if not self.interactive or not self.color or self.no_animation or self.width < 58:
            return False
        binary = shutil.which("ttfx") or shutil.which("tte")
        if not binary:
            self.say("Animation unavailable: ttfx/tte is not installed. Using the static logo.")
            return False
        # Keep the transient effect off the user's scrollback, then return to
        # the original buffer for one clean, persistent review page.
        process = None
        try:
            print("\033[?1049h\033[H", end="", flush=True)
            self.say("COMMAND CHROMA  /  Enter skips the intro · Esc cancels", "52d6ff")
            with keyboard() as descriptor:
                process = subprocess.Popen(effect_command(binary), stdin=subprocess.DEVNULL,
                                           stderr=subprocess.DEVNULL, env=child_env(),
                                           start_new_session=True)
                deadline = time.monotonic() + 8
                while process.poll() is None:
                    if time.monotonic() >= deadline:
                        break
                    if select.select([descriptor], [], [], 0.05)[0]:
                        key = os.read(descriptor, 1)
                        if key in (b"\x1b", b"\x04"):
                            raise Cancelled()
                        # Consume the skip key so it can never approve setup.
                        break
                if process.poll() not in (None, 0):
                    self.say("Animation exited unsuccessfully. Using the static logo.")
                return process.poll() == 0
        except OSError:
            self.say("Animation could not start. Continuing with the static logo.")
            return False
        finally:
            try:
                if process is not None:
                    stop_process(process)
            finally:
                print("\033[?1049l", end="", flush=True)
                self.restore()

    def banner(self, subtitle="TERMINAL SETUP"):
        print()
        if self.width >= 58:
            for row in LOGO.read_text(encoding="utf-8").splitlines():
                rendered = []
                for index, char in enumerate(row):
                    position = index / max(1, len(row) - 1) * 2
                    first = min(1, int(position))
                    fraction = position - first
                    left, right = GRADIENT[first:first + 2]
                    color = "".join(f"{round(int(left[n:n+2],16)*(1-fraction)+int(right[n:n+2],16)*fraction):02x}"
                                    for n in (0, 2, 4))
                    rendered.append(self.paint(char, color))
                print("  " + "".join(rendered), flush=True)
        else:
            self.say(">_ COMMAND CHROMA", "a970ff", bold=True)
        self.say("COMMAND CHROMA  /  " + subtitle, "52d6ff", bold=True)
        self.say("Give your commands meaning. Keep your terminal yours.")
        self.rule()

    def confirm(self, prompt):
        if not self.interactive:
            raise RuntimeError("Confirmation requires a terminal. Use --yes only after reviewing the source.")
        self.say(prompt, "52d6ff", bold=True)
        self.say("[y] Yes   [Enter / n / Esc] Cancel", "a970ff")
        with keyboard() as descriptor:
            # Discard queued keystrokes: skipping the intro is not consent.
            termios.tcflush(descriptor, termios.TCIFLUSH)
            while True:
                key = os.read(descriptor, 1).lower()
                if key == b"y":
                    self.say("Yes")
                    return True
                if key in (b"", b"n", b"\r", b"\n", b"\x1b", b"\x04"):
                    self.say("Cancelled.")
                    return False

    def run_helper(self, action, *, confirmed=False):
        argv = [sys.executable, str(ROOT / "scripts/chroma-control"), action]
        if confirmed:
            argv.append("--confirm")
        process = subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, env=child_env(), start_new_session=True)
        deadline = time.monotonic() + (270 if action == "setup" else 15)
        frames = "|/-\\"
        tick = 0
        try:
            while True:
                try:
                    stdout, stderr = process.communicate(timeout=0.1)
                    return process.returncode, stdout, stderr
                except subprocess.TimeoutExpired:
                    if time.monotonic() > deadline:
                        raise RuntimeError("Setup timed out. Its helper was stopped; review the status before retrying.")
                    if action == "setup" and self.color:
                        print("\r  " + self.paint(frames[tick % 4] + " Installing bundled code / checking ble.sh…", "52d6ff"), end="", flush=True)
                        tick += 1
        finally:
            stop_process(process)
            if action == "setup" and self.color:
                print("\r\033[2K", end="", flush=True)
            self.restore()


def review(ui, snapshot, *, preview=False):
    ui.banner("PREVIEW · NO CHANGES" if preview else "TERMINAL SETUP")
    ui.say("01 REVIEW    →    02 INSTALL    →    03 READY", "a970ff", bold=True)
    ui.say("Semantic Bash highlighting · theme-aware colors · 5.5:1 contrast target")
    ui.say()
    ui.say("WHAT WILL CHANGE", "52d6ff", bold=True)
    ui.say("Bash code:  " + snapshot.get("installPath", "(unknown)"))
    ui.say("Loader:     " + snapshot.get("bashrc", "(unknown)"))
    ui.say("Backup:     saved before changing an existing .bashrc")
    ui.say("ble.sh:     " + ("use the existing local installation" if snapshot.get("blePath")
                               else "download a pinned, SHA-256-verified build if missing"))
    ui.say("Settings:   preserved, including an existing disabled state")
    ui.say()
    ui.say("No sudo. No system packages. No history access. No telemetry.")
    ui.say("Uses this plugin checkout; never downloads Bash code from main.")
    ui.rule()
    if snapshot.get("malformed"):
        ui.say("The existing Chroma loader is malformed. Repair it before setup; nothing will be overwritten.", "ff5da2")
    if preview:
        ui.say("PREVIEW ONLY — no configuration was read, downloaded, or changed.", "ff5da2")
