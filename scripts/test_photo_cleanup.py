"""Synthetic HTTP contract checks; not a Supabase Storage service emulator."""
import json
import os
import shutil
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from threading import Thread
import unittest
from unittest.mock import patch
from urllib.error import HTTPError
from cleanup_photos import cleanup


def powershell():
    """Release docs prescribe pwsh; accept Windows PowerShell where Core is absent."""
    host = shutil.which("pwsh") or shutil.which("powershell")
    if host is None:
        raise unittest.SkipTest("no PowerShell host available")
    return host


class CleanupTest(unittest.TestCase):
    def test_empty_key_fails_before_request(self):
        with patch('urllib.request.urlopen') as request:
            request.return_value.__enter__.return_value.read.return_value = b'[]'
            with self.assertRaises(ValueError):
                cleanup('https://synthetic.supabase.co', '')
            request.assert_not_called()

    def test_dry_run_reports_ids_without_paths(self):
        url, calls = self.fixture()
        with patch('builtins.print') as output:
            self.assertEqual(cleanup(url, 'synthetic-key'), (1, 0))
        self.assertIn('synthetic-id', str(output.call_args_list))
        self.assertNotIn('synthetic-owner', str(output.call_args_list))

    def fixture(self, fail_delete=False, partial=False):
        calls = []
        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def respond(self, value, status=200):
                self.send_response(status)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps(value).encode())

            def do_GET(self):
                calls.append(("GET", self.path, None))
                # Model server eligibility: attached rows are never selected.
                from urllib.parse import parse_qs, urlsplit
                filters = parse_qs(urlsplit(self.path).query)
                if filters.get('or', [''])[0].startswith('(status.eq.detached,and(status.eq.pending,expires_at.lte.'):
                    rows = [{"id": "synthetic-id", "path": "synthetic-owner/synthetic-id.jpg"}]
                    if partial:
                        rows.append({"id": "second-id", "path": "synthetic-owner/second-id.jpg"})
                    self.respond(rows)
                else:
                    self.respond([{"id": "attached-id", "path": "attached.jpg"}])

            def mutate(self):
                body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                calls.append((self.command, self.path, body))
                failed = fail_delete and self.command == "DELETE"
                failed = failed or (partial and self.command == "DELETE" and 'second-id' in str(body))
                self.respond({}, 503 if failed else 200)

            do_DELETE = mutate
            do_POST = mutate

        server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = Thread(target=server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        return f"http://127.0.0.1:{server.server_port}", calls

    def test_dry_run_does_not_delete(self):
        url, calls = self.fixture()
        self.assertEqual(cleanup(url, "synthetic-key"), (1, 0))
        self.assertEqual([c[0] for c in calls], ["GET"])
        self.assertIn("status.eq.detached", calls[0][1])
        self.assertIn("limit=100", calls[0][1])

    def test_storage_removal_precedes_metadata(self):
        url, calls = self.fixture()
        self.assertEqual(cleanup(url, "synthetic-key", True), (1, 1))
        self.assertEqual(calls[1:], [
            ("DELETE", "/storage/v1/object/convert-photos", {"prefixes": ["synthetic-owner/synthetic-id.jpg"]}),
            ("POST", "/rest/v1/rpc/ieadpe_purge_photo_asset", {"asset_id": "synthetic-id"}),
        ])

    def test_storage_failure_preserves_metadata(self):
        url, calls = self.fixture(fail_delete=True)
        with self.assertRaises(HTTPError):
            cleanup(url, "synthetic-key", True)
        self.assertEqual([c[0] for c in calls], ["GET", "DELETE"])

    def test_partial_failure_keeps_failed_asset_metadata_and_skips_attached(self):
        url, calls = self.fixture(partial=True)
        with self.assertRaises(HTTPError):
            cleanup(url, 'synthetic-key', True)
        self.assertEqual([c[0] for c in calls], ['GET', 'DELETE', 'POST', 'DELETE'])
        self.assertEqual(calls[2][2], {'asset_id': 'synthetic-id'})
        self.assertNotIn('attached-id', str(calls))

    def test_powershell_wrapper_propagates_failure_without_metadata_delete(self):
        url, calls = self.fixture(fail_delete=True)
        result = subprocess.run(
            [powershell(), '-NoProfile', '-File', 'scripts/maintenance_photos.ps1', '-Apply'],
            env={**os.environ, 'SUPABASE_URL': url, 'SUPABASE_SERVICE_ROLE_KEY': 'synthetic-key'},
            capture_output=True, text=True, timeout=30,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual([c[0] for c in calls], ['GET', 'DELETE'])
        self.assertNotIn('synthetic-key', result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
