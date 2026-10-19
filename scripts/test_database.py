"""Run real SQL in an owned, disposable loopback PostgreSQL database."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
from urllib.parse import urlparse, urlunparse
import uuid

from database_catalog_concurrency import check_catalog_concurrency
from database_access_concurrency import check_access_concurrency
from database_convert_concurrency import check_convert_concurrency
from database_import_concurrency import check_import_concurrency
from database_lifecycle_concurrency import check_lifecycle_concurrency
from database_ministry_registry_concurrency import check_ministry_registry_concurrency
from database_ministry_academic_concurrency import check_ministry_academic_concurrency
from database_convert_student_concurrency import check_convert_student_concurrency
from database_ministry_follow_up_concurrency import check_ministry_follow_up_concurrency

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("scenario", nargs="?", default="access_test.sql")
    parser.add_argument("--seed-before-migration")
    parser.add_argument("--seed-scenario")
    parser.add_argument("--catalog-concurrency", action="store_true")
    parser.add_argument("--access-concurrency", action="store_true")
    parser.add_argument("--convert-concurrency", action="store_true")
    parser.add_argument("--import-concurrency", action="store_true")
    parser.add_argument("--lifecycle-concurrency", action="store_true")
    parser.add_argument("--ministry-registry-concurrency", action="store_true")
    parser.add_argument("--ministry-academic-concurrency", action="store_true")
    parser.add_argument("--convert-student-concurrency", action="store_true")
    parser.add_argument("--ministry-follow-up-concurrency", action="store_true")
    args = parser.parse_args()
    database_tests = (ROOT / "supabase/tests/database").resolve()
    migrations_dir = (ROOT / "supabase/migrations").resolve()
    scenario = (database_tests / args.scenario).resolve()
    if scenario.parent != database_tests or not scenario.is_file():
        raise ValueError("Scenario must belong to database tests")
    if (args.seed_before_migration is None) != (args.seed_scenario is None):
        parser.error("--seed-before-migration and --seed-scenario must be used together")
    seed_migration = None
    seed_scenario = None
    if args.seed_before_migration is not None:
        migration_name = args.seed_before_migration
        migration_path = (migrations_dir / migration_name).resolve()
        migrations = sorted(migrations_dir.glob("*.sql"))
        if (
            Path(migration_name).name != migration_name
            or migration_path.parent != migrations_dir
            or migration_path.suffix != ".sql"
            or migration_path not in migrations
        ):
            raise ValueError("Seed target must name an existing migration")
        seed_scenario = (database_tests / args.seed_scenario).resolve()
        if (
            seed_scenario.parent != database_tests
            or not seed_scenario.is_file()
            or seed_scenario.suffix != ".sql"
        ):
            raise ValueError("Seed scenario must be an existing .sql database scenario")
        seed_migration = migration_path
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
        for migration in sorted(migrations_dir.glob("*.sql")):
            if migration == seed_migration:
                run(target, "-f", str(seed_scenario))
            run(target, "-f", str(migration))
        if args.catalog_concurrency:
            check_catalog_concurrency(psql, target)
        elif args.import_concurrency:
            check_import_concurrency(psql, target)
        elif args.access_concurrency:
            check_access_concurrency(psql, target)
        elif args.convert_concurrency:
            check_convert_concurrency(psql, target)
        elif args.lifecycle_concurrency:
            check_lifecycle_concurrency(psql, target)
        elif args.ministry_registry_concurrency:
            check_ministry_registry_concurrency(psql, target)
        elif args.ministry_academic_concurrency:
            check_ministry_academic_concurrency(psql, target)
        elif args.convert_student_concurrency:
            check_convert_student_concurrency(psql, target)
        elif args.ministry_follow_up_concurrency:
            check_ministry_follow_up_concurrency(psql, target)
        else:
            run(target, "-f", str(scenario))
            print("PASS: " + args.scenario, flush=True)
    finally:
        run(admin, "-c", f'DROP DATABASE "{database}" WITH (FORCE)')


if __name__ == "__main__":
    main()
