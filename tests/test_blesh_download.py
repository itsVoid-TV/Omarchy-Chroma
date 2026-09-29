"""A streaming dependency response must not exhaust installer scratch space."""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading
import time
import unittest


ROOT = Path(__file__).resolve().parent.parent
LIMIT = 8 * 1024 * 1024


class OversizedResponse(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        # Deliberately omit Content-Length: old curl cannot preflight this size.
        self.end_headers()
        chunk = b"x" * 65536
        try:
            for _ in range(512):
                self.wfile.write(chunk)
                self.wfile.flush()
                time.sleep(0.0002)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def log_message(self, *_args):
        pass


class DependencyDownloadTests(unittest.TestCase):
    def test_unbounded_response_is_stopped_before_checksum_or_activation(self):
        for ignore_curl_limit in (False, True):
            with self.subTest(older_curl=ignore_curl_limit):
                with tempfile.TemporaryDirectory(prefix="chroma download ") as directory:
                    base = Path(directory)
                    home = base / "home"
                    scratch = base / "tmp"
                    shim_dir = base / "bin"
                    home.mkdir()
                    scratch.mkdir()
                    shim_dir.mkdir()
                    bashrc = home / ".bashrc"
                    bashrc.write_text("# keep my original shell\n")

                    curl_shim = shim_dir / "curl"
                    curl_shim.write_text(
                        '#!/usr/bin/env python3\n'
                        'import os, sys\n'
                        'argv = sys.argv[1:]\n'
                        'url = next(i for i, arg in enumerate(argv) if arg.startswith('
                        '"https://github.com/akinomyoga/ble.sh/releases/download/"))\n'
                        'argv[url] = os.environ["CHROMA_TEST_URL"]\n'
                        'if os.environ.get("CHROMA_TEST_OLD_CURL") == "1":\n'
                        '    option = argv.index("--max-filesize")\n'
                        '    del argv[option:option + 2]\n'
                        'os.execv(os.environ["CHROMA_REAL_CURL"], '
                        '[os.environ["CHROMA_REAL_CURL"], *argv])\n'
                    )
                    curl_shim.chmod(0o755)
                    server = ThreadingHTTPServer(("127.0.0.1", 0), OversizedResponse)
                    thread = threading.Thread(target=server.serve_forever, daemon=True)
                    thread.start()
                    try:
                        env = dict(os.environ, HOME=str(home),
                                   XDG_DATA_HOME=str(base / "data"),
                                   XDG_CONFIG_HOME=str(base / "config"),
                                   TMPDIR=str(scratch),
                                   PATH=str(shim_dir) + os.pathsep + os.environ["PATH"],
                                   CHROMA_REAL_CURL=shutil.which("curl"),
                                   CHROMA_TEST_URL=f"http://127.0.0.1:{server.server_port}/large",
                                   CHROMA_TEST_OLD_CURL="1" if ignore_curl_limit else "0",
                                   NO_PROXY="127.0.0.1")
                        env.pop("CHROMA_INSTALL_BLESH", None)
                        env.pop("BASH_ENV", None)
                        env.pop("ENV", None)
                        result = subprocess.run(
                            ["bash", str(ROOT / "install.sh"), "--source", str(ROOT)],
                            env=env, capture_output=True, text=True, timeout=15)
                    finally:
                        server.shutdown()
                        thread.join(timeout=2)
                        server.server_close()

                    self.assertNotEqual(result.returncode, 0, result.stdout)
                    self.assertIn("8 MiB limit", result.stderr)
                    self.assertNotIn("checksum verification failed", result.stderr)
                    self.assertEqual(bashrc.read_text(), "# keep my original shell\n")
                    self.assertFalse((base / "data/omarchy-chroma").exists())
                    self.assertEqual(list(scratch.iterdir()), [])
                    self.assertEqual(list((base / "data").iterdir()), [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
