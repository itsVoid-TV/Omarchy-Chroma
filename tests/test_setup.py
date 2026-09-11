"""Development ZIP bootstrap tests with an isolated Omarchy host double."""
import contextlib
import importlib.machinery
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent
loader = importlib.machinery.SourceFileLoader("chroma_setup", str(ROOT / "setup"))
spec = importlib.util.spec_from_loader(loader.name, loader)
setup = importlib.util.module_from_spec(spec)
loader.exec_module(setup)


class SetupTests(unittest.TestCase):
    def setUp(self):
        self.fixture = tempfile.TemporaryDirectory(prefix="chroma-setup spaces '")
        self.addCleanup(self.fixture.cleanup)
        self.base = Path(self.fixture.name)
        self.seed = self.base / "remote"
        self.seed.mkdir()
        self.plugins = self.base / "plugins"
        self.target = self.plugins / setup.PLUGIN_ID
        self.bashrc = self.base / "bashrc"
        self.bashrc.write_text("# keep existing Bash setup\n")
        self.git("init", "-q", "-b", setup.BRANCH)
        (self.seed / "manifest.json").write_text((ROOT / "manifest.json").read_text())
        self.commit("fixture")
        self.calls = []
        self.catalog = []
        self.failure = None
        self.race = False
        self.original_run = setup.run
        self.run_patch = patch.object(setup, "run", side_effect=self.host)
        self.run_patch.start()
        self.addCleanup(self.run_patch.stop)
        self.which_patch = patch.object(setup.shutil, "which", side_effect=lambda name: "/usr/bin/" + name)
        self.which_patch.start()
        self.addCleanup(self.which_patch.stop)

    def git(self, *args, directory=None):
        return subprocess.run(["git", "-c", "user.name=Chroma Test", "-c",
                               "user.email=test@example.invalid", *args],
                              cwd=directory or self.seed, check=True,
                              capture_output=True, text=True).stdout.strip()

    def commit(self, message):
        self.git("add", ".")
        self.git("commit", "-qm", message)

    def host(self, argv, **kwargs):
        self.calls.append(list(argv))
        if argv[0] == self.failure:
            raise subprocess.CalledProcessError(1, argv)
        if argv[0] == "git":
            self.assertEqual(argv[-2], setup.REPOSITORY)
            return self.original_run([*argv[:-2], str(self.seed), argv[-1]], **kwargs)
        if argv[0] == "mv":
            if self.race:
                self.target.mkdir()
                (self.target / "keep").write_text("another install")
            return self.original_run(argv, **kwargs)
        payload = ""
        if argv[0] == "omarchy-plugin-catalog":
            payload = json.dumps(self.catalog)
        elif argv[0] == "omarchy-plugin-list":
            payload = json.dumps([{"id": setup.PLUGIN_ID}])
        return subprocess.CompletedProcess(argv, 0, stdout=payload, stderr="")

    def install(self, yes=True):
        with contextlib.redirect_stdout(io.StringIO()):
            setup.install(self.plugins, assume_yes=yes)

    def test_setup_creates_an_independent_updatable_checkout(self):
        self.install()
        self.assertTrue((self.target / ".git").is_dir())
        self.assertEqual(self.git("branch", "--show-current", directory=self.target), setup.BRANCH)
        self.assertEqual(self.git("rev-parse", "--abbrev-ref", "@{upstream}", directory=self.target),
                         "origin/" + setup.BRANCH)
        (self.seed / "update.txt").write_text("new version")
        self.commit("new version")
        self.git("pull", "--ff-only", directory=self.target)
        self.assertEqual((self.target / "update.txt").read_text(), "new version")
        self.assertEqual(self.bashrc.read_text(), "# keep existing Bash setup\n")
        self.assertIn(["omarchy-plugin-enable", setup.PLUGIN_ID], self.calls)
        validator = next(i for i, call in enumerate(self.calls) if call[0] == "omarchy-plugin-validate")
        enable = next(i for i, call in enumerate(self.calls) if call[0] == "omarchy-plugin-enable")
        self.assertLess(validator, enable)

    def test_cancel_and_noninteractive_use_do_not_download(self):
        with patch.object(setup.sys.stdin, "isatty", return_value=True), patch("builtins.input", return_value="n"):
            self.install(yes=False)
        self.assertFalse(self.plugins.exists())
        self.assertFalse(any(call[0] == "git" for call in self.calls))
        with patch.object(setup.sys.stdin, "isatty", return_value=False):
            with self.assertRaisesRegex(RuntimeError, "confirm"):
                self.install(yes=False)
        self.assertFalse(self.plugins.exists())

    def test_missing_omarchy_fails_before_writes(self):
        with patch.object(setup.shutil, "which", return_value=None):
            with self.assertRaisesRegex(RuntimeError, "Omarchy Quattro"):
                self.install()
        self.assertFalse(self.plugins.exists())
        self.assertEqual(self.calls, [])

    def test_existing_checkout_symlink_and_catalog_collision_are_preserved(self):
        self.install()
        before = self.git("rev-parse", "HEAD", directory=self.target)
        self.calls.clear()
        with self.assertRaisesRegex(RuntimeError, "already has a checkout"):
            self.install()
        self.assertEqual(self.git("rev-parse", "HEAD", directory=self.target), before)
        self.assertFalse(any(call[0] == "git" for call in self.calls))
        moved = self.base / "existing"
        self.target.rename(moved)
        self.target.symlink_to(moved, target_is_directory=True)
        with self.assertRaisesRegex(RuntimeError, "already has a checkout"):
            self.install()
        self.assertTrue(self.target.is_symlink())
        self.target.unlink()
        moved.rename(self.target)
        self.target.rename(self.base / "saved")
        self.catalog = [{"id": setup.PLUGIN_ID, "manifestPath": "/other/manifest.json"}]
        with self.assertRaisesRegex(RuntimeError, "already in use"):
            self.install()

    def test_clone_validation_and_manifest_failures_never_enable(self):
        for command in ("git", "omarchy-plugin-validate"):
            self.failure = command
            with self.assertRaises(subprocess.CalledProcessError):
                self.install()
            self.assertFalse(self.target.exists())
        self.failure = None
        (self.seed / "manifest.json").write_text(json.dumps({"id": "org.example.unexpected"}))
        self.commit("wrong id")
        with self.assertRaisesRegex(RuntimeError, "unexpected ID"):
            self.install()
        self.assertFalse(self.target.exists())
        self.assertFalse(any(call[0] == "omarchy-plugin-enable" for call in self.calls))

    def test_competing_install_is_not_overwritten_or_nested(self):
        self.race = True
        with self.assertRaisesRegex(RuntimeError, "destination appeared"):
            self.install()
        self.assertEqual((self.target / "keep").read_text(), "another install")
        self.assertEqual(list(self.target.iterdir()), [self.target / "keep"])
        self.assertFalse(any(call[0] == "omarchy-plugin-enable" for call in self.calls))

    def test_activation_failure_keeps_checkout_and_gives_recovery(self):
        self.failure = "omarchy-shell"
        with self.assertRaisesRegex(RuntimeError, "checkout was kept"):
            self.install()
        self.assertTrue((self.target / ".git").is_dir())
        self.assertEqual(self.bashrc.read_text(), "# keep existing Bash setup\n")

    def test_yes_never_hands_off_to_bash_even_in_an_interactive_terminal(self):
        terminal = SimpleNamespace(interactive=True, animate=lambda: None)
        with patch.object(setup.sys, "argv", ["setup", "--yes"]), \
                patch.object(setup, "Terminal", return_value=terminal), \
                patch.object(setup, "install", return_value=self.target), \
                patch.object(setup.os, "execv") as handoff:
            self.assertEqual(setup.main(), 0)
            handoff.assert_not_called()

    def test_interactive_handoff_keeps_terminal_and_never_passes_yes(self):
        class Handoff(Exception):
            pass
        terminal = SimpleNamespace(interactive=True, animate=lambda: None)
        with patch.object(setup.sys, "argv", ["setup"]), \
                patch.object(setup, "Terminal", return_value=terminal), \
                patch.object(setup, "install", return_value=self.target), \
                patch.object(setup.os, "execv", side_effect=Handoff) as handoff:
            with self.assertRaises(Handoff):
                setup.main()
            self.assertEqual(handoff.call_args.args[1], [setup.sys.executable,
                             str(self.target / "scripts/chroma-installer"), "--no-animation"])

    def test_preview_bypasses_plugin_bootstrap(self):
        class Handoff(Exception):
            pass
        with patch.object(setup.sys, "argv", ["setup", "--preview", "--no-animation"]), \
                patch.object(setup, "install") as bootstrap, \
                patch.object(setup.os, "execv", side_effect=Handoff) as handoff:
            with self.assertRaises(Handoff):
                setup.main()
            bootstrap.assert_not_called()
            self.assertEqual(handoff.call_args.args[1], [setup.sys.executable,
                             str(ROOT / "scripts/chroma-installer"), "--no-animation", "--preview"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
