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
from urllib.parse import parse_qs, unquote, urlparse

ROOT = Path(__file__).resolve().parents[1]
SCENARIO_DIR = (ROOT / "supabase/tests/database").resolve()
SCENARIOS = {
    "public_registration_authority_test.sql": ("202610250002",),
    "public_intake_test.sql": ("202610250002", "202610250003"),
    "public_intake_hosted_smoke_test.sql": ("202610250002", "202610250003"),
    "pending_review_test.sql": ("202610250002", "202610250003", "202610250004"),
}
SCENARIO_SHA256 = {
    "public_registration_authority_test.sql": "6700394711d988fceaa10da0e8a892cd704bb2fa4cbcf2b9138ee90dcd0ec732",
    "public_intake_test.sql": "ab555bb7086a4693d7becfb4938774a848c384261947930332bc993fc1ae7c3b",
    "public_intake_hosted_smoke_test.sql": "d77c8256e10c4fc1310d28afaa8baf47ea22c68f6dd2cb1c8f57db41eb772b7d",
    "pending_review_test.sql": "6663d00030d4a0d6f3276b70937b9942dfd89f7a6a67c614e902066bc449664d",
}
T2_SMOKE_SUBMISSION_PLACEHOLDER = "0f100000-0000-4000-8000-000000000001"
T2_HOSTED_BLOCKED_SCENARIOS = {
    "public_intake_test.sql": (
        "BLOCKED: full rolling-window/capacity boundaries depend on a long transaction-level "
        "global intake lock and the shared live pending count; use the short hosted smoke scenario"
    ),
}
MAX_BACKUP_AGE = timedelta(hours=24)
PROJECT_REF = re.compile(r"^[a-z0-9]{20}$")
UUID_PATTERN = r"[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}"
UUID_LITERAL = re.compile(r"(?i)\b" + UUID_PATTERN + r"\b")
DANGEROUS_FUNCTION = re.compile(
    r"(?i)\b(?:pg_terminate_backend|pg_cancel_backend|pg_reload_conf|pg_read_file|"
    r"pg_read_binary_file|pg_write_file|pg_write_binary_file|pg_ls_dir|pg_sleep|"
    r"pg_advisory_lock|pg_advisory_xact_lock|dblink|lo_import|lo_export)\s*\("
)
APPROVED_SQL_CALLS = {
    "and", "auth.users", "bool_and", "coalesce", "convert_to", "count", "created",
    "drafts", "encode", "exists", "format", "has_function_privilege", "has_table_privilege", "in",
    "jsonb_array_elements", "jsonb_array_length", "jsonb_build_object", "jsonb_set",
    "jsonb_typeof", "now", "payload", "intake_smoke_scope", "pg_temp.assert_true", "pg_temp.call_get",
    "pg_temp.call_list", "pg_temp.call_review", "pg_temp.draft", "pg_temp.expect_failure",
    "pg_temp.reject", "pg_temp.review_payload", "pg_temp.run_smoke", "pg_temp.seed_pending",
    "private.convert_registration_command",
    "private.business_today", "private.public_intake_cleanup", "private.public_intake_now",
    "private.public_intake_submissions", "public.congregations", "public.ieadpe_create_convert",
    "public.ieadpe_create_photo_draft", "public.ieadpe_public_congregations",
    "public.ieadpe_receive_public_intake",
    "public.ieadpe_get_pending_intake", "public.ieadpe_list_pending_intake",
    "public.ieadpe_ministry_list_converts", "public.ieadpe_review_pending_intake",
    "or", "public.user_access", "repeat", "review_clock", "rpc_results", "select", "set_config",
    "sha256", "storage.objects", "sum", "to_jsonb", "to_regprocedure", "values",
}
SQL_CALL = re.compile(r"(?i)\b(?:([a-z_][a-z0-9_$]*)\s*\.\s*)?([a-z_][a-z0-9_$]*)\s*\(")


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
    if DANGEROUS_FUNCTION.search(code):
        raise SafetyError("scenario calls an unapproved or privileged SQL function")
    calls = {
        ((schema.lower() + ".") if schema else "") + function.lower()
        for schema, function in SQL_CALL.findall(code)
    }
    if not calls <= APPROVED_SQL_CALLS:
        raise SafetyError("scenario contains an unapproved SQL function or expression")
    create_functions = re.findall(
        r"(?is)\bCREATE\s+(?:OR\s+REPLACE\s+)?FUNCTION\s+([a-z_][a-z0-9_]*\.[a-z_][a-z0-9_]*)",
        code,
    )
    allowed_functions = {"pg_temp." + name for name in
                         ("assert_true", "expect_failure", "reject", "draft", "request", "receive", "run_smoke", "seed_pending",
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
                "public_intake_hosted_smoke_test.sql": {"intake_smoke_scope"},
                "pending_review_test.sql": {"rpc_results"},
            }[scenario_name]
            targets = {item.strip().lower() for item in granted.group(1).split(",")} if granted else set()
            if not targets or not targets <= allowed_grant_targets:
                raise SafetyError("grants are allowed only on scenario temporary fixtures")
        if (scenario_name == "public_intake_hosted_smoke_test.sql"
                and re.match(r"(?is)^INSERT\s+INTO\b", statement)
                and not re.match(r"(?is)^INSERT\s+INTO\s+intake_smoke_scope\b", statement)):
            raise SafetyError("T2 smoke inserts are allowed only into its transaction-local scope fixture")
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
    source_digest = hashlib.sha256(original.encode("utf-8")).hexdigest()
    if source_digest != SCENARIO_SHA256[scenario_name]:
        raise SafetyError("scenario content does not match the reviewed digest")
    validate_scenario_sql(original, scenario_name)

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


def run_ownership(sql: str) -> dict:
    all_ids = sorted(set(UUID_LITERAL.findall(sql)))
    auth_statement = re.search(r"(?is)INSERT\s+INTO\s+auth\.users\b.*?\bVALUES\s*(.*?);", sql)
    auth_ids = sorted(set(UUID_LITERAL.findall(auth_statement.group(1)))) if auth_statement else []
    receipt_pattern = re.compile(
        r"(?is)\b(?:ieadpe_create_convert|ieadpe_create_photo_draft|"
        r"ieadpe_review_pending_intake|call_review)\s*\(\s*'(" + UUID_PATTERN + r")'"
    )
    receipt_ids = sorted(set(match.group(1).lower() for match in receipt_pattern.finditer(sql)))
    intake_receipt_match = re.search(
        r"(?is)\bsubmission_id\s+uuid\s*:=\s*'(" + UUID_PATTERN + r")'\s*;", sql)
    intake_receipt_ids = (
        sorted({intake_receipt_match.group(1).lower()}) if intake_receipt_match else [])
    return {
        "fixture_ids": all_ids,
        "auth_user_ids": auth_ids,
        "operation_receipt_ids": receipt_ids,
        "operation_receipts": [
            {"operation_id": operation_id, "persistent_after_rollback": False}
            for operation_id in receipt_ids
        ],
        "intake_receipt_ids": intake_receipt_ids,
        "intake_receipts": [
            {
                "table": "private.public_intake_receipts",
                "submission_id": submission_id,
                "persistent_after_rollback": False,
            }
            for submission_id in intake_receipt_ids
        ],
        "persistent_rows_expected": 0,
        "disposition": "all SQL fixtures and receipts are inside the explicit rollback transaction",
    }


def _confirm_target(project_ref: str, env: dict[str, str]) -> str:
    if not PROJECT_REF.fullmatch(project_ref):
        raise SafetyError("project ref format is invalid")
    if env.get("PUBLIC_INTAKE_TRUSTED_PROJECT_REF") != project_ref:
        raise SafetyError("project ref does not match trusted local configuration")
    configured_url = urlparse(env.get("SUPABASE_URL", ""))
    database_url = urlparse(env.get("PUBLIC_INTAKE_DATABASE_URL", ""))
    try:
        port = database_url.port
        query = parse_qs(database_url.query, keep_blank_values=True)
    except ValueError as exc:
        raise SafetyError("database connection URL is invalid") from exc
    direct_host = database_url.hostname == f"db.{project_ref}.supabase.co"
    pooler_host = bool(database_url.hostname and re.fullmatch(
        r"aws-[0-9]+-[a-z0-9-]+\.pooler\.supabase\.com", database_url.hostname))
    valid_direct = direct_host and port in (None, 5432)
    valid_pooler = (
        pooler_host and port == 5432 and database_url.username in {
            f"postgres.{project_ref}", f"cli_login_postgres.{project_ref}"
        }
    )
    if (configured_url.scheme != "https" or configured_url.hostname != f"{project_ref}.supabase.co"
            or database_url.scheme not in ("postgres", "postgresql")
            or not (valid_direct or valid_pooler) or database_url.path != "/postgres"
            or database_url.fragment or set(query) != {"sslmode"}
            or query.get("sslmode") != ["require"]):
        raise SafetyError("trusted project URL and SSL database URL must identify the same project")
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


def _psql_environment(database_url: str, source_env: dict[str, str]) -> dict[str, str]:
    parsed = urlparse(database_url)
    try:
        port = parsed.port or 5432
    except ValueError as exc:
        raise SafetyError("database connection URL is invalid") from exc
    username = unquote(parsed.username or "")
    password = unquote(parsed.password or "")
    if not parsed.hostname or not username or not password:
        raise SafetyError("database connection URL must include host and credentials")
    result = {
        key: value for key, value in source_env.items()
        if not key.upper().startswith("PG")
    }
    result.pop("PUBLIC_INTAKE_DATABASE_URL", None)
    result.update({
        "PGHOST": parsed.hostname,
        "PGPORT": str(port),
        "PGUSER": username,
        "PGPASSWORD": password,
        "PGDATABASE": "postgres",
        "PGSSLMODE": "require",
    })
    return result


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


def _migration_ledger_query(scenario_name: str) -> str:
    versions = ",".join("'" + version + "'" for version in SCENARIOS[scenario_name])
    return (
        "SELECT coalesce(jsonb_agg(version ORDER BY version),'[]'::jsonb)::text "
        "FROM supabase_migrations.schema_migrations WHERE version IN (" + versions + ");"
    )


def _baseline_query(scenario_name: str, include_intake_schema: bool | None = None) -> str:
    if include_intake_schema is None:
        include_intake_schema = scenario_name != "public_registration_authority_test.sql"
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
    if include_intake_schema:
        counts.update({
            "private.public_intake_submissions": "SELECT count(*)::bigint FROM private.public_intake_submissions",
            "private.public_intake_receipts": "SELECT count(*)::bigint FROM private.public_intake_receipts",
            "private.public_intake_decisions": "SELECT count(*)::bigint FROM private.public_intake_decisions",
            "private.public_intake_accepted_events": "SELECT count(*)::bigint FROM private.public_intake_accepted_events",
        })
    count_pairs = ",".join("'" + key + "',(" + query + ")" for key, query in counts.items())
    def revision_snapshot(table: str) -> str:
        return (
            "jsonb_build_object('max',coalesce((SELECT max(revision) FROM " + table + "),0)::bigint,"
            "'distribution',coalesce((SELECT jsonb_object_agg(revision,row_count) FROM ("
            "SELECT revision,count(*)::bigint AS row_count FROM " + table +
            " GROUP BY revision) AS buckets),'{}'::jsonb))"
        )

    revisions = {
        "public.converts": revision_snapshot("public.converts"),
        "public.ministry_people": revision_snapshot("public.ministry_people"),
    }
    if include_intake_schema:
        revisions["private.public_intake_submissions"] = revision_snapshot("private.public_intake_submissions")
    revision_pairs = ",".join("'" + key + "'," + query for key, query in revisions.items())
    settings_query = (
        "(SELECT to_jsonb(s) FROM private.public_intake_settings s WHERE singleton)"
        if include_intake_schema else "NULL::jsonb"
    )
    signatures = [
        "public.ieadpe_create_convert(uuid,jsonb)",
        "public.ieadpe_create_photo_draft(uuid,jsonb)",
    ]
    if scenario_name == "pending_review_test.sql":
        signatures.extend((
            "public.ieadpe_list_pending_intake(jsonb)",
            "public.ieadpe_get_pending_intake(jsonb)",
            "public.ieadpe_review_pending_intake(uuid,jsonb)",
        ))
    if include_intake_schema:
        signatures.extend((
            "public.ieadpe_public_congregations(jsonb)",
            "public.ieadpe_receive_public_intake(jsonb)",
        ))
    grant_pairs = []
    for signature in signatures:
        key = signature.replace("'", "")
        for role in ("anon", "authenticated", "service_role"):
            grant_pairs.append(
                "'" + key + "." + role + "',coalesce(has_function_privilege('" + role + "',"
                "to_regprocedure('" + signature + "'),'EXECUTE'),false)"
            )
    if include_intake_schema:
        for table in (
                "private.public_intake_submissions", "private.public_intake_receipts",
                "private.public_intake_accepted_events", "private.public_intake_decisions"):
            for role in ("anon", "authenticated", "service_role"):
                grant_pairs.append(
                    "'" + table + "." + role + ".select',has_table_privilege('" + role + "','" +
                    table + "','SELECT')"
                )
    migration_versions = ",".join("'" + version + "'" for version in SCENARIOS[scenario_name])
    return (
        "SELECT jsonb_build_object(" +
        "'counts',jsonb_build_object(" + count_pairs + ")," +
        "'revisions',jsonb_build_object(" + revision_pairs + ")," +
        "'settings'," + settings_query + "," +
        "'grants',jsonb_build_object(" + ",".join(grant_pairs) + ")," +
        "'migrations',to_jsonb(ARRAY(SELECT version FROM supabase_migrations.schema_migrations "
        "WHERE version IN (" + migration_versions + ") ORDER BY version))" +
        ")::text;"
    )


def _validate_snapshot(snapshot: object) -> bool:
    if not isinstance(snapshot, dict) or set(snapshot) != {"counts", "revisions", "settings", "grants", "migrations"}:
        return False
    if not isinstance(snapshot["counts"], dict) or any(
            not isinstance(value, int) or value < 0 for value in snapshot["counts"].values()):
        return False
    if not isinstance(snapshot["revisions"], dict) or any(
            not isinstance(value, dict) or not isinstance(value.get("max"), int)
            or value["max"] < 0 or not isinstance(value.get("distribution"), dict)
            or any(not str(key).isdigit() or not isinstance(count, int) or count < 0
                   for key, count in value["distribution"].items())
            for value in snapshot["revisions"].values()):
        return False
    if snapshot["settings"] is not None and not isinstance(snapshot["settings"], dict):
        return False
    if not isinstance(snapshot["grants"], dict) or any(
            not isinstance(value, bool) for value in snapshot["grants"].values()):
        return False
    if not isinstance(snapshot["migrations"], list) or any(
            not isinstance(value, str) for value in snapshot["migrations"]):
        return False
    return True


def _write_evidence(path: Path, evidence: dict) -> None:
    path.write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")


def _run_owned_uuid(run_id: str, source_uuid: str) -> str:
    return str(uuid.uuid5(uuid.UUID(run_id), source_uuid.lower()))


def _t2_smoke_preflight_query(run_id: str) -> str:
    submission_id = _run_owned_uuid(run_id, T2_SMOKE_SUBMISSION_PLACEHOLDER)
    network_hash = hashlib.sha256(
        f"public-intake-hosted-smoke:{submission_id}".encode("utf-8")
    ).hexdigest()
    return (
        "SELECT jsonb_build_object("
        "'two_slot_capacity_headroom',coalesce((SELECT "
        "(SELECT count(*) FROM private.public_intake_submissions q "
        "WHERE q.status='pending' AND q.expires_at>private.public_intake_now()) "
        "+ 1 < s.global_pending_limit FROM private.public_intake_settings s "
        "WHERE s.singleton AND s.global_pending_limit>0),false),"
        "'intake_enabled',coalesce((SELECT enabled FROM private.public_intake_settings "
        "WHERE singleton),false),"
        "'submission_id_unused',NOT EXISTS(SELECT FROM private.public_intake_submissions "
        "WHERE id='" + submission_id + "'::uuid),"
        "'network_hash_unused',NOT EXISTS(SELECT FROM private.public_intake_accepted_events "
        "WHERE network_hash='" + network_hash + "'),"
        "'cleanup_candidates_absent',NOT EXISTS("
        "SELECT FROM private.public_intake_submissions s WHERE s.status='pending' "
        "AND s.expires_at<=private.public_intake_now() UNION ALL "
        "SELECT FROM private.public_intake_receipts r "
        "JOIN private.public_intake_submissions s ON s.id=r.submission_id "
        "WHERE r.expires_at<=private.public_intake_now() AND s.status<>'pending' UNION ALL "
        "SELECT FROM private.public_intake_accepted_events e "
        "WHERE e.accepted_at<=private.public_intake_now()-interval '2 days' UNION ALL "
        "SELECT FROM private.public_intake_decisions d "
        "WHERE d.retained_until<=private.public_intake_now()),"
        "'active_congregation_available',EXISTS(SELECT FROM public.congregations "
        "WHERE archived_at IS NULL))::text;"
    )


def _validate_t2_smoke_preflight(value: object) -> tuple[dict[str, bool], list[str]]:
    fields = {
        "two_slot_capacity_headroom", "intake_enabled", "submission_id_unused",
        "network_hash_unused", "cleanup_candidates_absent", "active_congregation_available",
    }
    if not isinstance(value, dict) or set(value) != fields or any(
            not isinstance(value[name], bool) for name in fields):
        return {}, sorted(fields)
    failed = sorted(name for name in fields if not value[name])
    return value, failed


def _write_blocked_evidence(args: argparse.Namespace, run_id: str, reason: str) -> Path:
    if not PROJECT_REF.fullmatch(args.project_ref):
        raise SafetyError("project ref format is invalid")
    path = _evidence_path(args.evidence_manifest, ROOT)
    _write_evidence(path, {
        "status": "BLOCKED",
        "run_id": run_id,
        "project_ref": args.project_ref,
        "scenario": args.scenario,
        "scenario_sha256": None,
        "target_confirmed": False,
        "hosted_subprocesses_invoked": False,
        "hosted_write_attempted": False,
        "scenario_dispatched": False,
        "reason": reason,
        "cleanup_outcome": "not applicable; no hosted subprocess or write was attempted",
        "started_at": utc_now().isoformat(),
        "completed_at": utc_now().isoformat(),
    })
    return path


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
                        help="request the separately gated hosted concurrency scenario")
    parser.add_argument("--psql-command-json",
                        help=argparse.SUPPRESS)
    parser.add_argument("--supabase-command-json", help=argparse.SUPPRESS)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = _parser()
    args = parser.parse_args(argv)
    try:
        run_id = str(uuid.UUID(args.run_id))
        if run_id != args.run_id.lower():
            raise SafetyError("run id must use canonical UUID syntax")
        if args.concurrency:
            reason = (
                "BLOCKED: the disposable concurrency helper truncates shared queue tables and commits "
                "fixed Auth, access-grant, and official-record fixtures; hosted race cleanup and traffic "
                "isolation are not proven"
            )
            _write_blocked_evidence(args, run_id, reason)
            print("Hosted scenario BLOCKED; no Supabase CLI or psql subprocesses were invoked.", file=sys.stderr)
            return 2
        if args.scenario in T2_HOSTED_BLOCKED_SCENARIOS:
            _write_blocked_evidence(args, run_id, T2_HOSTED_BLOCKED_SCENARIOS[args.scenario])
            print("Hosted T2 capacity scenario BLOCKED; no Supabase CLI or psql subprocesses were invoked.",
                  file=sys.stderr)
            return 2
        backup = validate_backup_manifest(args.backup_manifest, args.project_ref)
        sql, scenario_digest = load_scenario(args.scenario, run_id)
        _confirm_target(args.project_ref, os.environ)
        _verify_account_project(args, os.environ.copy())
        evidence_path = _evidence_path(args.evidence_manifest, ROOT)
        base = _psql_command(args)
        # Keep connection credentials in separate libpq fields, never in argv.
        process_env = _psql_environment(
            os.environ["PUBLIC_INTAKE_DATABASE_URL"], os.environ.copy())

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
        try:
            applied_migrations = json.loads(_psql(
                base, process_env, _migration_ledger_query(args.scenario)))
        except json.JSONDecodeError as exc:
            raise SafetyError("migration ledger response was invalid") from exc
        if not isinstance(applied_migrations, list) or any(
                not isinstance(version, str) for version in applied_migrations):
            raise SafetyError("migration ledger response was incomplete")
        missing_migrations = sorted(set(required_versions) - set(applied_migrations))
        include_intake_schema = (
            args.scenario != "public_registration_authority_test.sql" and not missing_migrations
        )
        baseline_scope = "scenario" if include_intake_schema else "core-only"
        counts_sql = _baseline_query(
            args.scenario, include_intake_schema=include_intake_schema)
        try:
            baseline = json.loads(_psql(base, process_env, counts_sql))
        except json.JSONDecodeError as exc:
            raise SafetyError("baseline state response was invalid") from exc
        if not _validate_snapshot(baseline):
            raise SafetyError("baseline state response was incomplete")
        ownership = None
        if not missing_migrations:
            ownership = run_ownership(sql)
            if not ownership["fixture_ids"]:
                raise SafetyError("run-owned fixture identifiers could not be enumerated")
            if args.scenario != "public_intake_hosted_smoke_test.sql" and (
                    not ownership["auth_user_ids"] or not ownership["operation_receipt_ids"]):
                raise SafetyError("run-owned fixture, Auth, and receipt identifiers could not be enumerated")
        evidence = {
            "status": "STARTED",
            "run_id": run_id,
            "project_ref": args.project_ref,
            "scenario": args.scenario,
            "scenario_sha256": scenario_digest,
            "required_migrations": list(required_versions),
            "applied_migrations": applied_migrations,
            "missing_migrations": missing_migrations,
            "backup_sha256": backup["sha256"],
            "backup_created_at": backup["created_at"],
            "target_confirmed": True,
            "hosted_subprocesses_invoked": True,
            "hosted_write_attempted": False,
            "scenario_dispatched": False,
            "transaction_policy": "scenario explicitly ends in ROLLBACK",
            "baseline": baseline,
            "baseline_scope": baseline_scope,
            "baseline_note": (
                "authority scenario baseline omits the intake feature schema"
                if args.scenario == "public_registration_authority_test.sql" else
                "feature-schema tables/settings/grants were omitted because required migrations are missing"
                if missing_migrations else None
            ),
            "run_ownership": ownership,
            "hosted_preflight": None,
            "after": None,
            "reconciled": False,
            "cleanup_outcome": "pending transaction rollback and reconciliation",
            "started_at": utc_now().isoformat(),
        }
        _write_evidence(evidence_path, evidence)
        if missing_migrations:
            evidence["status"] = "BLOCKED"
            evidence["reason"] = (
                "BLOCKED: required migrations are not confirmed as applied: "
                + ", ".join(missing_migrations)
            )
            evidence["cleanup_outcome"] = "not applicable; scenario was not dispatched and no fixture was created"
            evidence["completed_at"] = utc_now().isoformat()
            _write_evidence(evidence_path, evidence)
            print("Hosted scenario BLOCKED by missing migrations; scenario was not dispatched.",
                  file=sys.stderr)
            return 2
        if args.scenario == "public_intake_hosted_smoke_test.sql":
            try:
                preflight = json.loads(_psql(
                    base, process_env, _t2_smoke_preflight_query(run_id)))
            except (SafetyError, OSError, ValueError, subprocess.TimeoutExpired):
                preflight = {}
            preflight, failed_checks = _validate_t2_smoke_preflight(preflight)
            evidence["hosted_preflight"] = preflight or None
            if failed_checks:
                evidence["status"] = "BLOCKED"
                evidence["reason"] = (
                    "BLOCKED: T2 smoke preflight could not prove " + ", ".join(failed_checks)
                )
                evidence["cleanup_outcome"] = "scenario was not dispatched; no test fixture was created"
                evidence["completed_at"] = utc_now().isoformat()
                _write_evidence(evidence_path, evidence)
                print("Hosted T2 smoke BLOCKED by read-only preflight; scenario was not dispatched.",
                      file=sys.stderr)
                return 2
            evidence["hosted_write_attempted"] = True
            _write_evidence(evidence_path, evidence)
        evidence["scenario_dispatched"] = True
        _write_evidence(evidence_path, evidence)
        try:
            scenario_output = _psql(base, process_env, "SELECT 1;", stdin=sql)
        except (SafetyError, OSError, subprocess.TimeoutExpired):
            try:
                failed_after = json.loads(_psql(base, process_env, counts_sql))
                if _validate_snapshot(failed_after):
                    evidence["after"] = failed_after
                    evidence["reconciled"] = failed_after == baseline
                    evidence["cleanup_outcome"] = (
                        "transaction rollback verified" if evidence["reconciled"]
                        else "count or state mismatch; operator recovery required"
                    )
            except (SafetyError, OSError, ValueError, subprocess.TimeoutExpired):
                evidence["cleanup_outcome"] = "post-failure state unavailable; operator recovery required"
            evidence["status"] = "FAIL"
            evidence["failure"] = "scenario execution failed; raw database output withheld"
            evidence["completed_at"] = utc_now().isoformat()
            _write_evidence(evidence_path, evidence)
            raise SafetyError("scenario execution failed; external evidence was preserved") from None
        if args.scenario == "public_intake_hosted_smoke_test.sql" and scenario_output != "T2_SMOKE_PASS":
            try:
                after = json.loads(_psql(base, process_env, counts_sql))
                evidence["after"] = after
                evidence["reconciled"] = _validate_snapshot(after) and after == baseline
            except (SafetyError, OSError, ValueError, subprocess.TimeoutExpired):
                evidence["cleanup_outcome"] = "post-smoke state unavailable; operator recovery required"
            if isinstance(scenario_output, str) and scenario_output.startswith("T2_SMOKE_BLOCKED:"):
                reason_code = scenario_output.removeprefix("T2_SMOKE_BLOCKED:")
                allowed_block_reasons = {
                    "active_congregation", "lock_timeout", "capacity_full",
                    "intake_paused", "rate_limited", "operation_conflict",
                }
                if reason_code in allowed_block_reasons:
                    evidence["status"] = "BLOCKED"
                    evidence["reason"] = "BLOCKED: T2 smoke runtime guard reported " + reason_code
                else:
                    evidence["status"] = "FAIL"
                    evidence["failure"] = "smoke returned an unrecognized status; raw output withheld"
            else:
                evidence["status"] = "FAIL"
                evidence["failure"] = "smoke did not return its reviewed success marker; raw output withheld"
            if evidence["reconciled"]:
                evidence["cleanup_outcome"] = "transaction rollback verified; no fixture rows remain"
            elif evidence["status"] == "BLOCKED":
                evidence["cleanup_outcome"] = "state did not reconcile after blocked smoke; operator recovery required"
            evidence["completed_at"] = utc_now().isoformat()
            _write_evidence(evidence_path, evidence)
            if evidence["status"] == "BLOCKED" and evidence["reconciled"]:
                print("Hosted T2 smoke BLOCKED by a runtime guard; rollback reconciled and evidence preserved.",
                      file=sys.stderr)
                return 2
            raise SafetyError("T2 smoke did not complete safely; external evidence was preserved") from None
        try:
            after = json.loads(_psql(base, process_env, counts_sql))
        except json.JSONDecodeError as exc:
            evidence["status"] = "FAIL"
            evidence["failure"] = "after-state response was invalid; raw database output withheld"
            evidence["cleanup_outcome"] = "post-run state unavailable; operator recovery required"
            evidence["completed_at"] = utc_now().isoformat()
            _write_evidence(evidence_path, evidence)
            raise SafetyError("after-state response was invalid; external evidence was preserved") from exc
        evidence["after"] = after
        evidence["reconciled"] = _validate_snapshot(after) and after == baseline
        evidence["status"] = "PASS" if evidence["reconciled"] else "FAIL"
        evidence["cleanup_outcome"] = (
            "transaction rollback verified" if evidence["reconciled"]
            else "count or state mismatch; operator recovery required"
        )
        evidence["completed_at"] = utc_now().isoformat()
        _write_evidence(evidence_path, evidence)
        if not evidence["reconciled"]:
            raise SafetyError("before/after state did not reconcile; external evidence was preserved")
        print("Hosted scenario completed; redacted evidence manifest written.")
        return 0
    except (SafetyError, OSError, ValueError, subprocess.TimeoutExpired, EOFError) as exc:
        # Do not expose exception text: parser errors from external tools may
        # contain SQL values, connection strings, or provider response bodies.
        print(f"Hosted scenario refused or failed ({type(exc).__name__}).", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
