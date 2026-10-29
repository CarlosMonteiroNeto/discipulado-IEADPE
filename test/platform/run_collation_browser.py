"""Compile the production locale adapter and check it in a loopback browser."""
import functools
import http.server
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading

root = Path(__file__).resolve().parents[2]
output = root / "build" / "task10-collation"
output.mkdir(parents=True, exist_ok=True)
subprocess.run([shutil.which("dart"), "compile", "js", "-O1", "-o", str(output / "main.js"),
                "test/platform/portuguese_collation_browser_smoke.dart"], cwd=root, check=True, timeout=120)
(output / "index.html").write_text('<!doctype html><html><body>RUNNING<script src="main.js"></script></body></html>', encoding="utf-8")

class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *_):
        pass

server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(QuietHandler, directory=str(output)))
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
chrome = os.environ.get("CHROME_EXECUTABLE", r"C:\Program Files\Google\Chrome\Application\chrome.exe")
try:
    with tempfile.TemporaryDirectory(prefix="ieadpe-locale-", ignore_cleanup_errors=True) as profile:
        run = subprocess.run([chrome, "--headless", "--disable-gpu", "--no-first-run", "--no-default-browser-check",
                              "--user-data-dir=" + profile, "--virtual-time-budget=10000", "--dump-dom",
                              f"http://127.0.0.1:{server.server_address[1]}/index.html"],
                             capture_output=True, text=True, encoding="utf-8", timeout=90)
        (output / "browser-stderr.log").write_text(run.stderr, encoding="utf-8")
        (output / "browser-dom.html").write_text(run.stdout, encoding="utf-8")
        if run.returncode or "<body>PASS: production browser pt-BR collation" not in run.stdout:
            raise AssertionError("Browser locale check failed; inspect build/task10-collation artifacts")
        print("PASS: actual Chrome runs production pt-BR adapter, Matriz priority and canonical-equivalence fixtures")
finally:
    server.shutdown()
    server.server_close()
    thread.join(timeout=5)
