"""Real ble.sh PTY tests: paste must wait for an intentional submit or cancel."""
import errno
import fcntl
import os
from pathlib import Path
import pty
import select
import shlex
import signal
import struct
import termios
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parent.parent
BLE = os.environ.get("CHROMA_BLESH_PATH")


@unittest.skipUnless(BLE, "CHROMA_BLESH_PATH is required for real input tests")
class InputTests(unittest.TestCase):
    def start_shell(self, mode="emacs", policy="1", after_load="", before_load=""):
        fixture = tempfile.TemporaryDirectory(prefix="chroma-input-")
        self.addCleanup(fixture.cleanup)
        self.base = Path(fixture.name)
        self.output = bytearray()
        self.marker = self.base / "executed"
        config = self.base / "config/omarchy-chroma"
        config.mkdir(parents=True)
        (config / "config.bash").write_text(f"CHROMA_ENTER_ACCEPT={policy}\n")
        rc = self.base / "rc"
        rc.write_text(f"""HISTFILE=/dev/null
set +o history
set -o {mode}
PS1='INPUT_READY> '
PS2='CONTINUE> '
source {shlex.quote(BLE)} --attach=none
{before_load}
source {shlex.quote(str(ROOT / 'chromarchy.bash'))}
{after_load}
ble-attach
""")
        env = dict(os.environ, HOME=str(self.base), XDG_DATA_HOME=str(self.base / "data"),
                   XDG_CONFIG_HOME=str(self.base / "config"), XDG_CACHE_HOME=str(self.base / "cache"),
                   XDG_RUNTIME_DIR=str(self.base / "run"), INPUTRC="/dev/null", TERM="xterm-256color",
                   CHROMA_THEME_FILE=str(ROOT / "tests/fixtures/vantablack/colors.toml"))
        Path(env["XDG_RUNTIME_DIR"]).mkdir(mode=0o700)
        env.pop("BASH_ENV", None)
        env.pop("ENV", None)
        pid, self.fd = pty.fork()
        if pid == 0:
            os.execvpe("bash", ["bash", "--noprofile", "--rcfile", str(rc), "-i"], env)
        self.pid = pid
        self.addCleanup(self.stop_shell)
        fcntl.ioctl(self.fd, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 120, 0, 0))
        self.wait_for(lambda: b"INPUT_READY>" in self.output, "shell readiness")

    def stop_shell(self):
        try:
            os.killpg(self.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        os.waitpid(self.pid, 0)
        os.close(self.fd)

    def read(self, duration=0.1):
        if select.select([self.fd], [], [], duration)[0]:
            try:
                data = os.read(self.fd, 65536)
            except OSError as error:
                if error.errno == errno.EIO:
                    self.fail("shell exited: " + self.output.decode(errors="replace")[-3000:])
                raise
            self.output.extend(data)
            # Respond to the terminal cursor-position query without real xterm.
            if b"\x1b[6n" in data:
                os.write(self.fd, b"\x1b[1;1R")

    def wait_for(self, condition, label, timeout=15):
        deadline = time.monotonic() + timeout
        while not condition() and time.monotonic() < deadline:
            self.read()
        self.assertTrue(condition(), label + ": " + self.output.decode(errors="replace")[-3000:])

    def send(self, data):
        os.write(self.fd, data)

    def assert_no_execution(self):
        deadline = time.monotonic() + 0.35
        while time.monotonic() < deadline:
            self.read(0.05)
        self.assertFalse(self.marker.exists(), "input ran before explicit acceptance")

    def paste_commands(self):
        command = f"printf first >> {shlex.quote(str(self.marker))}\nprintf second >> {shlex.quote(str(self.marker))}\n"
        self.send(b"\x1b[200~" + command.encode() + b"\x1b[201~")
        self.assert_no_execution()

    def assert_submitted(self):
        self.wait_for(lambda: self.marker.exists() and self.marker.read_text() == "firstsecond",
                      "both pasted commands executed")

    def test_emacs_enter_submits_protected_multiline_paste(self):
        self.start_shell()
        self.paste_commands()
        self.send(b"\r")
        self.assert_submitted()

    def test_vi_insert_enter_submits_protected_multiline_paste(self):
        self.start_shell("vi")
        self.paste_commands()
        self.send(b"\r")
        self.assert_submitted()

    def test_vi_normal_enter_submits_and_returns_to_insert(self):
        self.start_shell("vi", after_load="ble-import keymap.vi; bleopt keymap_vi_mode_string_nmap=VI_NORMAL_READY")
        self.paste_commands()
        self.send(b"\x1b")
        self.wait_for(lambda: b"VI_NORMAL_READY" in self.output, "Vi normal mode")
        self.send(b"\r")
        self.assert_submitted()
        self.send(f"printf again >> {shlex.quote(str(self.marker))}".encode())
        self.read(0.2)
        self.send(b"\r")
        self.wait_for(lambda: self.marker.read_text() == "firstsecondagain", "Vi returns to insert mode")

    def test_switching_to_vi_after_loading_preserves_enter(self):
        self.start_shell(after_load="set -o vi")
        self.paste_commands()
        self.send(b"\r")
        self.assert_submitted()

    def test_doctor_before_attach_does_not_consume_deferred_bindings(self):
        self.start_shell(after_load='report=$(chroma doctor)')
        self.paste_commands()
        self.send(b"\r")
        self.assert_submitted()

    def test_doctor_reports_live_bindings_and_paste_settings(self):
        self.start_shell()
        report = self.base / "doctor"
        self.send(f"chroma doctor > {shlex.quote(str(report))}".encode())
        self.read(0.2)
        self.send(b"\r")
        self.wait_for(lambda: report.exists() and "discard input" in report.read_text(), "doctor output")
        text = report.read_text()
        self.assertIn("CHROMA_ENTER_ACCEPT=1", text)
        self.assertIn("bracketed paste    on", text)
        self.assertIn("accept threshold   5 (speed detection only)", text)
        self.assertIn("-f C-m 'accept-line syntax'", text)
        self.assertIn("-f RET 'accept-line syntax'", text)
        self.paste_commands()
        self.send(b"\r")
        self.assert_submitted()

    def test_emacs_opt_out_keeps_enter_newline_and_ctrl_j_accept(self):
        self.start_shell(policy="0")
        self.paste_commands()
        self.send(b"\r")
        self.assert_no_execution()
        self.send(b"\n")
        self.assert_submitted()

    def test_opt_out_preserves_custom_enter_bindings(self):
        self.start_shell(policy="0", before_load="ble-bind -m emacs -f C-m newline\nble-bind -m emacs -f RET newline")
        self.send(f"printf custom > {shlex.quote(str(self.marker))}".encode())
        self.read(0.2)
        self.send(b"\r")
        self.assert_no_execution()
        self.send(b"\n")
        self.wait_for(lambda: self.marker.exists() and self.marker.read_text() == "custom", "custom Enter binding kept")

    def test_user_paste_option_overrides_are_respected_and_diagnosed(self):
        self.start_shell(before_load="bleopt term_bracketed_paste_mode= accept_line_threshold=-1")
        report = self.base / "doctor"
        self.send(f"chroma doctor > {shlex.quote(str(report))}".encode())
        self.read(0.2)
        self.send(b"\r")
        self.wait_for(lambda: report.exists() and "discard input" in report.read_text(), "doctor output")
        self.assertIn("DISABLED (not disabled by Chroma)", report.read_text())
        self.assertIn("-1 (speed detection only)", report.read_text())

    def test_vi_opt_out_keeps_enter_newline_and_ctrl_j_accept(self):
        self.start_shell("vi", policy="0")
        self.paste_commands()
        self.send(b"\r")
        self.assert_no_execution()
        self.send(b"\n")
        self.assert_submitted()

    def test_ctrl_c_discards_paste_and_shell_remains_usable(self):
        self.start_shell()
        self.paste_commands()
        self.send(b"\x03")
        self.assert_no_execution()
        self.send(b"\r")
        self.assert_no_execution()
        self.send(f"printf recovered > {shlex.quote(str(self.marker))}".encode())
        self.read(0.2)
        self.send(b"\r")
        self.wait_for(lambda: self.marker.exists() and self.marker.read_text() == "recovered", "Ctrl+C recovery")

    def test_documented_vi_recovery_discards_the_whole_buffer(self):
        self.start_shell("vi", after_load="ble-import keymap.vi; bleopt keymap_vi_mode_string_nmap=VI_NORMAL_READY")
        self.paste_commands()
        self.send(b"\x1b")
        self.wait_for(lambda: b"VI_NORMAL_READY" in self.output, "Vi normal mode")
        self.send(b"HdGi")
        self.read(0.2)
        self.send(b"\r")
        self.assert_no_execution()
        self.send(f"printf recovered > {shlex.quote(str(self.marker))}".encode())
        self.read(0.2)
        self.send(b"\r")
        self.wait_for(lambda: self.marker.exists() and self.marker.read_text() == "recovered", "Vi recovery")

    def test_enter_preserves_unfinished_quote_continuation(self):
        self.start_shell()
        self.send(b"printf '%s' 'unfinished")
        self.read(0.2)
        self.send(b"\r")
        self.assert_no_execution()
        self.send(f"complete' > {shlex.quote(str(self.marker))}".encode())
        self.read(0.2)
        self.send(b"\r")
        self.wait_for(lambda: self.marker.exists() and self.marker.read_text() == "unfinished\ncomplete",
                      "quote continuation")


if __name__ == "__main__":
    unittest.main(verbosity=2)
