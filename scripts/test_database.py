"""Run real SQL in an owned, disposable loopback PostgreSQL database."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
from urllib.parse import urlparse, urlunparse
import uuid

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("scenario", nargs="?", default="access_test.sql")
    args = parser.parse_args()
    scenario = (ROOT / "supabase/tests/database" / args.scenario).resolve()
    if scenario.parent != (ROOT / "supabase/tests/database").resolve():
        raise ValueError("Scenario must belong to database tests")
    uri = urlparse(os.environ.get("IEADPE_DATABASE_URL", "postgresql://postgres@127.0.0.1:54329/postgres"))
    if uri.scheme not in ("postgres", "postgresql") or uri.hostname not in ("127.0.0.1", "localhost", "::1") or uri.query:
        raise ValueError("Only loopback PostgreSQL is permitted")
    binary = os.environ.get("IEADPE_PG_BIN")
    fallback = Path.home() / ".codex/tools/ieadpe-postgresql/pgsql/bin"
    executable = "psql.exe" if os.name == "nt" else "psql"
    psql = str(Path(binary) / executable) if binary else shutil.which("psql")
    if not psql:
        psql = str(fallback / executable)
    database = "ieadpe_test_" + uuid.uuid4().hex
    admin = urlunparse(uri)
    target = urlunparse(uri._replace(path="/" + database))

    def run(connection, *arguments):
        subprocess.run([psql, "-X", "--no-password", "-v", "ON_ERROR_STOP=1", "-d", connection, *arguments], check=True, timeout=90)

    run(admin, "-c", f'CREATE DATABASE "{database}"')
    try:
        run(target, "-f", str(ROOT / "supabase/tests/fixtures/local_auth_storage.sql"))
        for migration in sorted((ROOT / "supabase/migrations").glob("*.sql")):
            run(target, "-f", str(migration))
        run(target, "-f", str(scenario))
        print("PASS: " + args.scenario, flush=True)
    finally:
        run(admin, "-c", f'DROP DATABASE "{database}" WITH (FORCE)')


if __name__ == "__main__":
    main()
