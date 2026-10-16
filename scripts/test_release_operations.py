"""Local artifact and rewrite fixtures, not hosted Pages or Google QA."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from tempfile import TemporaryDirectory
from threading import Thread
from urllib.request import urlopen
import unittest
from web_preflight import inspect


class ReleaseTest(unittest.TestCase):
    def test_exact_limit_is_accepted(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'index.html').write_text('synthetic shell')
            (root / '_redirects').write_text('/* /index.html 200\n')
            with (root / 'limit.wasm').open('wb') as file:
                file.truncate(25 * 1024 * 1024)
            self.assertEqual(inspect(root), [])

    def test_oversized_actual_file_reports_path_and_bytes(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'index.html').write_text('synthetic shell')
            (root / '_redirects').write_text('/* /index.html 200\n')
            with (root / 'large.wasm').open('wb') as file:
                file.truncate(25 * 1024 * 1024 + 1)
            issues = '\n'.join(inspect(root))
            self.assertIn('large.wasm', issues)
            self.assertIn('26214401', issues)

    def test_missing_artifact_fails_closed(self):
        with TemporaryDirectory() as directory:
            self.assertTrue(inspect(Path(directory)))

    def test_deep_link_refresh_local_rewrite_fixture(self):
        config = Path('web/_redirects')
        rules = config.read_text().splitlines() if config.exists() else []
        self.assertIn('/* /index.html 200', rules)
        with TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'index.html').write_text('synthetic Flutter shell')
            (root / 'asset.js').write_text('synthetic asset')
            class Rewrite(SimpleHTTPRequestHandler):
                def log_message(self, *_):
                    pass

                def do_GET(self):
                    # Interpret the tested catch-all only for non-file paths.
                    if not Path(self.translate_path(self.path)).is_file():
                        self.path = rules[rules.index('/* /index.html 200')].split()[1]
                    super().do_GET()
            server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Rewrite, directory=directory))
            Thread(target=server.serve_forever, daemon=True).start()
            try:
                for route in ('/register', '/admin', '/auth/callback?code=synthetic'):
                    with urlopen(f'http://127.0.0.1:{server.server_port}{route}') as response:
                        self.assertEqual(response.status, 200)
                        self.assertEqual(response.read(), b'synthetic Flutter shell')
                with urlopen(f'http://127.0.0.1:{server.server_port}/asset.js') as response:
                    self.assertEqual(response.read(), b'synthetic asset')
            finally:
                server.shutdown()
                server.server_close()
