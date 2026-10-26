"""Run one reviewed public-intake SQL scenario against a confirmed hosted project.

This is deliberately separate from test_database.py, whose loopback-only guard
remains unchanged. Operator credentials are supplied to psql through its
environment; the runner never prints connection details or query output.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timedelta, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import uuid
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
SCENARIO_DIR = (ROOT / "supabase/tests/database").resolve()
SCENARIOS = {
    "public_registration_authority_test.sql": ("202610250002",),
    "public_intake_test.sql": ("202610250002", "202610250003"),
    "pending_review_test.sql": ("202610250002", "202610250003", "202610250004"),
}
MAX_BACKUP_AGE = timedelta(hours=24)
PROJECT_REF = re.compile(r"^[a-z0-9]{20}$")
UUID_LITERAL = re.compile(r"(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b")


class SafetyError(ValueError):
    """An input did not satisfy a hosted-run safety condition."""


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _outside_repository(path: Path, repository: Path) -> bool:
    resolved = path.resolve()
    root = repository.resolve()
    return resolved != root and root not in resolved.parents


def validate_backup_manifest(manifest_path: str | Path | None,
                             project_ref: str,
                             repository: Path = ROOT) -> dict:
    if manifest_path is None:
        raise SafetyError("backup manifest is required")
    path = Path(manifest_path).expanduser().resolve()
    if not _outside_repository(path, repository) or not path.is_file():
        raise SafetyError("backup manifest must be an existing external file")
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
        archive = Path(manifest["archive_path"]).expanduser().resolve()
        created = datetime.fromisoformat(manifest["created_at"].replace("Z", "+00:00"))
        digest = str(manifest["sha256"]).lower()
    except (OSError, ValueError, TypeError, KeyError, json.JSONDecodeError) as exc:
        raise SafetyError("backup manifest is malformed") from exc
    now = utc_now()
    if manifest.get("project_ref") != project_ref:
        raise SafetyError("backup manifest project does not match target")
    if created.tzinfo is None or created > now + timedelta(minutes=5) or now - created > MAX_BACKUP_AGE:
        raise SafetyError("backup manifest is not fresh")
    if not _outside_repository(archive, repository) or not archive.is_file() or archive.stat().st_size == 0:
        raise SafetyError("backup archive must be an existing external file")
    if (manifest.get("full_backup") is not True or manifest.get("archive_readable") is not True
            or not str(manifest.get("restore_path_verified", "")).strip()):
        raise SafetyError("full-backup, readability, and restore-path evidence are required")
    if not re.fullmatch(r"[0-9a-f]{64}", digest):
        raise SafetyError("backup archive checksum is invalid")
    digest_builder = hashlib.sha256()
    with archive.open("rb") as stream:
        while chunk := stream.read(1024 * 1024):
            digest_builder.update(chunk)
    actual = digest_builder.hexdigest()
    if actual != digest:
        raise SafetyError("backup archive checksum does not match")
    return {"sha256": digest, "created_at": created.astimezone(timezone.utc).isoformat()}


def _strip_sql_comments(sql: str) -> str:
    sql = re.sub(r"/\*.*?\*/", " ", sql, flags=re.DOTALL)
    return re.sub(r"(?m)--[^\r\n]*", " ", sql)


def validate_scenario_sql(sql: str, scenario_name: str) -> None:
    if scenario_name not in SCENARIOS:
        raise SafetyError("scenario is not allowlisted")
    code = _strip_sql_comments(sql).strip()
    if not re.match(r"(?is)^BEGIN\s*;", code) or not re.search(r"(?is)ROLLBACK\s*;\s*$", code):
        raise SafetyError("scenario must be a single explicit rollback transaction")
    forbidden = re.compile(
        r"(?is)\b(?:COMMIT|END\s+TRANSACTION|ABORT\s+TRANSACTION|"
        r"DROP|TRUNCATE|ALTER|VACUUM|ANALYZE|REINDEX|CLUSTER|REFRESH|"
        r"CREATE\s+(?:DATABASE|SCHEMA|ROLE|USER|EXTENSION|SUBSCRIPTION)|"
        r"COPY\s+[^;]*\bPROGRAM)\b"
    )
    if forbidden.search(code):
        raise SafetyError("scenario contains a prohibited or non-transactional operation")
    create_functions = re.findall(
        r"(?is)\bCREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+([a-z_][a-z0-9_]*\.[a-z_][a-z0-9_]*)",
        code,
    )
    allowed_functions = {"pg_temp." + name for name in
                         ("assert_true", "expect_failure", "reject", "draft", "request", "receive", "seed_pending",
                          "review_payload", "call_list", "call_get", "call_review",
                          "reset_intake", "seed_event", "expect_failure")}
    if scenario_name in ("public_intake_test.sql", "pending_review_test.sql"):
        allowed_functions.add("private.public_intake_now")
    if scenario_name == "pending_review_test.sql":
        allowed_functions.add("public.ieadpe_create_convert")
    if any(name.lower() not in allowed_functions for name in create_functions):
        raise SafetyError("scenario creates or replaces a non-allowlisted function")
    control_code = re.sub(r"'(?:''|[^'])*'", " ", code)
    control_code = re.sub(r"(?is)\$[a-z_0-9]*\$.*?\$[a-z_0-9]*\$", " ", control_code)
    for create in re.finditer(r"(?is)\bCREATE\b", control_code):
        tail = control_code[create.start():]
        allowed_create = re.match(
            r"(?is)CREATE\s+(?:(?:OR\s+REPLACE\s+)?FUNCTION\s+"
            r"(?:pg_temp\.[a-z_][a-z0-9_]*|private\.public_intake_now|"
            r"public\.ieadpe_create_convert)|TEMP(?:ORARY)?\s+TABLE\s+[a-z_][a-z0-9_]*)\b",
            tail,
        )
        if not allowed_create:
            raise SafetyError("scenario contains non-allowlisted DDL")
        if "public.ieadpe_create_convert" in allowed_create.group(0).lower() and scenario_name != "pending_review_test.sql":
            raise SafetyError("canonical function override is allowed only in the rollback-only T5 scenario")
        if "private.public_intake_now" in allowed_create.group(0).lower() and scenario_name not in (
                "public_intake_test.sql", "pending_review_test.sql"):
            raise SafetyError("test clock override is not allowed for this scenario")
    statements = [part.strip() for part in code.split(";") if part.strip()]
    for statement in statements:
        if re.match(r"(?is)^GRANT\b", statement):
            granted = re.search(r"(?is)\bON\s+([a-z_][a-z0-9_,\s]*?)\s+TO\b", statement)
            allowed_grant_targets = {
                "public_registration_authority_test.sql": {"payload", "created", "drafts"},
                "public_intake_test.sql": {"catalog_expected", "catalog_result", "intake_fixture", "intake_dates",
                                           "intake_result"},
                "pending_review_test.sql": {"rpc_results"},
            }[scenario_name]
            targets = {item.strip().lower() for item in granted.group(1).split(",")} if granted else set()
            if not targets or not targets <= allowed_grant_targets:
                raise SafetyError("grants are allowed only on T1 temporary fixtures")
        if re.match(r"(?is)^REVOKE\b", statement):
            raise SafetyError("privilege revocation is not permitted in hosted scenarios")
        if re.match(r"(?is)^(?:UPDATE|DELETE\s+FROM)\b", statement):
            run_uuid_scope = bool(UUID_LITERAL.search(statement))
            safe_singleton = (
                re.match(r"(?is)^UPDATE\s+private\.public_intake_settings\b", statement)
                and scenario_name in ("public_intake_test.sql", "pending_review_test.sql")
            )
            safe_temp_clock = (
                re.match(r"(?is)^UPDATE\s+(?:intake_clock|review_clock)\b", statement)
                and scenario_name in ("public_intake_test.sql", "pending_review_test.sql")
            )
            t1_temp_scope = (
                scenario_name == "public_registration_authority_test.sql"
                and re.match(r"(?is)^UPDATE\s+drafts\b", statement)
                and re.search(r"(?is)\bWHERE\s+label\s*=\s*'a[12]'\s*$", statement)
            )
            if not (safe_singleton or safe_temp_clock or t1_temp_scope or
                    (re.search(r"(?is)\bWHERE\b", statement) and run_uuid_scope)):
                raise SafetyError("mutating statements require an exact run-owned UUID predicate")
    if re.search(r"(?is)(?:^|;)\s*CALL\s+[\w\"]", code):
        raise SafetyError("stored procedures are not permitted in hosted scenarios")
    # Each mutating predicate must be scoped to an explicit fixture UUID. The
    # UUIDs are replaced with run-derived values before execution.
    if not UUID_LITERAL.search(code):
        raise SafetyError("scenario has no run-owned fixture identifiers")


def load_scenario(scenario_name: str, run_id: str, repository: Path = ROOT) -> tuple[str, str]:
    if scenario_name not in SCENARIOS or Path(scenario_name).name != scenario_name:
        raise SafetyError("scenario name is not allowlisted")
    path = (repository / "supabase/tests/database" / scenario_name).resolve()
    if path.parent != (repository / "supabase/tests/database").resolve() or not path.is_file():
        raise SafetyError("scenario must be an allowlisted repository file")
    try:
        run_uuid = uuid.UUID(run_id)
    except (ValueError, AttributeError) as exc:
        raise SafetyError("run id must be a UUID") from exc
    if str(run_uuid) != run_id.lower():
        raise SafetyError("run id must use canonical UUID syntax")
    original = path.read_text(encoding="utf-8")
    validate_scenario_sql(original, scenario_name)
    source_digest = hashlib.sha256(original.encode("utf-8")).hexdigest()

    def namespaced(match: re.Match[str]) -> str:
        derived = uuid.uuid5(run_uuid, match.group(0).lower())
        return str(derived)

    transformed = UUID_LITERAL.sub(namespaced, original)
    # Dynamic UUID series in the T2 scenario use a fixed first 24 hex digits
    # followed by a generated suffix. Namespace that prefix as well.
    prefix_pattern = re.compile(
        r"(?<=')([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-)(?='\s*\|\|)", re.IGNORECASE)
    transformed = prefix_pattern.sub(
        lambda match: str(uuid.uuid5(run_uuid, match.group(1).lower() + "000000000000"))[:-12],
        transformed,
    )
    # Namespace every synthetic test email to avoid collisions across runs.
    transformed = re.sub(
        r"([a-z0-9._+-]+)@example\.test",
        lambda match: f"run-{run_uuid.hex}-{match.group(1)}@example.test",
        transformed,
        flags=re.IGNORECASE,
    )
    if "authority-" in original and "authority-" in transformed and run_uuid.hex not in transformed:
        raise SafetyError("fixture ownership could not be established")
    return transformed, source_digest


def _confirm_target(project_ref: str, env: dict[str, str]) -> str:
    if not PROJECT_REF.fullmatch(project_ref):
        raise SafetyError("project ref format is invalid")
    if env.get("PUBLIC_INTAKE_TRUSTED_PROJECT_REF") != project_ref:
        raise SafetyError("project ref does not match trusted local configuration")
    configured_url = urlparse(env.get("SUPABASE_URL", ""))
    database_url = urlparse(env.get("PUBLIC_INTAKE_DATABASE_URL", ""))
    if (configured_url.scheme != "https" or configured_url.hostname != f"{project_ref}.supabase.co"
            or database_url.scheme not in ("postgres", "postgresql")
            or database_url.hostname != f"db.{project_ref}.supabase.co"
            or database_url.query == ""):
        raise SafetyError("trusted project URL and SSL database URL must identify the same project")
    if "sslmode=require" not in database_url.query.lower():
        raise SafetyError("database connection must require TLS")
    return project_ref


def _psql_command(args: argparse.Namespace) -> list[str]:
    if args.psql_command_json:
        try:
            command = json.loads(args.psql_command_json)
        except json.JSONDecodeError as exc:
            raise SafetyError("psql command override must be a JSON argument array") from exc
        if (not isinstance(command, list) or not command or
                any(not isinstance(part, str) or not part for part in command)):
            raise SafetyError("psql command override must be a non-empty string array")
        return command
    executable = shutil.which("psql")
    if not executable:
        raise SafetyError("psql is unavailable")
    return [executable]


def _verify_account_project(args: argparse.Namespace, env: dict[str, str]) -> None:
    if args.supabase_command_json:
        try:
            command = json.loads(args.supabase_command_json)
        except json.JSONDecodeError as exc:
            raise SafetyError("Supabase CLI command override must be a JSON argument array") from exc
        if not isinstance(command, list) or not command or any(not isinstance(part, str) or not part for part in command):
            raise SafetyError("Supabase CLI command override must be a non-empty string array")
        executable = command
    else:
        cli = shutil.which("supabase")
        if not cli:
            raise SafetyError("authenticated Supabase CLI is unavailable")
        executable = [cli]
    result = subprocess.run(
        [*executable, "projects", "list", "--output-format", "json"],
        text=True, capture_output=True, timeout=60, env=env, check=False,
    )
    if result.returncode != 0:
        raise SafetyError("authenticated Supabase project listing failed")
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise SafetyError("authenticated project listing was not valid JSON") from exc
    projects = payload if isinstance(payload, list) else payload.get("projects", payload.get("data", []))
    if not isinstance(projects, list) or not any(
            isinstance(item, dict) and item.get("id", item.get("ref")) == args.project_ref
            for item in projects):
        raise SafetyError("current authenticated Supabase account cannot confirm the project ref")


def _psql(base: list[str], env: dict[str, str], sql: str, stdin: str | None = None) -> str:
    result = subprocess.run(
        [*base, "-X", "--no-password", "-v", "ON_ERROR_STOP=1", "-q", "-A", "-t", "-c", sql]
        if stdin is None else
        [*base, "-X", "--no-password", "-v", "ON_ERROR_STOP=1", "-q", "-A", "-t", "-f", "-"],
        input=stdin, text=True, capture_output=True, timeout=90, env=env, check=False,
    )
    if result.returncode != 0:
        raise SafetyError("database preflight or scenario execution failed")
    return result.stdout.strip()


def _evidence_path(value: str, repository: Path) -> Path:
    path = Path(value).expanduser().resolve()
    if not _outside_repository(path, repository) or path.exists():
        raise SafetyError("evidence manifest must be a new external path")
    path.parent.mkdir(parents=True, exist_ok=True)
    return path


def _baseline_query(scenario_name: str) -> str:
    counts = {
        "public.converts": "SELECT count(*)::bigint FROM public.converts",
        "public.ministry_people": "SELECT count(*)::bigint FROM public.ministry_people",
        "public.weekly_reports": "SELECT count(*)::bigint FROM public.weekly_reports",
        "private.mutation_receipts": "SELECT count(*)::bigint FROM private.mutation_receipts",
        "public.photo_assets": "SELECT count(*)::bigint FROM public.photo_assets",
        "storage.objects": "SELECT count(*)::bigint FROM storage.objects",
        "auth.users": "SELECT count(*)::bigint FROM auth.users",
        "private.congregation_week_guards": "SELECT coalesce(sum(conversion_count),0)::bigint FROM private.congregation_week_guards",
        "public.user_access": "SELECT count(*)::bigint FROM public.user_access",
    }
    if scenario_name != "public_registration_authority_test.sql":
        counts.update({
            "private.public_intake_submissions": "SELECT count(*)::bigint FROM private.public_intake_submissions",
            "private.public_intake_receipts": "SELECT count(*)::bigint FROM private.public_intake_receipts",
            "private.public_intake_decisions": "SELECT count(*)::bigint FROM private.public_intake_decisions",
            "private.public_intake_accepted_events": "SELECT count(*)::bigint FROM private.public_intake_accepted_events",
        })
    pairs = ",".join("'" + key + "',(" + query + ")" for key, query in counts.items())
    return "SELECT jsonb_build_object(" + pairs + ")::text;"


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-ref", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--scenario", required=True, choices=sorted(SCENARIOS))
    parser.add_argument("--backup-manifest", required=True,
                        help="fresh external JSON manifest with archive checksum/readability evidence")
    parser.add_argument("--evidence-manifest", required=True,
                        help="new output path outside the repository")
    parser.add_argument("--concurrency", action="store_true",
                        help="run the separately reviewed intake concurrency scenario")
    parser.add_argument("--psql-command-json",
                        help=argparse.SUPPRESS)
    parser.add_argument("--supabase-command-json", help=argparse.SUPPRESS)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = _parser()
    args = parser.parse_args(argv)
    try:
        if args.concurrency:
            raise SafetyError(
                "hosted concurrency is blocked until the existing race helper removes global TRUNCATE and uses run-owned fixtures"
            )
        run_id = str(uuid.UUID(args.run_id))
        if run_id != args.run_id.lower():
            raise SafetyError("run id must use canonical UUID syntax")
        backup = validate_backup_manifest(args.backup_manifest, args.project_ref)
        sql, scenario_digest = load_scenario(args.scenario, run_id)
        _confirm_target(args.project_ref, os.environ)
        _verify_account_project(args, os.environ.copy())
        evidence_path = _evidence_path(args.evidence_manifest, ROOT)
        base = _psql_command(args)
        process_env = os.environ.copy()
        # Keep the credential-bearing URL out of argv and all output streams.
        process_env["PGDATABASE"] = process_env["PUBLIC_INTAKE_DATABASE_URL"]
        process_env.pop("PUBLIC_INTAKE_DATABASE_URL", None)

        confirmation = input("Type the exact project ref to confirm this hosted run: ").strip()
        if confirmation != args.project_ref:
            raise SafetyError("typed project confirmation did not match")
        target_result = _psql(
            base, process_env,
            "SELECT current_database() = 'postgres' AND current_setting('server_version_num') <> '';"
        )
        if target_result.lower() not in ("t", "true"):
            raise SafetyError("connected database identity probe did not confirm the target")
        required_versions = SCENARIOS[args.scenario]
        version_sql = (
            "SELECT count(DISTINCT version) = " + str(len(required_versions)) +
            " FROM supabase_migrations.schema_migrations WHERE version IN (" +
            ",".join("'" + version + "'" for version in required_versions) + ");"
        )
        if _psql(base, process_env, version_sql).lower() not in ("t", "true"):
            raise SafetyError("required additive migrations are not confirmed as applied")
        counts_sql = _baseline_query(args.scenario)
        try:
            baseline_counts = json.loads(_psql(base, process_env, counts_sql))
        except json.JSONDecodeError as exc:
            raise SafetyError("baseline count response was invalid") from exc
        if not isinstance(baseline_counts, dict) or any(
                not isinstance(value, int) or value < 0 for value in baseline_counts.values()):
            raise SafetyError("baseline count response was incomplete")
        _psql(base, process_env, "SELECT 1;", stdin=sql)
        try:
            after_counts = json.loads(_psql(base, process_env, counts_sql))
        except json.JSONDecodeError as exc:
            raise SafetyError("after-count response was invalid") from exc
        if after_counts != baseline_counts:
            raise SafetyError("before/after database counts did not reconcile")
        evidence = {
            "status": "PASS",
            "run_id": run_id,
            "project_ref": args.project_ref,
            "scenario": args.scenario,
            "scenario_sha256": scenario_digest,
            "required_migrations": list(required_versions),
            "backup_sha256": backup["sha256"],
            "backup_created_at": backup["created_at"],
            "target_confirmed": True,
            "transaction_policy": "scenario explicitly ends in ROLLBACK",
            "before_counts": baseline_counts,
            "after_counts": after_counts,
            "reconciled": True,
            "completed_at": utc_now().isoformat(),
        }
        evidence_path.write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")
        print("Hosted scenario completed; redacted evidence manifest written.")
        return 0
    except (SafetyError, OSError, ValueError, subprocess.TimeoutExpired, EOFError) as exc:
        # Do not expose exception text: parser errors from external tools may
        # contain SQL values, connection strings, or provider response bodies.
        print(f"Hosted scenario refused or failed ({type(exc).__name__}).", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
