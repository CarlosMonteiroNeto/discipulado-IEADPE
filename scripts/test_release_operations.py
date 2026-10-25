"""Local artifact and rewrite fixtures, not hosted Pages or Google QA."""
from functools import partial
from fnmatch import fnmatchcase
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from tempfile import TemporaryDirectory
from threading import Thread
from urllib.request import urlopen
from urllib.parse import urlsplit
import unittest
from web_preflight import inspect


class ReleaseTest(unittest.TestCase):
    def test_preflight_rejects_proxy_that_shadows_assets(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'index.html').write_text('synthetic shell')
            (root / '_redirects').write_text('/* /index.html 200\n')
            self.assertTrue(inspect(root))

    def test_exact_limit_is_accepted(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'index.html').write_text('synthetic shell')
            (root / '_redirects').write_text(Path('web/_redirects').read_text())
            with (root / 'limit.wasm').open('wb') as file:
                file.truncate(25 * 1024 * 1024)
            self.assertEqual(inspect(root), [])

    def test_oversized_actual_file_reports_path_and_bytes(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'index.html').write_text('synthetic shell')
            (root / '_redirects').write_text(Path('web/_redirects').read_text())
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
        with TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'index.html').write_text('synthetic Flutter shell')
            (root / 'asset.js').write_text('synthetic asset')
            (root / 'renderer.wasm').write_bytes(b'\x00asm\x01\x00\x00\x00')
            (root / 'logo.png').write_bytes(b'\x89PNG\r\n\x1a\n')
            class Rewrite(SimpleHTTPRequestHandler):
                def log_message(self, *_):
                    pass

                def do_GET(self):
                    # Pages applies the first matching proxy even to existing assets.
                    for rule in rules:
                        source, destination, status = rule.split()
                        if fnmatchcase(urlsplit(self.path).path, source):
                            assert status == '200'
                            self.path = destination
                            break
                    super().do_GET()
            server = ThreadingHTTPServer(('127.0.0.1', 0), partial(Rewrite, directory=directory))
            Thread(target=server.serve_forever, daemon=True).start()
            try:
                for route in (
                    '/login', '/register', '/home', '/converts', '/admin',
                    '/auth/callback?code=synthetic&next=%2Fregister',
                    '/ministry', '/ministry/team', '/ministry/students',
                    '/ministry/students/register', '/ministry/classes',
                    '/ministry/attendance', '/ministry/handoff',
                ):
                    with urlopen(f'http://127.0.0.1:{server.server_port}{route}') as response:
                        self.assertEqual(response.status, 200)
                        self.assertEqual(response.read(), b'synthetic Flutter shell')
                for asset, expected, mime in (
                    ('asset.js', b'synthetic asset', 'javascript'),
                    ('renderer.wasm', b'\x00asm\x01\x00\x00\x00', 'application/wasm'),
                    ('logo.png', b'\x89PNG\r\n\x1a\n', 'image/png'),
                ):
                    with self.subTest(asset=asset):
                        with urlopen(f'http://127.0.0.1:{server.server_port}/{asset}') as response:
                            self.assertEqual(response.read(), expected)
                            self.assertIn(mime, response.headers['Content-Type'])
            finally:
                server.shutdown()
                server.server_close()
