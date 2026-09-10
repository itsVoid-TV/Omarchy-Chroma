"""Offline bridge/lifecycle tests. All writes use disposable XDG fixtures."""
import fcntl
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent
HELPER = ROOT / "scripts/chroma-control"
loader = importlib.machinery.SourceFileLoader("chroma_control", str(HELPER))
spec = importlib.util.spec_from_loader(loader.name, loader)
bridge = importlib.util.module_from_spec(spec)
loader.exec_module(bridge)


class PluginTests(unittest.TestCase):
    def setUp(self):
        self.fixture = tempfile.TemporaryDirectory(prefix="chroma-test spaces '")
        self.addCleanup(self.fixture.cleanup)
        self.base = Path(self.fixture.name)
        self.env = os.environ.copy()
        self.env.update({"XDG_DATA_HOME": str(self.base / "data"),
                         "XDG_CONFIG_HOME": str(self.base / "config"),
                         "XDG_STATE_HOME": str(self.base / "state"),
                         "XDG_CACHE_HOME": str(self.base / "cache"),
                         "CHROMA_BASHRC": str(self.base / "bashrc"),
                         "CHROMA_INSTALL_BLESH": "0",
                         "CHROMA_THEME_FILE": str(ROOT / "tests/fixtures/vantablack/colors.toml")})
        self.bashrc = self.base / "bashrc"
        self.bashrc.write_text("# unrelated user setup\n", encoding="utf-8")
        self.ble = self.base / "data/blesh/ble.sh"
        self.ble.parent.mkdir(parents=True)
        self.ble.write_text("# Presence fixture, not a real ble.sh engine.\n", encoding="utf-8")
        self.settings = self.base / "config/omarchy-chroma"
        self.install = self.base / "data/omarchy-chroma"

    def call(self, *args, ok=True):
        completed = subprocess.run(["python3", str(HELPER), *args], env=self.env,
                                   capture_output=True, text=True, timeout=30)
        self.assertEqual(completed.stderr, "")
        result = json.loads(completed.stdout)
        self.assertEqual(result["ok"], ok, result)
        self.assertEqual(completed.returncode, 0 if ok else 1, result)
        return result

    def files(self):
        return {str(p.relative_to(self.base)): p.read_bytes()
                for p in self.base.rglob("*") if p.is_file()}

    def test_manifest(self):
        manifest = json.loads((ROOT / "manifest.json").read_text())
        self.assertEqual(manifest["schemaVersion"], 1)
        self.assertEqual(manifest["id"], bridge.PLUGIN_ID)
        self.assertEqual(manifest["kinds"], ["bar-widget"])
        for path in manifest["entryPoints"].values():
            self.assertNotIn("..", path)
            self.assertTrue((ROOT / path).is_file())
        self.assertIn("CHROMA_VERSION=" + manifest["version"], (ROOT / "chromarchy.bash").read_text())

    def test_read_only_actions(self):
        before = self.files()
        self.call("status")
        self.call("inspect")
        self.call("legend")
        self.assertEqual(before, self.files())
        self.assertFalse(self.settings.exists())

    @unittest.skipUnless(os.environ.get("CHROMA_BLESH_PATH"), "pinned ble.sh not available")
    def test_doctor_with_real_engine(self):
        source = Path(os.environ["CHROMA_BLESH_PATH"]).resolve()
        self.assertTrue(source.is_file())
        shutil.copytree(source.parent, self.ble.parent, dirs_exist_ok=True)
        (self.base / "cache").mkdir()
        self.call("setup", "--confirm")
        result = self.call("doctor")
        self.assertEqual(result["message"], "Diagnostic passed.")
        self.assertIn("semantic layer     ready", result["output"])
        self.assertNotIn("CHROMA_DOCTOR_RESULT", result["output"])
        self.assertTrue(result["data"]["enabled"])

    def test_terminal_escape_cleanup(self):
        self.assertEqual(bridge.clean("\x1b]0;title\x07\x1b7\x1b(B\x1b[31mready\x1b[0m\x1b8"), "ready")

    def test_every_mutation_requires_confirmation(self):
        before = self.files()
        for action in ("setup", "enable", "disable", "reload", "uninstall"):
            self.call(action, ok=False)
        self.assertEqual(before, self.files())

    def test_setup_backup_and_idempotent_update(self):
        original = self.bashrc.read_bytes()
        result = self.call("setup", "--confirm")
        self.assertTrue(result["data"]["enabled"])
        self.assertFalse(result["data"]["updateAvailable"])
        backups = list((self.base / "state/omarchy-chroma/backups").glob("*.bak"))
        self.assertEqual(backups[0].read_bytes(), original)
        self.assertIn(str(backups[0]), result["output"])
        custom = self.settings / "config.bash"
        custom.write_text("CHROMA_MIN_CONTRAST=6\n", encoding="utf-8")
        self.call("setup", "--confirm")
        self.assertEqual(custom.read_text(), "CHROMA_MIN_CONTRAST=6\n")
        self.assertEqual(self.bashrc.read_text().count(bridge.START), 1)

    def test_disable_enable_and_silent_loader(self):
        self.call("setup", "--confirm")
        disabled = self.call("disable", "--confirm")
        self.assertEqual(disabled["data"]["state"], "disabled")
        result = subprocess.run(["bash", "--noprofile", "--norc", "-ic",
                                 'source "$XDG_DATA_HOME/omarchy-chroma/chromarchy.bash"; '
                                 'if declare -F chroma >/dev/null; then exit 1; fi; printf plain'],
                                env=self.env, capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "plain")
        self.call("setup", "--confirm")
        self.assertTrue((self.settings / "disabled").exists())
        enabled = self.call("enable", "--confirm")
        self.assertTrue(enabled["data"]["enabled"])

    def test_uninstall_preserves_config_and_dependency(self):
        self.call("setup", "--confirm")
        result = self.call("uninstall", "--confirm")
        self.assertFalse(result["data"]["installed"])
        self.assertEqual(self.bashrc.read_text(), "# unrelated user setup\n\n")
        self.assertTrue((self.settings / "config.bash").exists())
        self.assertTrue(self.ble.exists())

    def test_symlinked_bashrc_is_preserved(self):
        target = self.base / "real bashrc"
        self.bashrc.rename(target)
        self.bashrc.symlink_to(target)
        self.call("setup", "--confirm")
        self.assertTrue(self.bashrc.is_symlink())
        self.call("uninstall", "--confirm")
        self.assertTrue(self.bashrc.is_symlink())
        self.assertIn("unrelated", target.read_text())

    def test_malformed_loader_is_not_overwritten(self):
        self.bashrc.write_text(bridge.START + "\n# keep me\n", encoding="utf-8")
        before = self.bashrc.read_bytes()
        self.call("setup", "--confirm", ok=False)
        self.assertEqual(self.bashrc.read_bytes(), before)
        self.assertFalse(self.install.exists())

    def test_no_user_startup_execution(self):
        marker = self.base / "SHOULD_NOT_EXIST"
        hook = self.base / "startup-hook"
        hook.write_text('touch "' + str(marker) + '"\n', encoding="utf-8")
        self.env["BASH_ENV"] = str(hook)
        self.bashrc.write_text(hook.read_text(), encoding="utf-8")
        self.call("inspect")
        self.call("setup", "--confirm")
        self.assertFalse(marker.exists())

    def test_palette_dark_light_custom_and_missing(self):
        self.call("setup", "--confirm")
        for theme in ("vantablack", "white"):
            self.env["CHROMA_THEME_FILE"] = str(ROOT / f"tests/fixtures/{theme}/colors.toml")
            result = self.call("legend")["data"]
            self.assertGreaterEqual(float(result["palette"]["worst"]), 5.5)
            self.assertEqual(len(result["legend"]), 13)
        (self.settings / "config.bash").write_text("CHROMA_STYLES[danger]='fg=#888888,bold'\n", encoding="utf-8")
        result = self.call("inspect")["data"]
        danger = next(row for row in result["legend"] if row["category"] == "danger")
        self.assertEqual(danger["color"], "#888888")
        self.assertEqual(danger["ratio"], "unknown")
        self.env["CHROMA_THEME_FILE"] = str(self.base / "missing-palette")
        self.assertIn("no readable", self.call("inspect")["data"]["paletteError"])

    def test_config_output_and_errors_do_not_break_json(self):
        self.call("setup", "--confirm")
        config = self.settings / "config.bash"
        config.write_text("printf 'noise\\n'\nCHROMA_MIN_CONTRAST=invalid\n", encoding="utf-8")
        self.assertIn("not numeric", self.call("inspect")["data"]["palette"]["warnings"])
        config.write_text("return 1\n", encoding="utf-8")
        self.assertIn("failed", self.call("inspect")["data"]["paletteError"])

    def test_update_is_detected(self):
        self.call("setup", "--confirm")
        path = self.install / "lib/layer.bash"
        path.write_text(path.read_text() + "\n# older code\n", encoding="utf-8")
        self.assertTrue(self.call("status")["data"]["updateAvailable"])

    def test_reload_does_not_touch_bashrc(self):
        self.call("setup", "--confirm")
        original = self.bashrc.read_bytes()
        self.call("reload", "--confirm")
        token = self.base / "state/omarchy-chroma/reload"
        self.assertTrue(token.read_text().strip().isdigit())
        self.assertEqual(self.bashrc.read_bytes(), original)
        self.env["CHROMA_TEST_ROOT"] = str(ROOT)
        result = subprocess.run(["bash", "--noprofile", "--norc", "-c",
                                 'source "$CHROMA_TEST_ROOT/config/defaults.bash"; '
                                 'source "$CHROMA_TEST_ROOT/lib/theme.bash"; '
                                 'chromarchy::theme_apply; chromarchy::theme_refresh; '
                                 'printf "%s" "$CHROMA_RELOAD_TOKEN"'],
                                env=self.env, capture_output=True, text=True, timeout=5)
        self.assertEqual(result.stdout, token.read_text().strip())

    def test_concurrent_mutation_is_rejected(self):
        directory = self.base / "state/omarchy-chroma"
        directory.mkdir(parents=True)
        with (directory / "control.lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            result = self.call("setup", "--confirm", ok=False)
            self.assertIn("Another Chroma action", result["message"])
        self.assertFalse(self.install.exists())

    def test_doctor_reports_missing_or_broken_engine(self):
        self.call("doctor", ok=False)
        self.call("setup", "--confirm")
        result = self.call("doctor", ok=False)
        self.assertIn("Diagnostic found", result["message"])

    def test_fifo_config_and_symlink_state_are_refused(self):
        self.settings.mkdir(parents=True)
        os.mkfifo(self.settings / "config.bash")
        self.assertIn("regular file", self.call("inspect")["data"]["paletteError"])
        directory = self.base / "state"
        directory.mkdir()
        (directory / "omarchy-chroma").symlink_to(self.base)
        self.call("setup", "--confirm", ok=False)
        self.assertFalse(self.install.exists())

    def test_timeout_stops_helpers(self):
        with self.assertRaisesRegex(RuntimeError, "timed out"):
            bridge.run(["sleep", "3"], timeout=0.02)


if __name__ == "__main__":
    unittest.main(verbosity=2)
