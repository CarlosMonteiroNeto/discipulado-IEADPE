import importlib.util
import json
import pathlib
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).parents[2] / "scripts" / "build_base44_import_sql.py"
spec = importlib.util.spec_from_file_location("base44_import", SCRIPT)
base44_import = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base44_import)


def backup():
    metadata = {"created_by_id": None, "created_by": None, "updated_date": "2024-01-01T10:00:00Z", "is_sample": False}
    congregation = {**metadata, "id": "cong-a", "name": "Congregação A", "created_date": "2024-01-01T10:00:00Z"}
    convert = {
        "id": "convert-a", "name": " Pessoa Exemplo ", "landmark": " Praça ", "gender": "female",
        "conversion_date": "2024-01-01", "worship_type": "Oração", "congregation_id": "cong-a",
        **metadata, "created_date": "2024-01-01T10:00:00Z", "updated_date": "2024-01-02T10:00:00Z",
        "was_visited_once": False, "visit_count": 0, "is_in_discipleship": False,
        "is_discipleship_completed": False, "is_deviated": False, "is_sample": False,
    }
    return {
        "format": "ieadpe-converts-full-backup", "format_version": 1, "completed": True,
        "data": {
            "Congregation": [congregation], "Convert": [convert],
            "ConvertEvent": [
                {**metadata, "id": "event-linked", "convert_id": "convert-a", "congregation_id": "cong-a", "convert_name": "Pessoa Exemplo", "event_type": "visit", "event_date": "2024-01-02", "created_date": "2024-01-02T10:00:00Z"},
                {**metadata, "id": "event-orphan", "convert_id": "deleted-convert", "congregation_id": "cong-a", "convert_name": "Pessoa removida", "event_type": "visit", "event_date": "2024-01-03", "created_date": "2024-01-03T10:00:00Z"},
            ],
            "WeeklyReport": [{**metadata, "id": "week-a", "congregation_id": "cong-a", "week_start": "2024-01-01", "confirmed_by_email": "reviewer@example.test", "created_date": "2024-01-08T10:00:00Z"}],
            "UserAccess": [{**metadata, "id": "access-a", "user_email": "pending@example.test", "role": "Membro da direção da campanha", "congregation_id": "cong-a", "created_date": "2024-01-01T10:00:00Z"}],
            "Feedback": [],
        },
    }


class Base44ImportSqlTests(unittest.TestCase):
    def test_builds_transactional_import_preserving_orphans_and_staging_access(self):
        with tempfile.TemporaryDirectory() as directory:
            source = pathlib.Path(directory) / "backup.json"
            output = pathlib.Path(directory) / "import.sql"
            source.write_text(json.dumps(backup(), ensure_ascii=False), encoding="utf-8")

            summary = base44_import.build(source, output)
            sql = output.read_text(encoding="utf-8")

        self.assertEqual(summary["records"], 6)
        self.assertEqual(summary["orphan_events"], 1)
        self.assertTrue(sql.startswith("BEGIN;"))
        self.assertTrue(sql.rstrip().endswith("COMMIT;"))
        self.assertIn("private.base44_user_access_pending", sql)
        self.assertNotIn("INSERT INTO public.user_access", sql)
        self.assertIn("legacy_convert_id", sql)
        self.assertIn("event-orphan", sql)
        self.assertIn("btrim(r->>'name')", sql)
        self.assertIn("btrim(r->>'landmark')", sql)
        self.assertIn("INSERT INTO private.base44_feedback_archive", sql)
        self.assertIn("expected_counts->>'Feedback'", sql)
        self.assertIn("INSERT INTO private.congregation_week_guards", sql)
        self.assertEqual(
            summary["normalizations"],
            {"congregation_name": 0, "convert_name": 1, "landmark": 1, "worship_type": 0},
        )

    def test_archives_nonempty_feedback_rows(self):
        value = backup()
        value["data"]["Feedback"] = [
            {
                "id": "feedback-a",
                "message": "Synthetic feedback",
                "user_email": "reviewer@example.test",
                "user_name": "Synthetic reviewer",
                "status": "pending",
                "created_by_id": None,
                "created_by": None,
                "created_date": "2024-01-04T10:00:00Z",
                "updated_date": "2024-01-04T10:00:00Z",
                "is_sample": False,
            }
        ]
        with tempfile.TemporaryDirectory() as directory:
            source = pathlib.Path(directory) / "backup.json"
            output = pathlib.Path(directory) / "import.sql"
            source.write_text(json.dumps(value, ensure_ascii=False), encoding="utf-8")

            summary = base44_import.build(source, output)
            sql = output.read_text(encoding="utf-8")

        self.assertEqual(summary["counts"]["Feedback"], 1)
        self.assertIn("INSERT INTO private.base44_feedback_archive", sql)
        self.assertIn("jsonb_array_elements(backup->'data'->'Feedback')", sql)
        self.assertIn("expected_counts->>'Feedback'", sql)
        self.assertIn("feedback-a", sql)

    def test_import_seeds_weekly_guards_from_converted_rows(self):
        with tempfile.TemporaryDirectory() as directory:
            source = pathlib.Path(directory) / "backup.json"
            output = pathlib.Path(directory) / "import.sql"
            source.write_text(json.dumps(backup(), ensure_ascii=False), encoding="utf-8")

            base44_import.build(source, output)
            sql = output.read_text(encoding="utf-8")

        self.assertIn("INSERT INTO private.congregation_week_guards", sql)
        self.assertIn("WITH affected_weeks AS", sql)
        self.assertIn("ON CONFLICT(congregation_id,week_start) DO UPDATE", sql)

    def test_rejects_incomplete_or_ambiguous_backup_before_creating_sql(self):
        with tempfile.TemporaryDirectory() as directory:
            source = pathlib.Path(directory) / "backup.json"
            output = pathlib.Path(directory) / "import.sql"
            value = backup()
            value["completed"] = False
            source.write_text(json.dumps(value), encoding="utf-8")

            with self.assertRaisesRegex(ValueError, "incomplete"):
                base44_import.build(source, output)

            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
