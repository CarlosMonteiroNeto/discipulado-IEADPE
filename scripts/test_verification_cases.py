"""Behavioral contract for the shared, fail-closed verification manifest."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "scripts" / "verification_cases.py"
MANIFEST = ROOT / "scripts" / "verification_cases.json"
DATABASE = ROOT / "supabase" / "tests" / "database"
MIGRATIONS = ROOT / "supabase" / "migrations"


def validate(manifest: Path = MANIFEST, database: Path = DATABASE,
             migrations: Path = MIGRATIONS) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(TOOL), "--validate", "--manifest", str(manifest),
         "--database-dir", str(database), "--migrations-dir", str(migrations)],
        cwd=ROOT, text=True, capture_output=True, check=False,
    )


class VerificationManifestTests(unittest.TestCase):
    def test_manifest_covers_each_standalone_scenario_and_required_seeds(self) -> None:
        result = validate()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        data = json.loads(MANIFEST.read_text(encoding="utf-8"))
        entries = data["sql"]
        scenarios = [entry["scenario"] for entry in entries]
        expected = sorted(path.name for path in DATABASE.glob("*_test.sql"))
        self.assertEqual(sorted(scenarios), expected)
        self.assertEqual(len(scenarios), len(set(scenarios)))
        by_scenario = {entry["scenario"]: entry for entry in entries}
        self.assertEqual(by_scenario["canonical_person_link_test.sql"], {
            "scenario": "canonical_person_link_test.sql",
            "seed_before_migration": "202610200002_canonical_handoff_reads.sql",
            "seed_scenario": "canonical_person_link_test.sql",
        })
        self.assertEqual(by_scenario["ministry_session_management_test.sql"], {
            "scenario": "ministry_session_management_test.sql",
            "seed_before_migration": "202610190009_ministry_session_management.sql",
            "seed_scenario": "ministry_session_management_test.sql",
        })

    def test_generated_argv_preserves_seed_order_and_all_ten_races(self) -> None:
        result = subprocess.run(
            [sys.executable, str(TOOL), "--cases-json"], cwd=ROOT,
            text=True, capture_output=True, check=False,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        cases = json.loads(result.stdout)
        sql = {case["name"]: case["argv"] for case in cases["sql"]}
        self.assertEqual(sql["canonical_person_link_test.sql"], [
            "canonical_person_link_test.sql", "--seed-before-migration",
            "202610200002_canonical_handoff_reads.sql", "--seed-scenario",
            "canonical_person_link_test.sql",
        ])
        self.assertEqual(sql["ministry_session_management_test.sql"], [
            "ministry_session_management_test.sql", "--seed-before-migration",
            "202610190009_ministry_session_management.sql", "--seed-scenario",
            "ministry_session_management_test.sql",
        ])
        races = {case["flag"] for case in cases["concurrency"]}
        self.assertEqual(races, {
            "--catalog-concurrency", "--access-concurrency", "--convert-concurrency",
            "--import-concurrency", "--lifecycle-concurrency",
            "--ministry-registry-concurrency", "--ministry-academic-concurrency",
            "--convert-student-concurrency", "--ministry-follow-up-concurrency",
            "--public-intake-concurrency",
        })

    def test_generated_case_lines_use_lf_without_carriage_returns(self) -> None:
        result = subprocess.run(
            [sys.executable, str(TOOL), "--cases-lines"], cwd=ROOT,
            capture_output=True, check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr.decode("utf-8"))
        self.assertNotIn(b"\r", result.stdout)
        lines = result.stdout.decode("utf-8").splitlines()
        expected_count = len(json.loads(MANIFEST.read_text(encoding="utf-8"))["sql"]) + 10
        self.assertEqual(len(lines), expected_count)
        canonical = next(line for line in lines if line.startswith("sql\tcanonical_person_link_test.sql\t"))
        self.assertEqual(canonical.split("\t")[2:], [
            "canonical_person_link_test.sql", "--seed-before-migration",
            "202610200002_canonical_handoff_reads.sql", "--seed-scenario",
            "canonical_person_link_test.sql",
        ])

    def test_missing_manifest_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            result = validate(Path(directory) / "missing.json")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("manifest", (result.stdout + result.stderr).lower())

    def test_duplicate_scenario_fails_validation(self) -> None:
        data = json.loads(MANIFEST.read_text(encoding="utf-8"))
        data["sql"].append(dict(data["sql"][0]))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "manifest.json"
            path.write_text(json.dumps(data), encoding="utf-8")
            result = validate(path)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("duplicate", (result.stdout + result.stderr).lower())

    def test_unlisted_standalone_scenario_fails_coverage(self) -> None:
        data = json.loads(MANIFEST.read_text(encoding="utf-8"))
        with tempfile.TemporaryDirectory() as directory:
            database = Path(directory) / "database"
            database.mkdir()
            for source in DATABASE.glob("*_test.sql"):
                (database / source.name).touch()
            (database / "new_acceptance_test.sql").touch()
            path = Path(directory) / "manifest.json"
            path.write_text(json.dumps(data), encoding="utf-8")
            result = validate(path, database)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("new_acceptance_test.sql", result.stdout + result.stderr)

    def test_path_traversal_is_rejected(self) -> None:
        data = json.loads(MANIFEST.read_text(encoding="utf-8"))
        data["sql"][0]["scenario"] = "../outside_test.sql"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "manifest.json"
            path.write_text(json.dumps(data), encoding="utf-8")
            result = validate(path)
        self.assertNotEqual(result.returncode, 0)
        self.assertRegex((result.stdout + result.stderr).lower(), "path|scenario")

    def test_wrong_seed_target_and_order_are_rejected(self) -> None:
        for field, value in (
            ("seed_before_migration", "999999999999_wrong.sql"),
            ("seed_before_migration", "202610190009_ministry_session_management.sql"),
            ("seed_scenario", "attendance_integrity_test.sql"),
        ):
            with self.subTest(field=field, value=value):
                data = json.loads(MANIFEST.read_text(encoding="utf-8"))
                target = next(row for row in data["sql"] if row["scenario"] == "canonical_person_link_test.sql")
                target[field] = value
                with tempfile.TemporaryDirectory() as directory:
                    path = Path(directory) / "manifest.json"
                    path.write_text(json.dumps(data), encoding="utf-8")
                    result = validate(path)
                self.assertNotEqual(result.returncode, 0)

    def test_race_omission_is_rejected(self) -> None:
        data = json.loads(MANIFEST.read_text(encoding="utf-8"))
        data["concurrency"].pop()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "manifest.json"
            path.write_text(json.dumps(data), encoding="utf-8")
            result = validate(path)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("concurrency", (result.stdout + result.stderr).lower())


if __name__ == "__main__":
    unittest.main()
