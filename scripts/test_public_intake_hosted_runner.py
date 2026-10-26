"""Offline safety tests for the hosted public-intake runner."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import test_public_intake_hosted as runner


class HostedRunnerSafetyTests(unittest.TestCase):
    def make_backup(self, directory: Path, project_ref: str = "abcdefghijklmnopqrst") -> Path:
        archive = directory / "fresh.dump"
        archive.write_bytes(b"verified fake archive")
        manifest = directory / "backup-manifest.json"
        manifest.write_text(json.dumps({
            "project_ref": project_ref,
            "created_at": runner.utc_now().isoformat(),
            "archive_path": str(archive),
            "sha256": hashlib.sha256(archive.read_bytes()).hexdigest(),
            "full_backup": True,
            "archive_readable": True,
            "restore_path_verified": "isolated native restore target",
        }), encoding="utf-8")
        return manifest

    def test_missing_and_wrong_project_backup_manifests_fail_closed(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            manifest = self.make_backup(directory)
            with self.assertRaises(runner.SafetyError):
                runner.validate_backup_manifest(None, "abcdefghijklmnopqrst", ROOT)
            with self.assertRaises(runner.SafetyError):
                runner.validate_backup_manifest(manifest, "zzzzzzzzzzzzzzzzzzzz", ROOT)

    def test_stale_tampered_and_repository_backups_fail_closed(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            manifest = self.make_backup(directory)
            value = json.loads(manifest.read_text(encoding="utf-8"))
            value["created_at"] = "2020-01-01T00:00:00+00:00"
            manifest.write_text(json.dumps(value), encoding="utf-8")
            with self.assertRaises(runner.SafetyError):
                runner.validate_backup_manifest(manifest, "abcdefghijklmnopqrst", ROOT)
            manifest = self.make_backup(directory)
            (directory / "fresh.dump").write_bytes(b"tampered")
            with self.assertRaises(runner.SafetyError):
                runner.validate_backup_manifest(manifest, "abcdefghijklmnopqrst", ROOT)
            with self.assertRaises(runner.SafetyError):
                runner.validate_backup_manifest(ROOT / "README.md", "abcdefghijklmnopqrst", ROOT)
            manifest = self.make_backup(directory)
            value = json.loads(manifest.read_text(encoding="utf-8"))
            value["full_backup"] = False
            manifest.write_text(json.dumps(value), encoding="utf-8")
            with self.assertRaises(runner.SafetyError):
                runner.validate_backup_manifest(manifest, "abcdefghijklmnopqrst", ROOT)

    def test_only_allowlisted_exact_scenarios_with_transactional_sql_are_accepted(self):
        with self.assertRaises(runner.SafetyError):
            runner.load_scenario("../public_intake_test.sql", str(uuid.uuid4()), ROOT)
        with tempfile.TemporaryDirectory() as temp:
            bad = Path(temp) / "public_registration_authority_test.sql"
            bad.write_text("BEGIN; DROP SCHEMA public CASCADE; ROLLBACK;", encoding="utf-8")
            with self.assertRaises(runner.SafetyError):
                runner.validate_scenario_sql(bad.read_text(encoding="utf-8"), bad.name)

    def test_t1_fixture_ids_are_namespaced_to_the_run(self):
        sql, source_digest = runner.load_scenario(
            "public_registration_authority_test.sql", "01234567-89ab-4cde-8fab-0123456789ab", ROOT)
        self.assertNotIn("aa000000-0000-4000-8000-000000000001", sql)
        self.assertIn("run-0123456789ab4cde8fab0123456789ab-authority-scope-a@example.test", sql)
        self.assertEqual(len(source_digest), 64)

    def test_t2_and_t5_scenarios_are_transactional_and_namespace_dynamic_fixture_ids(self):
        run_id = "01234567-89ab-4cde-8fab-0123456789ab"
        with self.assertRaisesRegex(runner.SafetyError, "prohibited"):
            runner.load_scenario("public_intake_test.sql", run_id, ROOT)
        sql, _ = runner.load_scenario("pending_review_test.sql", run_id, ROOT)
        self.assertNotIn("'review-a@example.test'", sql)
        self.assertIn("run-0123456789ab4cde8fab0123456789ab-review-a@example.test", sql)

    def test_cleanup_and_unscoped_persistent_mutations_are_rejected(self):
        with self.assertRaises(runner.SafetyError):
            runner.validate_scenario_sql(
                "BEGIN; DELETE FROM public.user_access; ROLLBACK;",
                "public_registration_authority_test.sql")
        with self.assertRaises(runner.SafetyError):
            runner.validate_scenario_sql(
                "BEGIN; UPDATE public.congregations SET name='changed'; ROLLBACK;",
                "public_registration_authority_test.sql")

    def test_target_mismatch_is_rejected_before_psql_is_invoked(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            marker = directory / "called"
            fake = directory / "fake_psql.py"
            fake.write_text(
                "from pathlib import Path\n"
                f"Path({str(marker)!r}).write_text('called')\n"
                "print('t')\n", encoding="utf-8")
            backup = self.make_backup(directory)
            evidence = directory / "evidence.json"
            env = os.environ.copy()
            env.update({
                "PUBLIC_INTAKE_TRUSTED_PROJECT_REF": "abcdefghijklmnopqrst",
                "PUBLIC_INTAKE_DATABASE_URL": "postgresql://operator@wrong.supabase.co/postgres",
            })
            result = subprocess.run([
                sys.executable, str(ROOT / "scripts/test_public_intake_hosted.py"),
                "--project-ref", "abcdefghijklmnopqrst", "--run-id", str(uuid.uuid4()),
                "--scenario", "public_registration_authority_test.sql",
                "--backup-manifest", str(backup), "--evidence-manifest", str(evidence),
                "--psql-command-json", json.dumps([sys.executable, str(fake)]),
            ], input="abcdefghijklmnopqrst\n", text=True, capture_output=True, env=env, cwd=ROOT)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(marker.exists())
            self.assertNotIn("operator@", result.stdout + result.stderr)

    def test_fake_psql_receives_only_target_probe_migration_probes_and_owned_scenario(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            capture = directory / "calls.jsonl"
            fake = directory / "fake_psql.py"
            fake.write_text(
                "import json, os, sys\n"
                "from pathlib import Path\n"
                "with open(os.environ['FAKE_PSQL_CAPTURE'], 'a', encoding='utf-8') as f: "
                "f.write(json.dumps({'args':sys.argv[1:], 'stdin':sys.stdin.read()})+'\\n')\n"
                "print('FAKE_PRIVATE_QUERY_RESULT', file=sys.stderr)\n"
                "args=sys.argv[1:]\n"
                "sql=args[args.index('-c')+1] if '-c' in args else ''\n"
                "print(json.dumps({'public.converts':0,'public.ministry_people':0,'public.weekly_reports':0,"
                "'private.mutation_receipts':0,'public.photo_assets':0,'private.congregation_week_guards':0,"
                "'storage.objects':0,'auth.users':0,'public.user_access':0}) "
                "if 'jsonb_build_object' in sql else ('t' if '-c' in args else ''))\n",
                encoding="utf-8")
            fake_supabase = directory / "fake_supabase.py"
            fake_supabase.write_text(
                "import json\n"
                "print(json.dumps([{'id':'abcdefghijklmnopqrst'}]))\n", encoding="utf-8")
            backup = self.make_backup(directory)
            evidence = directory / "evidence.json"
            run_id = "01234567-89ab-4cde-8fab-0123456789ab"
            env = os.environ.copy()
            env.update({
                "PUBLIC_INTAKE_TRUSTED_PROJECT_REF": "abcdefghijklmnopqrst",
                "SUPABASE_URL": "https://abcdefghijklmnopqrst.supabase.co",
                "PUBLIC_INTAKE_DATABASE_URL": "postgresql://operator@db.abcdefghijklmnopqrst.supabase.co/postgres?sslmode=require",
                "FAKE_PSQL_CAPTURE": str(capture),
            })
            result = subprocess.run([
                sys.executable, str(ROOT / "scripts/test_public_intake_hosted.py"),
                "--project-ref", "abcdefghijklmnopqrst", "--run-id", run_id,
                "--scenario", "public_registration_authority_test.sql",
                "--backup-manifest", str(backup), "--evidence-manifest", str(evidence),
                "--psql-command-json", json.dumps([sys.executable, str(fake)]),
                "--supabase-command-json", json.dumps([sys.executable, str(fake_supabase)]),
            ], input="abcdefghijklmnopqrst\n", text=True, capture_output=True, env=env, cwd=ROOT)
            self.assertEqual(result.returncode, 0, result.stderr)
            calls = [json.loads(line) for line in capture.read_text(encoding="utf-8").splitlines()]
            self.assertGreaterEqual(len(calls), 5)
            scenario_call = calls[-2]
            self.assertIn("-c", " ".join(calls[0]["args"]))
            self.assertIn("-f", " ".join(scenario_call["args"]))
            self.assertNotIn("postgresql://", " ".join(" ".join(call["args"]) for call in calls))
            self.assertNotIn("FAKE_PRIVATE_QUERY_RESULT", result.stdout + result.stderr)
            self.assertIn(run_id.replace("-", "")[8:], scenario_call["stdin"])
            self.assertNotIn("aa000000-0000-4000-8000-000000000001", scenario_call["stdin"])
            manifest_text = evidence.read_text(encoding="utf-8")
            self.assertNotIn("operator@", manifest_text)
            self.assertNotIn("sslmode", manifest_text)
            self.assertIn("PASS", manifest_text)
            self.assertIn('"reconciled": true', manifest_text)

    def test_authenticated_account_missing_project_is_rejected_before_psql(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            marker = directory / "psql-called"
            fake = directory / "fake_psql.py"
            fake.write_text(
                "from pathlib import Path\n"
                f"Path({str(marker)!r}).write_text('called')\n", encoding="utf-8")
            fake_supabase = directory / "fake_supabase.py"
            fake_supabase.write_text("import json; print(json.dumps([{'id':'anotherprojectref000'}]))\n",
                                     encoding="utf-8")
            backup = self.make_backup(directory)
            env = os.environ.copy()
            env.update({
                "PUBLIC_INTAKE_TRUSTED_PROJECT_REF": "abcdefghijklmnopqrst",
                "SUPABASE_URL": "https://abcdefghijklmnopqrst.supabase.co",
                "PUBLIC_INTAKE_DATABASE_URL": "postgresql://operator@db.abcdefghijklmnopqrst.supabase.co/postgres?sslmode=require",
            })
            result = subprocess.run([
                sys.executable, str(ROOT / "scripts/test_public_intake_hosted.py"),
                "--project-ref", "abcdefghijklmnopqrst", "--run-id", str(uuid.uuid4()),
                "--scenario", "public_registration_authority_test.sql",
                "--backup-manifest", str(backup), "--evidence-manifest", str(directory / "evidence.json"),
                "--psql-command-json", json.dumps([sys.executable, str(fake)]),
                "--supabase-command-json", json.dumps([sys.executable, str(fake_supabase)]),
            ], input="abcdefghijklmnopqrst\n", text=True, capture_output=True, env=env, cwd=ROOT)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(marker.exists())
            self.assertNotIn("operator@", result.stdout + result.stderr)

    def test_hosted_concurrency_refuses_existing_global_truncate_helper(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            marker = directory / "psql-called"
            fake = directory / "fake_psql.py"
            fake.write_text(
                "from pathlib import Path\n"
                f"Path({str(marker)!r}).write_text('called')\n", encoding="utf-8")
            backup = self.make_backup(directory)
            env = os.environ.copy()
            result = subprocess.run([
                sys.executable, str(ROOT / "scripts/test_public_intake_hosted.py"),
                "--project-ref", "abcdefghijklmnopqrst", "--run-id", str(uuid.uuid4()),
                "--scenario", "public_intake_test.sql", "--concurrency",
                "--backup-manifest", str(backup), "--evidence-manifest", str(directory / "evidence.json"),
                "--psql-command-json", json.dumps([sys.executable, str(fake)]),
            ], text=True, capture_output=True, env=env, cwd=ROOT)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(marker.exists())
            self.assertNotIn("truncate", result.stdout + result.stderr.lower())


if __name__ == "__main__":
    unittest.main()
