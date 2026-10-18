import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[2] / "scripts" / "rehearse_ministry_migration.py"
spec = importlib.util.spec_from_file_location("ministry_rehearsal", SCRIPT)
rehearsal = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rehearsal)


class MinistryRehearsalTest(unittest.TestCase):
    def test_same_legacy_id_in_different_sources_gets_stable_separate_keys(self):
        payload = {
            "records": [
                {"entity": "students", "source_system": "firebase", "source_id": "same", "source_state": "active", "congregation_candidates": ["c-1"]},
                {"entity": "students", "source_system": "base44", "source_id": "same", "source_state": "active", "congregation_candidates": ["c-1"]},
            ]
        }

        first = rehearsal.build_report(payload)
        second = rehearsal.build_report(payload)

        self.assertEqual(first, second)
        rows = first["rows"]
        self.assertNotEqual(rows[0]["source_key"], rows[1]["source_key"])
        self.assertNotEqual(rows[0]["target_id"], rows[1]["target_id"])

    def test_ambiguous_matches_are_quarantined_and_states_are_reconciled(self):
        payload = {
            "records": [
                {"entity": "students", "source_system": "firebase", "source_id": "a", "source_state": "archived", "congregation_candidates": ["c-1", "c-2"]},
                {"entity": "enrollments", "source_system": "base44", "source_id": "e", "source_state": "completed", "congregation_candidates": ["c-1"], "existing_student_candidates": ["s-1", "s-2"]},
                {"entity": "links", "source_system": "firebase", "source_id": "l", "source_state": "active", "congregation_candidates": ["c-1"], "existing_student_candidates": ["s-1"]},
            ]
        }

        report = rehearsal.build_report(payload)

        statuses = {row["entity"]: row["status"] for row in report["rows"]}
        self.assertEqual(statuses, {"students": "review", "enrollments": "review", "links": "ready"})
        self.assertEqual(
            {key: report["reconciliation"]["source_counts"][key] for key in statuses},
            {"students": 1, "enrollments": 1, "links": 1},
        )
        self.assertEqual(report["reconciliation"]["source_counts"], report["reconciliation"]["mapped_counts"])
        self.assertEqual(report["reconciliation"]["source_states"], report["reconciliation"]["mapped_states"])

    def test_duplicate_source_keys_fail_closed(self):
        record = {"entity": "students", "source_system": "firebase", "source_id": "duplicate", "source_state": "active", "congregation_candidates": ["c-1"]}
        with self.assertRaisesRegex(ValueError, "duplicate source key"):
            rehearsal.build_report({"records": [record, record]})

    def test_cli_writes_a_deterministic_json_report(self):
        payload = {"records": [{"entity": "converts", "source_system": "firebase", "source_id": "c1", "source_state": "completed", "congregation_candidates": []}]}
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "input.json"
            output = Path(directory) / "report.json"
            source.write_text(json.dumps(payload), encoding="utf-8")

            status = rehearsal.run_cli(["--input", str(source), "--output", str(output)])
            first = output.read_bytes()
            status_again = rehearsal.run_cli(["--input", str(source), "--output", str(output)])

            self.assertEqual(status, 0)
            self.assertEqual(status_again, 0)
            self.assertEqual(output.read_bytes(), first)
            report = json.loads(first)
            self.assertEqual(report["rows"][0]["status"], "review")
            self.assertEqual(report["rows"][0]["review_reason"], "congregation_unmatched")


if __name__ == "__main__":
    unittest.main()
