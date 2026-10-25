"""Run real SQL in an owned, disposable loopback PostgreSQL database."""
import argparse
import json
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
from database_public_intake_concurrency import check_public_intake_concurrency

ROOT = Path(__file__).resolve().parents[1]
T12_BACKFILL_INVARIANTS_SQL = r"""
SELECT jsonb_build_object(
 'public.converts.backfill_unlinked', (SELECT count(*)::bigint FROM public.converts WHERE congregation_id IS NOT NULL AND person_id IS NULL),
 'public.converts.backfill_wrong_scope', (SELECT count(*)::bigint FROM public.converts c WHERE c.person_id IS NOT NULL AND NOT EXISTS (SELECT FROM public.ministry_people p WHERE p.id=c.person_id AND p.congregation_id=c.congregation_id)),
 'public.ministry_students.person_wrong_scope', (SELECT count(*)::bigint FROM public.ministry_students s WHERE s.person_id IS NOT NULL AND NOT EXISTS (SELECT FROM public.ministry_people p WHERE p.id=s.person_id AND p.congregation_id=s.congregation_id)),
 'public.ministry_people.count_matches_scoped_converts', ((SELECT count(*) FROM public.ministry_people)=(SELECT count(*) FROM public.converts WHERE congregation_id IS NOT NULL)),
 'public.ministry_students.count_preserved', ((SELECT count(*) FROM public.ministry_students)=%s::bigint)
)::text;
"""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("scenario", nargs="?")
    parser.add_argument("--seed-before-migration")
    parser.add_argument("--seed-scenario")
    parser.add_argument("--verify-after-migration")
    parser.add_argument("--verification-scenario")
    parser.add_argument("--t12-resume-and-drift", action="store_true")
    parser.add_argument("--t12-semantic-snapshots")
    parser.add_argument("--catalog-concurrency", action="store_true")
    parser.add_argument("--access-concurrency", action="store_true")
    parser.add_argument("--convert-concurrency", action="store_true")
    parser.add_argument("--import-concurrency", action="store_true")
    parser.add_argument("--lifecycle-concurrency", action="store_true")
    parser.add_argument("--ministry-registry-concurrency", action="store_true")
    parser.add_argument("--ministry-academic-concurrency", action="store_true")
    parser.add_argument("--convert-student-concurrency", action="store_true")
    parser.add_argument("--ministry-follow-up-concurrency", action="store_true")
    parser.add_argument("--public-intake-concurrency", action="store_true")
    args = parser.parse_args()
    scenario_name = args.scenario or "access_test.sql"
    snapshot_path = None
    if args.t12_semantic_snapshots:
        snapshot_path = Path(args.t12_semantic_snapshots).resolve()
        allowed = (ROOT / "build/verification/corrective-release/T12").resolve()
        if allowed not in snapshot_path.parents or snapshot_path.name != "semantic-snapshots.json":
            raise ValueError("T12 semantic snapshots must be written to the task evidence directory")
        if not args.t12_resume_and_drift:
            parser.error("semantic snapshots require the T12 disposable rehearsal")
    database_tests = (ROOT / "supabase/tests/database").resolve()
    migrations_dir = (ROOT / "supabase/migrations").resolve()
    scenario = (database_tests / scenario_name).resolve()
    if scenario.parent != database_tests or not scenario.is_file():
        raise ValueError("Scenario must belong to database tests")
    if (args.seed_before_migration is None) != (args.seed_scenario is None):
        parser.error("--seed-before-migration and --seed-scenario must be used together")
    if (args.verify_after_migration is None) != (args.verification_scenario is None):
        parser.error("--verify-after-migration and --verification-scenario must be used together")
    if args.t12_resume_and_drift and (args.verify_after_migration !=
            "202610180002_base44_archive_weekly_consistency.sql" or scenario_name != "t12_post_forward_rehearsal.sql"):
        parser.error("T12 resume/drift rehearsal requires its 180002 baseline and final scenario")
    seed_migration = None
    seed_scenario = None
    verify_migration = None
    verification_scenario = None
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
    if args.verify_after_migration is not None:
        migration_name = args.verify_after_migration
        migration_path = (migrations_dir / migration_name).resolve()
        if (Path(migration_name).name != migration_name or migration_path.parent != migrations_dir
                or migration_path.suffix != ".sql" or not migration_path.is_file()):
            raise ValueError("Verification point must name an existing migration")
        verify_scenario_path = (database_tests / args.verification_scenario).resolve()
        if (verify_scenario_path.parent != database_tests or not verify_scenario_path.is_file()
                or verify_scenario_path.suffix != ".sql"):
            raise ValueError("Verification scenario must be an existing .sql database scenario")
        verify_migration = migration_path
        verification_scenario = verify_scenario_path
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

    def capture(connection, *arguments):
        return subprocess.run([psql, "-X", "-q", "-A", "-t", "--no-password", "-v", "ON_ERROR_STOP=1", "-d", connection, *arguments], check=True, timeout=90, text=True, capture_output=True).stdout.strip()

    run(admin, "-c", f'CREATE DATABASE "{database}"')
    try:
        run(target, "-f", str(ROOT / "supabase/tests/fixtures/local_auth_storage.sql"))
        snapshot_bundle = {"baseline": None, "versions": []}

        def capture_semantic_snapshot(version, source_sha256=None):
            from inspect_hosted_contracts import BACKFILL_CATALOG_SQL, CATALOG_SQL, catalog_as_contract
            raw = json.loads(capture(target, "-c", CATALOG_SQL))
            if version == "202610180002":
                snapshot_bundle["baseline"] = {"version": version,
                    "contract": catalog_as_contract(raw), "data_invariants": raw["data_invariants"],
                    "raw_catalog": raw}
            else:
                if version >= "202610190001":
                    if raw.get("capabilities", {}).get("ministry_people"):
                        raw["data_invariants"].update(json.loads(capture(target, "-c", BACKFILL_CATALOG_SQL)))
                    baseline_students = snapshot_bundle["baseline"]["data_invariants"]["public.ministry_students.total"]
                    transform_sql = T12_BACKFILL_INVARIANTS_SQL % int(baseline_students)
                    raw["data_invariants"].update(json.loads(capture(target, "-c", transform_sql)))
                snapshot_bundle["versions"].append({"version": version,
                    "source_sha256": source_sha256, "contract": catalog_as_contract(raw),
                    "data_invariants": raw["data_invariants"], "raw_catalog": raw})
            if snapshot_path is not None:
                snapshot_path.parent.mkdir(parents=True, exist_ok=True)
                snapshot_path.write_text(json.dumps(snapshot_bundle, indent=2) + "\n", encoding="utf-8")

        resumed_versions = set()
        for migration in sorted(migrations_dir.glob("*.sql")):
            if migration == seed_migration:
                run(target, "-f", str(seed_scenario))
            if args.t12_resume_and_drift and migration.name[:12] in resumed_versions:
                continue
            run(target, "-f", str(migration))
            if migration == verify_migration:
                run(target, "-f", str(verification_scenario))
                if snapshot_path is not None:
                    capture_semantic_snapshot("202610180002")
            if snapshot_path is not None and migration.name[:12] in {
                    item["version"] for item in __import__("rehearse_hosted_upgrade").migration_sequence()}:
                import hashlib
                capture_semantic_snapshot(migration.name[:12], hashlib.sha256(migration.read_bytes()).hexdigest())
            if args.t12_resume_and_drift and migration.name[:12] == "202610190001":
                from rehearse_hosted_upgrade import build_migration_resume_plan, migration_sequence, require_catalog_fingerprint_match
                expected = migration_sequence()
                prefix = {item["version"]: item["sha256"] for item in expected
                          if item["version"] in {"202610180003", "202610190001"}}
                pending = build_migration_resume_plan(expected, prefix)
                if not pending or pending[0]["version"] != "202610190002":
                    raise AssertionError("T12 resume planner did not continue after controlled prefix")
                query = "SELECT md5(coalesce(string_agg(format('%s:%s:%s:%s',column_name,data_type,is_nullable,coalesce(column_default,'')),E'\\n' ORDER BY ordinal_position),'')) FROM information_schema.columns WHERE table_schema='public' AND table_name='ministry_people'"
                before = capture(target, "-c", query)
                drift_query = ("BEGIN; ALTER TABLE public.ministry_people ADD COLUMN t12_synthetic_drift text; "
                    + query + "; SELECT (to_regprocedure('private.ministry_register_student_command(uuid,jsonb)') IS NULL); ROLLBACK;")
                drift_lines = capture(target, "-c", drift_query).splitlines()
                if len(drift_lines) != 2 or drift_lines[1] != "t":
                    raise AssertionError("T12 controlled drift did not remain before the next migration")
                try:
                    require_catalog_fingerprint_match(before, drift_lines[0])
                except ValueError as exc:
                    if "catalog drift" not in str(exc):
                        raise
                else:
                    raise AssertionError("T12 catalog drift was not rejected")
                after_rollback = capture(target, "-c", query)
                require_catalog_fingerprint_match(before, after_rollback)
                print("PASS: T12 catalog drift stopped at controlled boundary; transaction rolled back")
                for item in pending:
                    run(target, "-f", str(migrations_dir / item["filename"]))
                    if snapshot_path is not None:
                        import hashlib
                        capture_semantic_snapshot(item["version"], hashlib.sha256(
                            (migrations_dir / item["filename"]).read_bytes()).hexdigest())
                resumed_versions = {item["version"] for item in pending}
                print("PASS: T12 partial migration prefix resumed through exact remaining sequence")
        if snapshot_path is not None:
            from migration_semantic_manifest import build_manifest, classify_manifest_inventory
            from rehearse_hosted_upgrade import migration_sequence
            from inspect_hosted_contracts import catalog_as_contract
            manifest = build_manifest(snapshot_bundle)
            checkpoints = [snapshot_bundle["baseline"], *snapshot_bundle["versions"]]
            sequence = migration_sequence()
            for index, checkpoint in enumerate(checkpoints):
                raw = checkpoint.get("raw_catalog")
                if not isinstance(raw, dict):
                    raise AssertionError("T12 checkpoint lacks raw catalog query output")
                observed_contract = catalog_as_contract(raw)
                ledger = {item["version"] for item in sequence[:index]}
                states = classify_manifest_inventory(manifest, observed_contract, ledger)
                expected_states = (["recorded+present"] * index + ["absent"] * (len(sequence) - index))
                if [item["state"] for item in states] != expected_states:
                    raise AssertionError(f"T12 raw catalog/ledger classifier failed at {checkpoint['version']}")
            print("PASS: inspector raw-catalog normalization classified baseline and all 16 migration prefixes")
            import copy
            final_raw_contract = catalog_as_contract(checkpoints[-1]["raw_catalog"])
            full_ledger = {item["version"] for item in sequence}
            for label, mutate in (
                    ("weekly_guard.stale", lambda value: value["data_invariants"].__setitem__(
                        "private.congregation_week_guards.stale", 1)),
                    ("backfill_wrong_scope", lambda value: value["data_invariants"].__setitem__(
                        "public.converts.backfill_wrong_scope", 1)),
                    ("unexpected ministry_people column", lambda value: value["columns"].__setitem__(
                        "public.ministry_people.t12_correction6_unexpected", {"type": "text"}))):
                adversarial = copy.deepcopy(final_raw_contract)
                mutate(adversarial)
                drift_states = classify_manifest_inventory(manifest, adversarial, full_ledger)
                if [item["state"] for item in drift_states] != ["partial/conflicting"] * len(sequence):
                    raise AssertionError(f"T12 actual inspector catalog failed closed for {label}")
            print("PASS: actual inspector final catalog rejects stale guard, wrong backfill scope, and unexpected column drift")
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
        elif args.public_intake_concurrency:
            if args.scenario is not None:
                run(target, "-f", str(scenario))
                print("PASS: " + scenario_name, flush=True)
            check_public_intake_concurrency(psql, target)
        else:
            run(target, "-f", str(scenario))
            print("PASS: " + scenario_name, flush=True)
    finally:
        run(admin, "-c", f'DROP DATABASE "{database}" WITH (FORCE)')


if __name__ == "__main__":
    main()
