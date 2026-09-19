"""Installer source selection must never fall back to remote Chroma code."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent


class LocalInstallTests(unittest.TestCase):
    def setUp(self):
        self.fixture = tempfile.TemporaryDirectory(prefix="chroma local '")
        self.addCleanup(self.fixture.cleanup)
        self.base = Path(self.fixture.name)
        self.bashrc = self.base / "bashrc"
        self.bashrc.write_text("# existing shell\n")
        self.network = self.base / "network-called"
        bin_dir = self.base / "bin"
        bin_dir.mkdir()
        for name in ("git", "curl", "wget"):
            command = bin_dir / name
            command.write_text('#!/bin/sh\nprintf called > "$CHROMA_NETWORK_LOG"\nexit 99\n')
            command.chmod(0o755)
        self.env = dict(os.environ, XDG_DATA_HOME=str(self.base / "data"),
                        XDG_CONFIG_HOME=str(self.base / "config"),
                        CHROMA_BASHRC=str(self.bashrc), CHROMA_INSTALL_BLESH="0",
                        CHROMA_NETWORK_LOG=str(self.network),
                        PATH=str(bin_dir) + os.pathsep + os.environ["PATH"])
        self.env.pop("BASH_ENV", None)
        self.env.pop("ENV", None)

    def run_installer(self, *args, cwd=None):
        return subprocess.run(["bash", *map(str, args)], cwd=cwd or self.base,
                              env=self.env, capture_output=True, text=True, timeout=20)

    def assert_refused(self, result):
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertFalse(self.network.exists(), "An installer attempted a network fetch")
        self.assertEqual(self.bashrc.read_text(), "# existing shell\n")
        self.assertFalse((self.base / "data").exists())

    def test_local_script_resolves_its_own_source_from_another_directory(self):
        result = self.run_installer(ROOT / "install.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.network.exists())
        self.assertEqual((self.base / "data/omarchy-chroma/chromarchy.bash").read_bytes(),
                         (ROOT / "chromarchy.bash").read_bytes())

    def test_detached_script_fails_without_fetch_or_mutation(self):
        detached = self.base / "install.sh"
        shutil.copyfile(ROOT / "install.sh", detached)
        self.assert_refused(self.run_installer(detached))

    def test_inline_script_requires_an_explicit_source_even_inside_checkout(self):
        result = self.run_installer("-c", (ROOT / "install.sh").read_text(), cwd=ROOT)
        self.assertIn("--source DIR", result.stderr)
        self.assert_refused(result)

    def test_explicit_missing_source_never_fetches(self):
        self.assert_refused(self.run_installer(ROOT / "install.sh", "--source", self.base / "missing"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
