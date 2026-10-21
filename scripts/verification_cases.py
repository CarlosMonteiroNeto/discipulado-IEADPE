"""Validate and emit the platform-neutral argv cases for unified verification."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = Path(__file__).with_name("verification_cases.json")
DEFAULT_DATABASE = ROOT / "supabase/tests/database"
DEFAULT_MIGRATIONS = ROOT / "supabase/migrations"
REQUIRED_SEEDS = {
    "canonical_person_link_test.sql": (
        "202610200002_canonical_handoff_reads.sql",
        "canonical_person_link_test.sql",
    ),
    "ministry_session_management_test.sql": (
        "202610190009_ministry_session_management.sql",
        "ministry_session_management_test.sql",
    ),
}
REQUIRED_RACES = {
    "--catalog-concurrency", "--access-concurrency", "--convert-concurrency",
    "--import-concurrency", "--lifecycle-concurrency",
    "--ministry-registry-concurrency", "--ministry-academic-concurrency",
    "--convert-student-concurrency", "--ministry-follow-up-concurrency",
}


class ManifestError(ValueError):
    """The checked-in verification manifest cannot safely describe the suite."""


def _unique_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
    result: dict[str, object] = {}
    for key, value in pairs:
        if key in result:
            raise ManifestError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _load_json(path: Path) -> dict[str, object]:
    try:
        with path.open(encoding="utf-8") as stream:
            value = json.load(stream, object_pairs_hook=_unique_object)
    except FileNotFoundError as error:
        raise ManifestError(f"manifest file is missing: {path}") from error
    except json.JSONDecodeError as error:
        raise ManifestError(f"manifest JSON is invalid: {error}") from error
    if not isinstance(value, dict):
        raise ManifestError("manifest root must be an object")
    return value


def _safe_sql_name(value: object, field: str) -> str:
    if not isinstance(value, str) or not re.fullmatch(r"[a-z0-9_]+_test\.sql", value):
        raise ManifestError(f"{field} must be a contained *_test.sql basename")
    return value


def validate_manifest(
    manifest_path: Path = DEFAULT_MANIFEST,
    database_dir: Path = DEFAULT_DATABASE,
    migrations_dir: Path = DEFAULT_MIGRATIONS,
) -> dict[str, object]:
    """Return validated data, failing on stale coverage, unsafe paths, or bad order."""
    data = _load_json(manifest_path)
    if set(data) != {"version", "sql", "concurrency"} or data.get("version") != 1:
        raise ManifestError("manifest must contain only version 1, sql, and concurrency")
    sql = data.get("sql")
    concurrency = data.get("concurrency")
    if not isinstance(sql, list) or not isinstance(concurrency, list):
        raise ManifestError("manifest sql and concurrency entries must be arrays")

    migrations = sorted(path.name for path in migrations_dir.glob("*.sql"))
    actual_scenarios = {path.name for path in database_dir.glob("*_test.sql")}
    scenarios: list[str] = []
    for index, entry in enumerate(sql):
        if not isinstance(entry, dict):
            raise ManifestError(f"sql entry {index} must be an object")
        if not set(entry).issubset({"scenario", "seed_before_migration", "seed_scenario"}):
            raise ManifestError(f"sql entry {index} has unknown fields")
        scenario = _safe_sql_name(entry.get("scenario"), f"sql entry {index} scenario")
        scenarios.append(scenario)
        if ("seed_before_migration" in entry) != ("seed_scenario" in entry):
            raise ManifestError(f"{scenario} seed migration and seed scenario must be paired")
        if "seed_before_migration" in entry:
            target = entry["seed_before_migration"]
            seed = _safe_sql_name(entry["seed_scenario"], f"{scenario} seed scenario")
            if not isinstance(target, str) or not re.fullmatch(r"[0-9]{12}_[a-z0-9_]+\.sql", target):
                raise ManifestError(f"{scenario} seed target must be a migration basename")
            if target not in migrations:
                raise ManifestError(f"{scenario} seed target is not an existing migration: {target}")
            if seed not in actual_scenarios:
                raise ManifestError(f"{scenario} seed scenario does not exist: {seed}")
            if migrations.index(target) == 0:
                raise ManifestError(f"{scenario} seed target has no preceding migration")
        if scenario not in actual_scenarios:
            raise ManifestError(f"scenario is missing or unsafe: {scenario}")
    if len(scenarios) != len(set(scenarios)):
        raise ManifestError("duplicate SQL scenario entry")
    if set(scenarios) != actual_scenarios:
        missing = sorted(actual_scenarios - set(scenarios))
        stale = sorted(set(scenarios) - actual_scenarios)
        raise ManifestError(f"SQL scenario coverage mismatch; missing={missing}, stale={stale}")

    by_name = {entry["scenario"]: entry for entry in sql}
    for scenario, (target, seed) in REQUIRED_SEEDS.items():
        entry = by_name.get(scenario)
        if not entry or entry.get("seed_before_migration") != target or entry.get("seed_scenario") != seed:
            raise ManifestError(f"{scenario} requires pre-migration seed {seed} immediately before {target}")

    flags: list[str] = []
    for index, entry in enumerate(concurrency):
        if not isinstance(entry, dict) or set(entry) != {"flag"}:
            raise ManifestError(f"concurrency entry {index} must contain only flag")
        flag = entry["flag"]
        if not isinstance(flag, str) or not re.fullmatch(r"--[a-z0-9]+(?:-[a-z0-9]+)*-concurrency", flag):
            raise ManifestError(f"concurrency entry {index} has an invalid flag")
        flags.append(flag)
    if len(flags) != len(set(flags)):
        raise ManifestError("duplicate concurrency flag")
    if set(flags) != REQUIRED_RACES:
        raise ManifestError(f"concurrency coverage mismatch; expected {sorted(REQUIRED_RACES)}, got {sorted(flags)}")
    return data


def build_cases(data: dict[str, object]) -> dict[str, list[dict[str, object]]]:
    sql_cases = []
    for entry in data["sql"]:
        argv = [entry["scenario"]]
        if "seed_before_migration" in entry:
            argv.extend(("--seed-before-migration", entry["seed_before_migration"],
                         "--seed-scenario", entry["seed_scenario"]))
        sql_cases.append({"name": entry["scenario"], "argv": argv})
    races = [{"name": entry["flag"], "flag": entry["flag"], "argv": [entry["flag"]]}
             for entry in data["concurrency"]]
    return {"sql": sql_cases, "concurrency": races}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--database-dir", type=Path, default=DEFAULT_DATABASE)
    parser.add_argument("--migrations-dir", type=Path, default=DEFAULT_MIGRATIONS)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--validate", action="store_true")
    mode.add_argument("--cases-json", action="store_true")
    mode.add_argument("--cases-lines", action="store_true")
    args = parser.parse_args(argv)
    try:
        data = validate_manifest(args.manifest, args.database_dir, args.migrations_dir)
        if args.cases_json:
            print(json.dumps(build_cases(data), sort_keys=True))
        elif args.cases_lines:
            cases = build_cases(data)
            for case in cases["sql"]:
                print("\t".join(["sql", case["name"], *case["argv"]]))
            for case in cases["concurrency"]:
                print("\t".join(["concurrency", case["name"], *case["argv"]]))
        else:
            print(f"PASS: {len(data['sql'])} SQL scenarios and {len(data['concurrency'])} concurrency cases validated")
    except (ManifestError, OSError) as error:
        print(f"FAIL: verification manifest: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
