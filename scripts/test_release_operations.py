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
    def test_callback_proxy_avoids_index_html_canonical_redirect(self):
        rules = [line.split() for line in Path('web/_redirects').read_text().splitlines()
                 if line.strip() and not line.startswith('#')]
        callback = next(rule for rule in rules if rule[0] == '/auth/callback')
        self.assertEqual(callback, ['/auth/callback', '/', '200'])
        with TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'index.html').write_text('synthetic shell')
            (root / '_redirects').write_text(Path('web/_redirects').read_text())
            self.assertEqual(inspect(root), [])
            (root / '_redirects').write_text(
                Path('web/_redirects').read_text().replace(' / 200', ' /index.html 200'))
            self.assertTrue(inspect(root))

    def test_public_intake_runbook_pins_config_and_release_boundaries(self):
        runbook_path = Path('docs/operations/public-intake.md')
        runbook = runbook_path.read_text() if runbook_path.exists() else ''
        for public_define in (
            'SUPABASE_URL', 'SUPABASE_PUBLISHABLE_KEY',
            'AUTH_CALLBACK_URL', 'TURNSTILE_SITE_KEY',
        ):
            with self.subTest(public_define=public_define):
                self.assertIn(public_define, runbook)
        for server_value in (
            'SUPABASE_SERVICE_ROLE_KEY', 'TURNSTILE_SECRET_KEY',
            'INTAKE_NETWORK_HASH_SECRET', 'INTAKE_ALLOWED_ORIGINS',
            'INTAKE_ALLOWED_HOSTNAMES',
        ):
            with self.subTest(server_value=server_value):
                self.assertIn(server_value, runbook)
        self.assertIn('verify_jwt = false', runbook)
        self.assertIn('private.public_intake_cleanup()', runbook)
        self.assertIn('BLOCKED', runbook)
        self.assertIn('https://discipulado-ieadpe.pages.dev', runbook)
        self.assertIn('public-intake-release-candidate-20261026.json', runbook)
        self.assertIn('https://discipulado-ieadpe.pages.dev', runbook)

    def test_public_intake_runbook_names_current_hosted_release_blockers(self):
        runbook_path = Path('docs/operations/public-intake.md')
        runbook = runbook_path.read_text() if runbook_path.exists() else ''
        for evidence in (
            '202610250002', '202610250003', '202610250004',
            'client-address', 'Turnstile', 'fresh post-acceptance full database archive',
            'TLS Session Pooler', 'mobile',
        ):
            with self.subTest(evidence=evidence):
                self.assertIn(evidence, runbook)

    def test_public_intake_retention_is_fixed_and_limits_are_configurable(self):
        runbook = Path('docs/operations/public-intake.md').read_text()
        self.assertIn('pending drafts expire after exactly 30 days', runbook)
        self.assertIn('decision metadata is retained for exactly 90 days', runbook)
        self.assertIn('only abuse and capacity limits are operator-configurable', runbook)

    def test_ministry_contract_marks_no_grant_creation_as_superseded(self):
        contract = Path('docs/integration/ministry-contracts.md').read_text(encoding='utf-8')
        self.assertIn('without a matching campaign grant, registration follows public pending intake', contract)
        self.assertIn('superseded by the public-intake authority migration', contract)

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
                    '/login', '/register', '/home', '/converts', '/pending', '/team', '/admin',
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


if __name__ == '__main__':
    unittest.main()
