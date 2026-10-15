"""Synthetic HTTP contract checks; not a Supabase Storage service emulator."""
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from threading import Thread
import unittest
from urllib.error import HTTPError
from cleanup_photos import cleanup


class CleanupTest(unittest.TestCase):
    def fixture(self, fail_delete=False):
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
                self.respond([{"id": "synthetic-id", "path": "synthetic-owner/synthetic-id.jpg"}])

            def mutate(self):
                body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                calls.append((self.command, self.path, body))
                self.respond({}, 503 if fail_delete and self.command == "DELETE" else 200)

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


if __name__ == "__main__":
    unittest.main()
