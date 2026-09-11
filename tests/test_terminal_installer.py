"""Real PTY consent/cancellation tests and isolated terminal installer lifecycle."""
import errno
import fcntl
import importlib.machinery
import importlib.util
import io
import json
import os
from pathlib import Path
import pty
import select
import signal
import struct
import subprocess
import sys
import tempfile
import termios
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
import installer_ui as ui

loader = importlib.machinery.SourceFileLoader("terminal_installer", str(ROOT / "scripts/chroma-installer"))
spec = importlib.util.spec_from_loader(loader.name, loader)
installer = importlib.util.module_from_spec(spec)
loader.exec_module(installer)


class TerminalTests(unittest.TestCase):
    def setUp(self):
        self.fixture = tempfile.TemporaryDirectory(prefix="chroma terminal ' ")
        self.addCleanup(self.fixture.cleanup)
        self.base = Path(self.fixture.name)
        self.env = os.environ.copy()
        self.env.update({"XDG_DATA_HOME": str(self.base / "data"),
                         "XDG_CONFIG_HOME": str(self.base / "config"),
                         "XDG_STATE_HOME": str(self.base / "state"),
                         "CHROMA_BASHRC": str(self.base / "bashrc"),
                         "CHROMA_INSTALL_BLESH": "0", "TERM": "xterm-256color",
                         "CHROMA_THEME_FILE": str(ROOT / "tests/fixtures/vantablack/colors.toml")})
        self.bashrc = self.base / "bashrc"
        self.bashrc.write_text("# preserve my Bash settings\n")
        self.original = self.bashrc.read_bytes()

    def invoke(self, *args, command=None):
        return subprocess.run(command or [sys.executable, str(ROOT / "scripts/chroma-installer"), *args],
                              env=self.env, capture_output=True, text=True, timeout=30)

    def fake_ble(self):
        ble = self.base / "data/blesh/ble.sh"
        ble.parent.mkdir(parents=True)
        ble.write_text("# Presence fixture, not a real ble.sh engine.\n")

    def assert_untouched(self):
        self.assertEqual(self.bashrc.read_bytes(), self.original)
        self.assertFalse((self.base / "data/omarchy-chroma").exists())
        self.assertFalse((self.base / "state").exists())

    def test_noninteractive_refuses_before_any_changes(self):
        result = self.invoke()
        self.assertEqual(result.returncode, 1)
        self.assertIn("in a terminal", result.stdout)
        self.assertNotIn("\x1b", result.stdout)
        self.assert_untouched()

    def test_review_does_not_execute_user_config_or_startup(self):
        marker = self.base / "unexpected-execution"
        settings = self.base / "config/omarchy-chroma"
        settings.mkdir(parents=True)
        hook = settings / "config.bash"
        hook.write_text('printf executed > "' + str(marker) + '"\n')
        self.env["BASH_ENV"] = str(hook)
        self.env["ENV"] = str(hook)
        code, output = self.terminal_action(b"n")
        self.assertEqual(code, 0, output)
        self.assertFalse(marker.exists())
        self.assert_untouched()

    def test_preview_is_read_only_even_with_broken_paths(self):
        self.env["CHROMA_BASHRC"] = "/not/a/real/path"
        result = self.invoke("--preview")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("PREVIEW ONLY", result.stdout)
        self.assertIn("WHAT WILL CHANGE", result.stdout)
        self.assertNotIn(str(self.base), result.stdout)
        self.assert_untouched()
        result = self.invoke(command=[sys.executable, str(ROOT / "setup"), "--preview"])
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_yes_installs_with_backup_and_keeps_disabled_setting(self):
        self.fake_ble()
        settings = self.base / "config/omarchy-chroma"
        settings.mkdir(parents=True)
        (settings / "disabled").write_text("paused\n")
        result = self.invoke("--yes")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("03 READY", result.stdout)
        self.assertIn("Not enabled for new terminals yet: disabled", result.stdout)
        backups = list((self.base / "state/omarchy-chroma/backups").glob("*.bak"))
        self.assertTrue(backups)
        self.assertEqual(backups[0].read_bytes(), self.original)
        self.assertEqual(self.bashrc.read_text().count("# >>> omarchy-chroma >>>"), 1)

    def test_malformed_loader_refused_and_retry_is_explicit(self):
        self.bashrc.write_text("# >>> omarchy-chroma >>>\n# leave me alone\n")
        self.original = self.bashrc.read_bytes()
        result = self.invoke("--yes")
        self.assertEqual(result.returncode, 1)
        self.assertIn("malformed", result.stdout)
        self.assertIn("./setup --bash", result.stdout)
        self.assert_untouched()

    def test_bad_helper_response_is_not_reported_as_success(self):
        terminal = ui.Terminal()
        for payload in (b"not json", b'{}', json.dumps({"schemaVersion": 1, "ok": False, "message": "fixture error"}).encode()):
            with patch.object(terminal, "run_helper", return_value=(1, payload, b"")):
                with self.assertRaises(RuntimeError):
                    installer.reply(terminal, "setup", confirmed=True)

    def test_effect_argv_matches_ttfx_and_tte(self):
        for name in ("ttfx", "tte"):
            argv = ui.effect_command(name)
            self.assertEqual(argv[0], name)
            self.assertLess(argv.index("--frame-rate"), argv.index("beams"))
            self.assertGreater(argv.index("--final-gradient-stops"), argv.index("beams"))
            self.assertNotIn("--no-restore-cursor", argv)
            self.assertNotIn("--random-effect", argv)

    def test_no_color_and_missing_engine_skip_safely(self):
        terminal = ui.Terminal()
        terminal.interactive = True
        terminal.color = True
        terminal.width = 80
        with patch.object(ui.shutil, "which", return_value=None), patch("sys.stdout", new=io.StringIO()):
            self.assertFalse(terminal.animate())
        with patch.dict(os.environ, {"NO_COLOR": "1"}), patch.object(sys.stdout, "isatty", return_value=True):
            self.assertFalse(ui.Terminal().color)
        terminal.no_animation = True
        with patch.object(ui.shutil, "which") as lookup:
            self.assertFalse(terminal.animate())
            lookup.assert_not_called()

    def test_terminal_escape_sequences_are_not_forwarded(self):
        self.assertEqual(ui.safe("\x1b]52;c;secret\x07\x1b[31mhello\x1b[0m\u202e"), "hello")

    def test_helpers_use_english_diagnostics_without_startup_hooks(self):
        with patch.dict(os.environ, {"LC_ALL": "de_DE.UTF-8", "BASH_ENV": "/unused", "ENV": "/unused"}):
            env = ui.child_env()
        self.assertEqual(env["LC_ALL"], "C.UTF-8")
        self.assertNotIn("BASH_ENV", env)
        self.assertNotIn("ENV", env)

    def terminal_action(self, key, *, animation=False, columns=80):
        master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 38, columns, 0, 0))
        initial = termios.tcgetattr(slave)
        argv = [sys.executable, str(ROOT / "scripts/chroma-installer")]
        if not animation:
            argv.append("--no-animation")
        process = subprocess.Popen(argv, stdin=slave, stdout=slave, stderr=slave,
                                   env=self.env, start_new_session=True)
        output = bytearray()
        sent = False
        deadline = time.monotonic() + 15
        try:
            while time.monotonic() < deadline:
                if select.select([master], [], [], 0.05)[0]:
                    try:
                        part = os.read(master, 65536)
                    except OSError as error:
                        if error.errno == errno.EIO:
                            break
                        raise
                    output.extend(part)
                if not sent and b"[Enter / n / Esc] Cancel" in output:
                    # The UI flushes queued keys immediately before reading.
                    time.sleep(0.03)
                    if key == b"\x03":
                        process.send_signal(signal.SIGINT)
                    else:
                        os.write(master, key)
                    sent = True
                if process.poll() is not None:
                    break
            self.assertTrue(sent, output.decode(errors="replace"))
            self.assertIsNotNone(process.poll(), "terminal installer hung")
            self.assertEqual(termios.tcgetattr(slave), initial, "terminal modes were not restored")
            return process.returncode, output.decode(errors="replace")
        finally:
            ui.stop_process(process)
            os.close(master)
            os.close(slave)

    def test_escape_enter_and_ctrl_c_are_nonmutating(self):
        for key, expected in ((b"\x1b", 0), (b"\n", 0), (b"n", 0), (b"\x03", 130)):
            code, output = self.terminal_action(key)
            self.assertEqual(code, expected, output)
            self.assert_untouched()

    def test_real_tty_yes_installs_from_quoted_path(self):
        self.fake_ble()
        code, output = self.terminal_action(b"y")
        self.assertEqual(code, 0, output)
        self.assertIn("03 READY", output)
        self.assertTrue((self.base / "data/omarchy-chroma/chromarchy.bash").is_file())

    def test_narrow_tty_uses_compact_brand(self):
        code, output = self.terminal_action(b"n", columns=40)
        self.assertEqual(code, 0)
        self.assertIn(">_", output)
        self.assert_untouched()

    @unittest.skipUnless(os.environ.get("CHROMA_TTFX_REQUIRED"), "real ttfx not required locally")
    def test_real_ttfx_in_a_tty_finishes_and_preserves_consent(self):
        self.assertIsNotNone(ui.shutil.which("ttfx"))
        checked = subprocess.run(ui.effect_command("ttfx"), stdin=subprocess.DEVNULL,
                                 stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=12)
        self.assertEqual(checked.returncode, 0, checked.stderr.decode(errors="replace"))
        code, output = self.terminal_action(b"n", animation=True)
        self.assertEqual(code, 0, output)
        self.assertNotIn("Animation unavailable", output)
        self.assertNotIn("Animation exited unsuccessfully", output)
        self.assertNotIn("Animation could not start", output)
        self.assertIn("\x1b[?1049h", output)
        self.assertIn("\x1b[?1049l", output)
        self.assert_untouched()


if __name__ == "__main__":
    unittest.main(verbosity=2)
