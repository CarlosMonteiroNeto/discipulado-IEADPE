"""Prepare or locally rehearse the exact corrective migration sequence.

This tool has no hosted mode. Any supplied PostgreSQL URL must point to loopback,
and an actual run is delegated to the repository's disposable database harness.
"""
import argparse
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import subprocess
import sys
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
MIGRATIONS = ROOT / "supabase" / "migrations"
PREFIXES = ("202610180003", "20261019", "20261020")
TARGET = "voqmtnqjrbugpazcimvh"


def migration_sequence():
    files = sorted(p for p in MIGRATIONS.glob("*.sql") if p.name.startswith(PREFIXES))
    expected = ["202610180003", *(f"20261019{i:04d}" for i in range(1, 10)),
                *(f"20261020{i:04d}" for i in range(1, 7))]
    if [p.name[:12] for p in files] != expected:
        raise ValueError("migration sequence is incomplete or has unexpected files")
    return [{"version": p.name[:12], "filename": p.name,
             "sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p in files]


def require_catalog_fingerprint_match(expected, observed):
    if not expected or not observed or expected != observed:
        raise ValueError("catalog drift detected before migration resume")
    return True


def build_migration_resume_plan(expected_migrations, applied_ledger):
    versions = [item["version"] for item in expected_migrations]
    if len(versions) != len(set(versions)):
        raise ValueError("duplicate migration version")
    pending = []
    gap = False
    for migration in expected_migrations:
        version = migration["version"]
        expected_hash = migration["sha256"]
        if version not in applied_ledger:
            gap = True
            pending.append(migration)
            continue
        if gap:
            raise ValueError("migration ledger gap before a recorded version")
        if applied_ledger[version] != expected_hash:
            raise ValueError(f"migration checksum drift at {version}")
    unknown = set(applied_ledger) - set(versions)
    if unknown:
        raise ValueError("migration ledger contains versions outside the ordered plan")
    return pending


def build_local_rehearsal_command(database_url, output_path):
    safe_url = require_loopback(database_url)
    if not output_path:
        raise ValueError("local rehearsal report path is required")
    snapshots_path = ROOT / "build/verification/corrective-release/T12/semantic-snapshots.json"
    return [sys.executable, str(ROOT / "scripts" / "test_database.py"),
            "t12_post_forward_rehearsal.sql",
            "--seed-before-migration", "202610180002_base44_archive_weekly_consistency.sql",
            "--seed-scenario", "t12_pre_180002_rehearsal.sql",
            "--verify-after-migration", "202610180002_base44_archive_weekly_consistency.sql",
            "--verification-scenario", "t12_post_180002_baseline.sql",
            "--t12-resume-and-drift", "--t12-semantic-snapshots", str(snapshots_path)]


def build_candidate_provenance(paths=None):
    if paths is None:
        status = subprocess.run(["git", "status", "--porcelain=v1", "-z"], cwd=ROOT,
                                capture_output=True, check=True).stdout.decode("utf-8", "surrogateescape")
        paths = []
        for record in status.split("\0"):
            if len(record) >= 4:
                paths.append(ROOT / record[3:])
    entries = {}
    expanded = set()
    for item in paths:
        path = Path(item).resolve()
        if path.is_dir():
            expanded.update(child for child in path.rglob("*") if child.is_file())
        else:
            expanded.add(path)
    for path in sorted(expanded):
        try:
            relative = path.relative_to(ROOT).as_posix()
        except ValueError:
            raise ValueError("candidate path escapes repository")
        try:
            current_digest = hashlib.sha256(path.read_bytes()).hexdigest()
        except FileNotFoundError:
            current_digest = None
        base = subprocess.run(["git", "show", f"HEAD:{relative}"], cwd=ROOT,
                              capture_output=True)
        base_digest = hashlib.sha256(base.stdout).hexdigest() if base.returncode == 0 else None
        if relative == "docs/verification/ministry-corrective-activation-package.md":
            # The package cannot hash itself; the final report hashes the package after generation.
            continue
        entries[relative] = {"sha256": current_digest, "head_sha256": base_digest,
                             "working_tree": current_digest != base_digest}
    candidate_hash = hashlib.sha256()
    for relative, entry in sorted(entries.items()):
        candidate_hash.update(relative.encode())
        candidate_hash.update(b"\0")
        candidate_hash.update((entry["sha256"] or "DELETED").encode())
        candidate_hash.update(b"\n")
    return {"head": subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT,
                                    text=True, capture_output=True, check=True).stdout.strip(),
            "candidate_sha256": candidate_hash.hexdigest(), "files": entries}


def build_plan():
    sequence = migration_sequence()
    prefix_ledger = {item["version"]: item["sha256"] for item in sequence[:2]}
    resume_pending = build_migration_resume_plan(sequence, prefix_ledger)
    drift_rejected = False
    poisoned = dict(prefix_ledger)
    poisoned[sequence[1]["version"]] = "0" * 64
    try:
        build_migration_resume_plan(sequence, poisoned)
    except ValueError as exc:
        drift_rejected = "drift" in str(exc)
    candidate = build_candidate_provenance()
    return {
        "task_id": 12, "target_project_ref": TARGET,
        "source_sha": candidate["head"], "candidate_provenance": candidate,
        "migration_sequence": sequence,
        "resume_drift_rehearsal": {"partial_prefix_count": len(prefix_ledger),
            "pending_versions": [item["version"] for item in resume_pending],
            "checksum_drift_stopped": drift_rejected, "ledger_repair_performed": False},
        "baseline": {"last_schema_migration": "202610180002", "ledger_through": "202610140018",
                     "synthetic_only": True},
        "ledger_repair_proposal": {"review_required": True, "versions": ["202610180001", "202610180002"],
            "requires_full_equivalence": True,
            "guard_reconciliation": "independent proof required before any future repair",
            "proposal_only": True},
        "hosted_effects": {"inventory_performed": False, "migration_applied": False,
                            "ledger_repaired": False},
        "backup_restore": {"status": "BLOCKED", "required": True,
            "checks": ["encrypted database backup", "Storage inventory/backup", "isolated restore",
                       "counts/constraints/links/object access", "retained digest and recovery procedure"]},
        "historical_snapshot_to_recheck": {"converts": 51, "congregations": 24,
            "access_assignments": 30, "admin_users": 1, "active_ministry_grants": 0,
            "current_academic_records": 0, "authoritative_for_cutover": False},
        "compatibility": {"old_client_write_pause_required": True, "status": "INCOMPLETE",
            "write_pause_plan": "pause incompatible old-client writes before envelope changes; confirm by real operator sessions",
            "monitoring": ["authorization denials", "RPC/schema errors", "row/link reconciliation",
                           "backup/restore status", "provider quota/capacity alerts"],
            "rollback_stop_conditions": ["unknown target or schema drift", "failed restore",
                "authorization regression", "count/link mismatch", "old-client writes not paused",
                "new security/integrity failure"],
            "rollback_procedure": "stop target writes, retain sources, restore only to an isolated destination, reconcile counts/constraints/links/object access, and retry only after the cause is understood"},
        "legacy_firebase": {"status": "BLOCKED", "reason": "source export or verified absence unavailable"},
        "android_artifact": {"status": "BLOCKED", "reason": "installed artifact/device evidence unavailable"},
        "effects": {"migrations_applied": False, "ledger_repaired": False},
    }


def require_loopback(database_url):
    parsed = urlparse(database_url)
    if parsed.scheme not in ("postgres", "postgresql") or parsed.query or parsed.fragment:
        raise ValueError("rehearsal requires a simple PostgreSQL URL without libpq overrides")
    if parsed.password is not None:
        raise ValueError("do not embed a password in the local rehearsal URL")
    hostname = parsed.hostname
    if hostname is None:
        raise ValueError("database URL must specify an explicit loopback host")
    if hostname.lower() == "localhost":
        address = ipaddress.ip_address("127.0.0.1")
    else:
        try:
            address = ipaddress.ip_address(hostname)
        except ValueError as exc:
            raise ValueError("only literal loopback IPs or localhost are permitted") from exc
    if not address.is_loopback:
        raise ValueError("refusing non-loopback target; rehearsal requires local disposable PostgreSQL")
    port = parsed.port or 5432
    if not 1 <= port <= 65535:
        raise ValueError("database port is invalid")
    userinfo = parsed.netloc.rsplit("@", 1)[0] + "@" if "@" in parsed.netloc else ""
    authority_host = f"[{address.compressed}]" if address.version == 6 else address.compressed
    path = parsed.path or "/postgres"
    return f"{parsed.scheme}://{userinfo}{authority_host}:{port}{path}"


def sanitize_libpq_environment(database_url, environ=None):
    """Remove every inherited libpq variable and force the parsed loopback URL."""
    safe_url = require_loopback(database_url)
    source = os.environ if environ is None else environ
    sanitized = {key: value for key, value in source.items() if not key.upper().startswith("PG")}
    sanitized["IEADPE_DATABASE_URL"] = safe_url
    return sanitized


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database-url", help="local disposable PostgreSQL URL; loopback only")
    parser.add_argument("--plan-only", action="store_true", help="write the review package without database access")
    parser.add_argument("--output", required=True)
    parser.add_argument("--log-output", help="raw output path for local harness evidence")
    args = parser.parse_args()
    if args.database_url:
        safe_environment = sanitize_libpq_environment(args.database_url)
    elif not args.plan_only:
        parser.error("choose --plan-only or provide --database-url; hosted targets are never a default")
    report = build_plan()
    if args.database_url:
        env = safe_environment
        command = build_local_rehearsal_command(args.database_url, args.output)
        result = subprocess.run(command, cwd=ROOT, env=env, text=True, capture_output=True, timeout=900)
        log_path = Path(args.log_output).resolve() if args.log_output else Path(args.output).resolve().with_suffix(".log")
        log_path.parent.mkdir(parents=True, exist_ok=True)
        log_text = result.stdout + result.stderr
        log_path.write_text(log_text, encoding="utf-8")
        report["local_rehearsal"] = {"exit_code": result.returncode,
            "harness": "scripts/test_database.py", "completed": result.returncode == 0,
            "evidence_path": str(log_path), "evidence_sha256": hashlib.sha256(log_text.encode()).hexdigest()}
        if result.returncode:
            raise RuntimeError("disposable local migration harness failed; caller captured stderr")
        snapshots_path = ROOT / "build/verification/corrective-release/T12/semantic-snapshots.json"
        from migration_semantic_manifest import build_manifest_from_snapshot_file
        manifest = build_manifest_from_snapshot_file(snapshots_path)
        manifest_path = snapshots_path.with_name("semantic-manifest.json")
        manifest_text = json.dumps(manifest, indent=2) + "\n"
        manifest_path.write_text(manifest_text, encoding="utf-8")
        report["local_rehearsal"].update({
            "baseline": "synthetic seed staged after 202610180001, before 202610180002",
            "ledger_through": "202610140018",
            "blind_base44_ddl_replay_failed_as_expected": "CREATE TABLE duplicate caught by assertion",
            "synthetic_equivalence_checks": "passed",
            "weekly_guard_reconciliation": "passed",
            "post_180002_baseline_assertions": "passed before the forward chain",
            "database_partial_resume": "passed after controlled stop at 202610190001; remaining exact chain applied",
            "database_catalog_drift": "detected on ministry_people and stopped before 202610190002; synthetic DDL rolled back",
            "ledger_repair_executed": False,
            "semantic_snapshot_count": len(manifest["versions"]),
            "semantic_manifest_path": str(manifest_path),
            "semantic_manifest_sha256": hashlib.sha256(manifest_text.encode()).hexdigest(),
        })
        report["resume_drift_rehearsal"].update({
            "database_partial_resume_verified": True,
            "database_catalog_drift_stopped_before": "202610190002",
            "synthetic_drift_rolled_back": True,
        })
        report["ledger_repair_proposal"].update({
            "synthetic_equivalence_proven": True,
            "synthetic_guard_reconciliation_proven": True,
            "hosted_equivalence_proven": False,
            "proposal_ready_for_hosted_repair": False,
        })
    output = Path(args.output).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote local-only preparation report: {output}")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, RuntimeError) as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(2)
