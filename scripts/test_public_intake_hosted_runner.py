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

    def test_preproduction_allows_only_the_digest_pinned_rollback_capacity_reset(self):
        scenario = (ROOT / "supabase/tests/database/public_intake_test.sql").read_text(encoding="utf-8")

        with self.assertRaises(runner.SafetyError):
            runner.validate_scenario_sql(scenario, "public_intake_test.sql")
        runner.validate_scenario_sql(scenario, "public_intake_test.sql", preproduction=True)

    def test_preproduction_rejects_truncate_of_any_other_application_table(self):
        unsafe = "BEGIN; TRUNCATE public.converts CASCADE; ROLLBACK;"

        with self.assertRaises(runner.SafetyError):
            runner.validate_scenario_sql(unsafe, "public_intake_test.sql", preproduction=True)

    def test_preproduction_does_not_unblock_legacy_concurrency_helper(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            marker = directory / "subprocess-called"
            fake = directory / "fake.py"
            fake.write_text(
                "from pathlib import Path\n"
                f"Path({str(marker)!r}).write_text('called')\n", encoding="utf-8")
            backup = self.make_backup(directory)
            evidence = directory / "blocked.json"
            env = os.environ.copy()
            env.update({
                "PUBLIC_INTAKE_TRUSTED_PROJECT_REF": "abcdefghijklmnopqrst",
                "SUPABASE_URL": "https://abcdefghijklmnopqrst.supabase.co",
                "PUBLIC_INTAKE_DATABASE_URL": (
                    "postgresql://operator@db.abcdefghijklmnopqrst.supabase.co/postgres?sslmode=require"
                ),
            })
            result = subprocess.run([
                sys.executable, str(ROOT / "scripts/test_public_intake_hosted.py"),
                "--project-ref", "abcdefghijklmnopqrst", "--run-id", str(uuid.uuid4()),
                "--scenario", "public_intake_test.sql", "--preproduction", "--concurrency",
                "--backup-manifest", str(backup), "--evidence-manifest", str(evidence),
                "--psql-command-json", json.dumps([sys.executable, str(fake)]),
                "--supabase-command-json", json.dumps([sys.executable, str(fake)]),
            ], text=True, capture_output=True, env=env, cwd=ROOT)

            self.assertEqual(result.returncode, 2)
            self.assertFalse(marker.exists())
            manifest = json.loads(evidence.read_text(encoding="utf-8"))
            self.assertEqual(manifest["status"], "BLOCKED")
            self.assertFalse(manifest["hosted_subprocesses_invoked"])
            self.assertFalse(manifest["scenario_dispatched"])

    def test_preproduction_capacity_sql_dispatches_only_after_backup_and_exact_target_confirmation(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            capture = directory / "psql-calls.jsonl"
            snapshot = {
                "counts": {
                    "public.converts": 0, "public.ministry_people": 0,
                    "public.weekly_reports": 0, "private.mutation_receipts": 0,
                    "public.photo_assets": 0, "storage.objects": 0, "auth.users": 0,
                    "private.congregation_week_guards": 0, "public.user_access": 0,
                    "private.public_intake_submissions": 0,
                    "private.public_intake_receipts": 0,
                    "private.public_intake_decisions": 0,
                    "private.public_intake_accepted_events": 0,
                },
                "revisions": {
                    "public.converts": {"max": 0, "distribution": {}},
                    "public.ministry_people": {"max": 0, "distribution": {}},
                    "private.public_intake_submissions": {"max": 0, "distribution": {}},
                },
                "settings": {"enabled": True, "global_pending_limit": 1000},
                "grants": {}, "migrations": ["202610250002", "202610250003"],
            }
            fake_psql = directory / "fake_psql.py"
            fake_psql.write_text(
                "import json, os, sys\n"
                "args=sys.argv[1:]\n"
                "stdin=sys.stdin.read()\n"
                "with open(os.environ['FAKE_PSQL_CAPTURE'], 'a', encoding='utf-8') as f: "
                "f.write(json.dumps({'args':args, 'stdin':stdin})+'\\n')\n"
                "sql=args[args.index('-c')+1] if '-c' in args else ''\n"
                f"print({json.dumps(snapshot)!r} if \"'counts'\" in sql else ('t' if '-c' in args else ''))\n",
                encoding="utf-8",
            )
            fake_supabase = directory / "fake_supabase.py"
            fake_supabase.write_text(
                "import json, os, sys\n"
                "args=sys.argv[1:]\n"
                "open(os.environ['FAKE_SUPABASE_CAPTURE'],'a').write(json.dumps(args)+'\\n')\n"
                "if args[:2] == ['projects','list']:\n"
                " print(json.dumps([{'id':'abcdefghijklmnopqrst'}]))\n"
                "elif args[:2] == ['migration','list']:\n"
                " print(json.dumps({'migrations':["
                "{'local':'202610250002','remote':'202610250002','time':'202610250002'},"
                "{'local':'202610250003','remote':'202610250003','time':'202610250003'}]}))\n"
                "else: sys.exit(9)\n", encoding="utf-8",
            )
            backup = self.make_backup(directory)
            evidence = directory / "preproduction-evidence.json"
            run_id = "01234567-89ab-4cde-8fab-0123456789ab"
            env = os.environ.copy()
            env.update({
                "PUBLIC_INTAKE_TRUSTED_PROJECT_REF": "abcdefghijklmnopqrst",
                "SUPABASE_URL": "https://abcdefghijklmnopqrst.supabase.co",
                "PUBLIC_INTAKE_DATABASE_URL": (
                    "postgresql://operator:fake-secret@db.abcdefghijklmnopqrst.supabase.co/postgres?sslmode=require"
                ),
                "FAKE_PSQL_CAPTURE": str(capture),
                "FAKE_SUPABASE_CAPTURE": str(directory / "supabase-calls.jsonl"),
            })
            self.assertEqual(
                runner._remote_applied_migrations(
                    [sys.executable, str(fake_supabase)], "abcdefghijklmnopqrst", env),
                ["202610250002", "202610250003"],
            )
            result = subprocess.run([
                sys.executable, str(ROOT / "scripts/test_public_intake_hosted.py"),
                "--project-ref", "abcdefghijklmnopqrst", "--run-id", run_id,
                "--scenario", "public_intake_test.sql", "--preproduction",
                "--backup-manifest", str(backup), "--evidence-manifest", str(evidence),
                "--psql-command-json", json.dumps([sys.executable, str(fake_psql)]),
                "--supabase-command-json", json.dumps([sys.executable, str(fake_supabase)]),
            ], input="abcdefghijklmnopqrst\n", text=True, capture_output=True, env=env, cwd=ROOT)

            self.assertEqual(
                result.returncode, 0,
                result.stdout + result.stderr +
                (evidence.read_text(encoding="utf-8") if evidence.exists() else "") +
                ((directory / "supabase-calls.jsonl").read_text(encoding="utf-8")
                 if (directory / "supabase-calls.jsonl").exists() else ""),
            )
            calls = [json.loads(line) for line in capture.read_text(encoding="utf-8").splitlines()]
            scenario_call = next(call for call in calls if "-f" in call["args"])
            self.assertIn("TRUNCATE private.public_intake_decisions", scenario_call["stdin"])
            self.assertTrue(scenario_call["stdin"].rstrip().endswith("ROLLBACK;"))
            manifest = json.loads(evidence.read_text(encoding="utf-8"))
            self.assertEqual(manifest["execution_mode"], "preproduction")
            self.assertEqual(manifest["status"], "PASS")
            self.assertTrue(manifest["target_confirmed"])
            self.assertTrue(manifest["scenario_dispatched"])
            self.assertTrue(manifest["hosted_write_attempted"])
            self.assertTrue(manifest["reconciled"])
            self.assertNotIn("fake-secret", evidence.read_text(encoding="utf-8"))

    def test_preproduction_wrong_typed_target_stops_before_database_subprocess(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            marker = directory / "psql-called"
            fake_psql = directory / "fake_psql.py"
            fake_psql.write_text(
                "from pathlib import Path\n"
                f"Path({str(marker)!r}).write_text('called')\n", encoding="utf-8")
            fake_supabase = directory / "fake_supabase.py"
            fake_supabase.write_text(
                "import json\nprint(json.dumps([{'id':'abcdefghijklmnopqrst'}]))\n", encoding="utf-8")
            backup = self.make_backup(directory)
            env = os.environ.copy()
            env.update({
                "PUBLIC_INTAKE_TRUSTED_PROJECT_REF": "abcdefghijklmnopqrst",
                "SUPABASE_URL": "https://abcdefghijklmnopqrst.supabase.co",
                "PUBLIC_INTAKE_DATABASE_URL": (
                    "postgresql://operator:fake-secret@db.abcdefghijklmnopqrst.supabase.co/postgres?sslmode=require"
                ),
            })
            result = subprocess.run([
                sys.executable, str(ROOT / "scripts/test_public_intake_hosted.py"),
                "--project-ref", "abcdefghijklmnopqrst", "--run-id", str(uuid.uuid4()),
                "--scenario", "public_intake_test.sql", "--preproduction",
                "--backup-manifest", str(backup),
                "--evidence-manifest", str(directory / "unconfirmed-evidence.json"),
                "--psql-command-json", json.dumps([sys.executable, str(fake_psql)]),
                "--supabase-command-json", json.dumps([sys.executable, str(fake_supabase)]),
            ], input="wrong-project\n", text=True, capture_output=True, env=env, cwd=ROOT)

            self.assertEqual(result.returncode, 2)
            self.assertFalse(marker.exists())

    def test_target_confirmation_accepts_only_project_scoped_session_pooler(self):
        project_ref = "abcdefghijklmnopqrst"
        base = {
            "PUBLIC_INTAKE_TRUSTED_PROJECT_REF": project_ref,
            "SUPABASE_URL": f"https://{project_ref}.supabase.co",
        }
        for username in ("postgres", "cli_login_postgres"):
            with self.subTest(username=username):
                env = {
                    **base,
                    "PUBLIC_INTAKE_DATABASE_URL": (
                        f"postgresql://{username}.{project_ref}:secret@"
                        "aws-1-us-west-2.pooler.supabase.com:5432/postgres?sslmode=require"
                    ),
                }
                self.assertEqual(runner._confirm_target(project_ref, env), project_ref)

    def test_target_confirmation_preserves_direct_project_database_form(self):
        project_ref = "abcdefghijklmnopqrst"
        env = {
            "PUBLIC_INTAKE_TRUSTED_PROJECT_REF": project_ref,
            "SUPABASE_URL": f"https://{project_ref}.supabase.co",
            "PUBLIC_INTAKE_DATABASE_URL": (
                f"postgresql://postgres:secret@db.{project_ref}.supabase.co/postgres?sslmode=require"
            ),
        }
        self.assertEqual(runner._confirm_target(project_ref, env), project_ref)

    def test_target_confirmation_rejects_unsafe_pooler_shapes(self):
        project_ref = "abcdefghijklmnopqrst"
        base = {
            "PUBLIC_INTAKE_TRUSTED_PROJECT_REF": project_ref,
            "SUPABASE_URL": f"https://{project_ref}.supabase.co",
        }
        invalid_urls = (
            "postgresql://postgres.wrongprojectref000:secret@aws-1-us-west-2.pooler.supabase.com:5432/postgres?sslmode=require",
            "postgresql://cli_login_postgres.abcdefghijklmnopqrst:secret@aws-1-us-west-2.pooler.supabase.com:6543/postgres?sslmode=require",
            "postgresql://cli_login_postgres.abcdefghijklmnopqrst:secret@aws-1-us-west-2.pooler.supabase.com:5432/other?sslmode=require",
            "postgresql://otherrole.abcdefghijklmnopqrst:secret@aws-1-us-west-2.pooler.supabase.com:5432/postgres?sslmode=require",
            "postgresql://cli_login_postgres.abcdefghijklmnopqrst:secret@unrelated.example.com:5432/postgres?sslmode=require",
            "postgresql://cli_login_postgres.abcdefghijklmnopqrst:secret@aws-1-us-west-2.pooler.supabase.com:5432/postgres",
            "postgresql://cli_login_postgres.abcdefghijklmnopqrst:secret@aws-1-us-west-2.pooler.supabase.com:5432/postgres?sslmode=prefer",
        )
        for database_url in invalid_urls:
            with self.subTest(database_url=database_url.split("@")[1]):
                with self.assertRaises(runner.SafetyError):
                    runner._confirm_target(project_ref, {
                        **base, "PUBLIC_INTAKE_DATABASE_URL": database_url,
                    })

    def test_target_confirmation_rejects_libpq_query_overrides(self):
        project_ref = "abcdefghijklmnopqrst"
        base = {
            "PUBLIC_INTAKE_TRUSTED_PROJECT_REF": project_ref,
            "SUPABASE_URL": f"https://{project_ref}.supabase.co",
        }
        overrides = (
            "host=other.example",
            "user=postgres.otherprojectref000",
            "hostaddr=203.0.113.42",
            "dbname=other_database",
            "port=6543",
            "sslmode=require&sslmode=prefer",
        )
        for override in overrides:
            with self.subTest(override=override):
                url = (
                    f"postgresql://postgres.{project_ref}:secret@"
                    f"aws-1-us-west-2.pooler.supabase.com:5432/postgres?sslmode=require&{override}"
                )
                with self.assertRaises(runner.SafetyError):
                    runner._confirm_target(project_ref, {
                        **base, "PUBLIC_INTAKE_DATABASE_URL": url,
                    })

    def test_missing_required_migrations_writes_blocked_baseline_without_scenario_dispatch(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            capture = directory / "psql-calls.jsonl"
            fake_psql = directory / "fake_psql.py"
            snapshot = {
                "counts": {
                    "public.converts": 4, "public.ministry_people": 4,
                    "public.weekly_reports": 2, "private.mutation_receipts": 5,
                    "public.photo_assets": 1, "storage.objects": 1,
                    "auth.users": 6, "private.congregation_week_guards": 3,
                    "public.user_access": 6,
                },
                "revisions": {
                    "public.converts": {"max": 2, "distribution": {"1": 3, "2": 1}},
                    "public.ministry_people": {"max": 1, "distribution": {"1": 4}},
                },
                "settings": None,
                "grants": {},
                "migrations": [],
            }
            fake_psql.write_text(
                "import json, os, sys\n"
                "with open(os.environ['FAKE_PSQL_CAPTURE'], 'a', encoding='utf-8') as f: "
                "f.write(json.dumps({'args':sys.argv[1:], 'stdin':sys.stdin.read()})+'\\n')\n"
                "args=sys.argv[1:]\n"
                "sql=args[args.index('-c')+1] if '-c' in args else ''\n"
                f"print({json.dumps(snapshot)!r} if \"'counts'\" in sql else ('t' if '-c' in args else ''))\n",
                encoding="utf-8",
            )
            fake_supabase = directory / "fake_supabase.py"
            fake_supabase.write_text(
                "import json, sys\n"
                "args=sys.argv[1:]\n"
                "if args[:2] == ['projects','list']: "
                "print(json.dumps([{'id':'abcdefghijklmnopqrst'}]))\n"
                "elif args[:2] == ['migration','list']: "
                "print(json.dumps({'migrations':[]}))\n"
                "else: sys.exit(9)\n",
                encoding="utf-8",
            )
            backup = self.make_backup(directory)
            evidence_path = directory / "missing-migrations.json"
            run_id = "01234567-89ab-4cde-8fab-0123456789ab"
            env = os.environ.copy()
            env.update({
                "PUBLIC_INTAKE_TRUSTED_PROJECT_REF": "abcdefghijklmnopqrst",
                "SUPABASE_URL": "https://abcdefghijklmnopqrst.supabase.co",
                "PUBLIC_INTAKE_DATABASE_URL": (
                    "postgresql://cli_login_postgres.abcdefghijklmnopqrst:secret@"
                    "aws-1-us-west-2.pooler.supabase.com:5432/postgres?sslmode=require"
                ),
                "FAKE_PSQL_CAPTURE": str(capture),
            })
            result = subprocess.run([
                sys.executable, str(ROOT / "scripts/test_public_intake_hosted.py"),
                "--project-ref", "abcdefghijklmnopqrst", "--run-id", run_id,
                "--scenario", "public_registration_authority_test.sql",
                "--backup-manifest", str(backup), "--evidence-manifest", str(evidence_path),
                "--psql-command-json", json.dumps([sys.executable, str(fake_psql)]),
                "--supabase-command-json", json.dumps([sys.executable, str(fake_supabase)]),
            ], input="abcdefghijklmnopqrst\n", text=True, capture_output=True, env=env, cwd=ROOT)

            self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
            self.assertTrue(evidence_path.is_file())
            manifest = json.loads(evidence_path.read_text(encoding="utf-8"))
            self.assertEqual(manifest["status"], "BLOCKED")
            self.assertTrue(manifest["target_confirmed"])
            self.assertEqual(manifest["required_migrations"], ["202610250002"])
            self.assertEqual(manifest["applied_migrations"], [])
            self.assertEqual(manifest["missing_migrations"], ["202610250002"])
            self.assertEqual(manifest["baseline_scope"], "core-only")
            self.assertIsNone(manifest["run_ownership"])
            self.assertFalse(manifest["hosted_write_attempted"])
            self.assertFalse(manifest["scenario_dispatched"])
            self.assertIn("baseline", manifest)
            self.assertIn("required migrations", manifest["reason"].lower())
            calls = [json.loads(line) for line in capture.read_text(encoding="utf-8").splitlines()]
            self.assertFalse(any("-f" in call["args"] for call in calls))
            self.assertNotIn("postgresql://", evidence_path.read_text(encoding="utf-8"))

    def test_missing_intake_migrations_writes_limited_baseline_without_queue_tables_or_scenario(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            capture = directory / "psql-calls.jsonl"
            fake_psql = directory / "fake_psql.py"
            core_snapshot = {
                "counts": {
                    "public.converts": 4, "public.ministry_people": 4,
                    "public.weekly_reports": 2, "private.mutation_receipts": 5,
                    "public.photo_assets": 1, "storage.objects": 1,
                    "auth.users": 6, "private.congregation_week_guards": 3,
                    "public.user_access": 6,
                },
                "revisions": {
                    "public.converts": {"max": 2, "distribution": {"1": 3, "2": 1}},
                    "public.ministry_people": {"max": 1, "distribution": {"1": 4}},
                },
                "settings": None, "grants": {}, "migrations": [],
            }
            fake_psql.write_text(
                "import json, os, sys\n"
                "args=sys.argv[1:]\n"
                "sql=args[args.index('-c')+1] if '-c' in args else ''\n"
                "stdin=sys.stdin.read()\n"
                "with open(os.environ['FAKE_PSQL_CAPTURE'], 'a', encoding='utf-8') as f: "
                "f.write(json.dumps({'args':args, 'sql':sql, 'stdin':stdin})+'\\n')\n"
                "if 'private.public_intake_submissions' in sql: sys.exit(7)\n"
                "if \"'counts'\" in sql: print(" + repr(json.dumps(core_snapshot)) + ")\n"
                "elif '-c' in args: print('t')\n",
                encoding="utf-8",
            )
            fake_supabase = directory / "fake_supabase.py"
            fake_supabase.write_text(
                "import json, sys\n"
                "args=sys.argv[1:]\n"
                "if args[:2] == ['projects','list']: "
                "print(json.dumps([{'id':'abcdefghijklmnopqrst'}]))\n"
                "elif args[:2] == ['migration','list']: "
                "print(json.dumps({'migrations':[]}))\n"
                "else: sys.exit(9)\n",
                encoding="utf-8",
            )
            backup = self.make_backup(directory)
            evidence_path = directory / "missing-intake-migrations.json"
            env = os.environ.copy()
            env.update({
                "PUBLIC_INTAKE_TRUSTED_PROJECT_REF": "abcdefghijklmnopqrst",
                "SUPABASE_URL": "https://abcdefghijklmnopqrst.supabase.co",
                "PUBLIC_INTAKE_DATABASE_URL": (
                    "postgresql://cli_login_postgres.abcdefghijklmnopqrst:secret@"
                    "aws-1-us-west-2.pooler.supabase.com:5432/postgres?sslmode=require"
                ),
                "FAKE_PSQL_CAPTURE": str(capture),
            })
            result = subprocess.run([
                sys.executable, str(ROOT / "scripts/test_public_intake_hosted.py"),
                "--project-ref", "abcdefghijklmnopqrst", "--run-id", "01234567-89ab-4cde-8fab-0123456789ab",
                "--scenario", "public_intake_hosted_smoke_test.sql",
                "--backup-manifest", str(backup), "--evidence-manifest", str(evidence_path),
                "--psql-command-json", json.dumps([sys.executable, str(fake_psql)]),
                "--supabase-command-json", json.dumps([sys.executable, str(fake_supabase)]),
            ], input="abcdefghijklmnopqrst\n", text=True, capture_output=True, env=env, cwd=ROOT)

            self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
            self.assertTrue(evidence_path.is_file())
            manifest = json.loads(evidence_path.read_text(encoding="utf-8"))
            self.assertEqual(manifest["status"], "BLOCKED")
            self.assertEqual(manifest["applied_migrations"], [])
            self.assertEqual(manifest["missing_migrations"], ["202610250002", "202610250003"])
            self.assertEqual(manifest["baseline_scope"], "core-only")
            self.assertIsNone(manifest["run_ownership"])
            self.assertFalse(manifest["hosted_write_attempted"])
            self.assertFalse(manifest["scenario_dispatched"])
            calls = [json.loads(line) for line in capture.read_text(encoding="utf-8").splitlines()]
            self.assertTrue(calls)
            self.assertFalse(any("private.public_intake_submissions" in call["sql"] for call in calls))
            self.assertFalse(any("-f" in call["args"] for call in calls))

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
        with self.assertRaises(runner.SafetyError):
            runner.validate_scenario_sql(
                "BEGIN; SELECT pg_terminate_backend(123); ROLLBACK;",
                "public_registration_authority_test.sql")
        with self.assertRaises(runner.SafetyError):
            runner.validate_scenario_sql(
                "BEGIN; SELECT public.unreviewed_side_effect(); ROLLBACK;",
                "public_registration_authority_test.sql")

    def test_changed_scenario_with_dangerous_function_fails_before_any_cli(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            repository = directory / "repo"
            scripts = repository / "scripts"
            scenarios = repository / "supabase/tests/database"
            scripts.mkdir(parents=True)
            scenarios.mkdir(parents=True)
            (scripts / "test_public_intake_hosted.py").write_bytes(
                (ROOT / "scripts/test_public_intake_hosted.py").read_bytes())
            canonical = ROOT / "supabase/tests/database/public_registration_authority_test.sql"
            changed_scenario = canonical.read_text(encoding="utf-8").replace(
                "ROLLBACK;",
                "SELECT pg_terminate_backend(pg_backend_pid());\nROLLBACK;",
            )
            (scenarios / canonical.name).write_text(changed_scenario, encoding="utf-8")
            psql_marker = directory / "psql-called"
            supabase_marker = directory / "supabase-called"
            fake_psql = directory / "fake_psql.py"
            fake_psql.write_text(
                "from pathlib import Path\n"
                f"Path({str(psql_marker)!r}).write_text('called')\n", encoding="utf-8")
            fake_supabase = directory / "fake_supabase.py"
            fake_supabase.write_text(
                "from pathlib import Path\n"
                f"Path({str(supabase_marker)!r}).write_text('called')\n", encoding="utf-8")
            backup = self.make_backup(directory)
            env = os.environ.copy()
            env.update({
                "PUBLIC_INTAKE_TRUSTED_PROJECT_REF": "abcdefghijklmnopqrst",
                "SUPABASE_URL": "https://abcdefghijklmnopqrst.supabase.co",
                "PUBLIC_INTAKE_DATABASE_URL": "postgresql://operator:fake-secret@db.abcdefghijklmnopqrst.supabase.co/postgres?sslmode=require",
            })
            result = subprocess.run([
                sys.executable, str(scripts / "test_public_intake_hosted.py"),
                "--project-ref", "abcdefghijklmnopqrst", "--run-id", str(uuid.uuid4()),
                "--scenario", "public_registration_authority_test.sql",
                "--backup-manifest", str(backup), "--evidence-manifest", str(directory / "evidence.json"),
                "--psql-command-json", json.dumps([sys.executable, str(fake_psql)]),
                "--supabase-command-json", json.dumps([sys.executable, str(fake_supabase)]),
            ], text=True, capture_output=True, env=env, cwd=repository)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(psql_marker.exists())
            self.assertFalse(supabase_marker.exists())
            self.assertFalse((directory / "evidence.json").exists())

    def test_modified_safe_scenario_is_rejected_by_reviewed_digest(self):
        with tempfile.TemporaryDirectory() as temp:
            repository = Path(temp)
            scenario_dir = repository / "supabase/tests/database"
            scenario_dir.mkdir(parents=True)
            source = (ROOT / "supabase/tests/database/public_intake_hosted_smoke_test.sql").read_text(
                encoding="utf-8")
            (scenario_dir / "public_intake_hosted_smoke_test.sql").write_text(
                source + "\n-- unreviewed harmless edit\n", encoding="utf-8")
            with self.assertRaisesRegex(runner.SafetyError, "reviewed digest"):
                runner.load_scenario(
                    "public_intake_hosted_smoke_test.sql",
                    "01234567-89ab-4cde-8fab-0123456789ab", repository)

    def test_t1_fixture_ids_are_namespaced_to_the_run(self):
        sql, source_digest = runner.load_scenario(
            "public_registration_authority_test.sql", "01234567-89ab-4cde-8fab-0123456789ab", ROOT)
        self.assertNotIn("aa000000-0000-4000-8000-000000000001", sql)
        self.assertIn("run-0123456789ab4cde8fab0123456789ab-authority-scope-a@example.test", sql)
        self.assertEqual(len(source_digest), 64)

    def test_t2_full_capacity_scenario_is_rejected_for_hosted_execution(self):
        run_id = "01234567-89ab-4cde-8fab-0123456789ab"
        sql = (ROOT / "supabase/tests/database/public_intake_test.sql").read_text(encoding="utf-8")
        with self.assertRaisesRegex(runner.SafetyError, "prohibited"):
            runner.validate_scenario_sql(sql, "public_intake_test.sql")
        self.assertIn("TRUNCATE private.public_intake_decisions", sql)
        # The pre-production exception is confined to that exact pinned queue
        # reset. A nested function body must not hide a different TRUNCATE from
        # the statement-level safety check.
        nested_unrelated_truncate = (
            "BEGIN; CREATE FUNCTION pg_temp.reset_intake() RETURNS void "
            "LANGUAGE plpgsql AS $$DECLARE fixture uuid := "
            "'00000000-0000-4000-8000-000000000001'; BEGIN "
            "TRUNCATE public.converts CASCADE; "
            "END $$; ROLLBACK;"
        )
        with self.assertRaisesRegex(runner.SafetyError, "TRUNCATE"):
            runner.validate_scenario_sql(
                nested_unrelated_truncate, "public_intake_test.sql", preproduction=True)
        runner.validate_scenario_sql(sql, "public_intake_test.sql", preproduction=True)
        sql, _ = runner.load_scenario("pending_review_test.sql", run_id, ROOT)
        self.assertNotIn("'review-a@example.test'", sql)
        self.assertIn("run-0123456789ab4cde8fab0123456789ab-review-a@example.test", sql)

    def test_t2_hosted_smoke_scenario_is_short_run_owned_and_rollback_only(self):
        run_id = "01234567-89ab-4cde-8fab-0123456789ab"
        sql, digest = runner.load_scenario("public_intake_hosted_smoke_test.sql", run_id, ROOT)
        self.assertTrue(sql.startswith("BEGIN;"))
        self.assertTrue(sql.rstrip().endswith("ROLLBACK;"))
        self.assertNotRegex(sql, r"(?i)\b(?:TRUNCATE|COMMIT|UPDATE|DELETE)\b")
        self.assertIn("SET LOCAL statement_timeout='5s';", sql)
        self.assertIn("SET LOCAL lock_timeout='2s';", sql)
        self.assertEqual(sql.count("INSERT INTO intake_smoke_scope"), 1)
        self.assertIn("GRANT SELECT ON intake_smoke_scope TO service_role", sql)
        self.assertNotRegex(sql, r"(?i)INSERT\s+INTO\s+(?:public|private)\.")
        self.assertNotIn("private.business_today()", sql)
        self.assertIn("'conversion_date','2000-01-01'", sql)
        self.assertNotIn("0f100000-0000-4000-8000-000000000001", sql)
        ownership = runner.run_ownership(sql)
        self.assertTrue(ownership["fixture_ids"])
        self.assertEqual(ownership["persistent_rows_expected"], 0)
        self.assertEqual(len(digest), 64)

    def test_t2_smoke_asserts_select_privileges_for_every_private_queue_table_and_role(self):
        sql = (ROOT / "supabase/tests/database/public_intake_hosted_smoke_test.sql").read_text(
            encoding="utf-8")
        queue_tables = (
            "private.public_intake_submissions", "private.public_intake_receipts",
            "private.public_intake_accepted_events", "private.public_intake_decisions",
        )
        roles = ("anon", "authenticated", "service_role")
        for table in queue_tables:
            for role in roles:
                with self.subTest(table=table, role=role):
                    self.assertIn(
                        f"NOT has_table_privilege('{role}','{table}','SELECT')", sql)

    def test_fixed_retention_contract_rejects_calendar_interval_components(self):
        intake_migration = (ROOT / "supabase/migrations/202610250003_public_intake.sql").read_text(
            encoding="utf-8")
        review_migration = (ROOT / "supabase/migrations/202610250004_pending_review.sql").read_text(
            encoding="utf-8")
        settings_constraints = intake_migration.split("CREATE TABLE private.public_intake_settings", 1)[1].split(
            ");", 1)[0]
        writer = review_migration.split("CREATE FUNCTION public.ieadpe_review_pending_intake", 1)[1]
        self.assertIn("extract(month from pending_ttl)=0", settings_constraints)
        self.assertIn("extract(year from pending_ttl)=0", settings_constraints)
        for field in ("hour", "minute", "second"):
            self.assertIn(f"extract({field} from pending_ttl)=0", settings_constraints)
        self.assertIn("extract(month from decision_retention)=0", settings_constraints)
        self.assertIn("extract(year from decision_retention)=0", settings_constraints)
        for field in ("hour", "minute", "second"):
            self.assertIn(f"extract({field} from decision_retention)=0", settings_constraints)
        self.assertIn("extract(month from settings.decision_retention)<>0", writer)
        self.assertIn("extract(year from settings.decision_retention)<>0", writer)
        for field in ("hour", "minute", "second"):
            self.assertIn(f"extract({field} from settings.decision_retention)<>0", writer)

    def test_reviewed_scenario_pins_match_allowlisted_sources(self):
        for scenario_name, expected_digest in runner.SCENARIO_SHA256.items():
            with self.subTest(scenario=scenario_name):
                source = (ROOT / "supabase/tests/database" / scenario_name).read_text(encoding="utf-8")
                actual_digest = hashlib.sha256(source.encode("utf-8")).hexdigest()
                self.assertEqual(actual_digest, expected_digest)

    def test_smoke_preserves_authenticated_congregation_select(self):
        sql = (ROOT / "supabase/tests/database/public_intake_hosted_smoke_test.sql").read_text(
            encoding="utf-8")
        self.assertIn("NOT has_table_privilege('anon','public.congregations','SELECT')", sql)
        self.assertNotIn("NOT has_table_privilege('authenticated','public.congregations','SELECT')", sql)
        self.assertIn("has_table_privilege('authenticated','public.congregations','SELECT')", sql)

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

    def test_authority_scenario_baseline_ignores_absent_intake_schema(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            capture = directory / "calls.jsonl"
            fake = directory / "fake_psql.py"
            snapshot = {
                "counts": {"public.converts": 0, "public.ministry_people": 0,
                           "public.weekly_reports": 0, "private.mutation_receipts": 0,
                           "public.photo_assets": 0, "storage.objects": 0,
                           "auth.users": 0, "private.congregation_week_guards": 0,
                           "public.user_access": 0},
                "revisions": {"public.converts": {"max": 1, "distribution": {"1": 0}},
                              "public.ministry_people": {"max": 1, "distribution": {"1": 0}}},
                "settings": None,
                "grants": {"public.ieadpe_create_convert(uuid,jsonb).anon": False,
                           "public.ieadpe_create_convert(uuid,jsonb).authenticated": True},
                "migrations": ["202610250002"],
            }
            snapshot_json = json.dumps(snapshot)
            fake.write_text(
                "import json, os, sys\n"
                "from pathlib import Path\n"
                "with open(os.environ['FAKE_PSQL_CAPTURE'], 'a', encoding='utf-8') as f: "
                "f.write(json.dumps({'args':sys.argv[1:], 'stdin':sys.stdin.read(), 'connection_env':"
                "{key:os.environ.get(key) for key in ('PGHOST','PGPORT','PGUSER','PGPASSWORD','PGDATABASE',"
                "'PGSSLMODE','PGHOSTADDR','PGSERVICE','PGOPTIONS','PUBLIC_INTAKE_DATABASE_URL')}})+'\\n')\n"
                "print('FAKE_PRIVATE_QUERY_RESULT', file=sys.stderr)\n"
                "args=sys.argv[1:]\n"
                "sql=args[args.index('-c')+1] if '-c' in args else ''\n"
                "if 'private.public_intake_submissions' in sql: sys.exit(7)\n"
                "if 'supabase_migrations' in sql: sys.exit(8)\n"
                f"print({snapshot_json!r} if 'jsonb_build_object' in sql else ('t' if '-c' in args else ''))\n",
                encoding="utf-8")
            fake_supabase = directory / "fake_supabase.py"
            fake_supabase.write_text(
                "import json, os, sys\n"
                "args=sys.argv[1:]\n"
                "with open(os.environ['FAKE_SUPABASE_CAPTURE'], 'a', encoding='utf-8') as f: "
                "f.write(json.dumps(args)+'\\n')\n"
                "if args[:2] == ['projects','list']:\n"
                " print(json.dumps([{'id':'abcdefghijklmnopqrst'}]))\n"
                "elif args[:2] == ['migration','list']:\n"
                " print(json.dumps({'migrations':["
                "{'local':'202610250001','remote':'202610250001','time':'202610250001'},"
                "{'local':'202610250002','remote':'202610250002','time':'202610250002'},"
                "{'local':'202610250003','remote':'','time':''}]}))\n"
                "else: sys.exit(9)\n", encoding="utf-8")
            backup = self.make_backup(directory)
            evidence = directory / "evidence.json"
            run_id = "01234567-89ab-4cde-8fab-0123456789ab"
            env = os.environ.copy()
            env.update({
                "PUBLIC_INTAKE_TRUSTED_PROJECT_REF": "abcdefghijklmnopqrst",
                "SUPABASE_URL": "https://abcdefghijklmnopqrst.supabase.co",
                "PUBLIC_INTAKE_DATABASE_URL": (
                    "postgresql://cli_login_postgres.abcdefghijklmnopqrst:secret%40value@"
                    "aws-1-us-west-2.pooler.supabase.com:5432/postgres?sslmode=require"
                ),
                "FAKE_PSQL_CAPTURE": str(capture),
                "FAKE_SUPABASE_CAPTURE": str(directory / "supabase-calls.jsonl"),
                "PGHOST": "untrusted.example",
                "PGPORT": "6543",
                "PGUSER": "untrusted-user",
                "PGPASSWORD": "untrusted-password",
                "PGDATABASE": "untrusted-db",
                "PGSSLMODE": "disable",
                "PGHOSTADDR": "203.0.113.8",
                "PGSERVICE": "untrusted-service",
                "PGOPTIONS": "-c sslmode=disable",
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
            self.assertGreaterEqual(len(calls), 4)
            target_env = calls[0]["connection_env"]
            self.assertEqual(target_env, {
                "PGHOST": "aws-1-us-west-2.pooler.supabase.com",
                "PGPORT": "5432",
                "PGUSER": "cli_login_postgres.abcdefghijklmnopqrst",
                "PGPASSWORD": "secret@value",
                "PGDATABASE": "postgres",
                "PGSSLMODE": "require",
                "PGHOSTADDR": None,
                "PGSERVICE": None,
                "PGOPTIONS": None,
                "PUBLIC_INTAKE_DATABASE_URL": None,
            })
            self.assertNotIn("secret@value", " ".join(" ".join(call["args"]) for call in calls))
            scenario_call = calls[-2]
            self.assertIn("-c", " ".join(calls[0]["args"]))
            self.assertIn("-f", " ".join(scenario_call["args"]))
            baseline_call = next(call for call in calls if "'counts'" in call["args"][-1])
            self.assertNotIn("private.public_intake_", baseline_call["args"][-1])
            manifest = json.loads(evidence.read_text(encoding="utf-8"))
            self.assertEqual(manifest["applied_migrations"], ["202610250002"])
            self.assertEqual(manifest["baseline_scope"], "core-only")
            self.assertIn("authority scenario", manifest["baseline_note"])
            self.assertNotIn("postgresql://", " ".join(" ".join(call["args"]) for call in calls))
            self.assertFalse(any("supabase_migrations" in call["args"][-1] for call in calls))
            cli_calls = [json.loads(line) for line in
                         (directory / "supabase-calls.jsonl").read_text(encoding="utf-8").splitlines()]
            migration_call = next(args for args in cli_calls if args[:2] == ["migration", "list"])
            self.assertIn("--linked", migration_call)
            self.assertIn("--project-ref", migration_call)
            self.assertIn("abcdefghijklmnopqrst", migration_call)
            self.assertIn("--output-format", migration_call)
            self.assertIn("json", migration_call)
            self.assertNotIn("FAKE_PRIVATE_QUERY_RESULT", result.stdout + result.stderr)
            self.assertIn(run_id.replace("-", "")[8:], scenario_call["stdin"])
            self.assertNotIn("aa000000-0000-4000-8000-000000000001", scenario_call["stdin"])
            manifest_text = evidence.read_text(encoding="utf-8")
            self.assertNotIn("operator@", manifest_text)
            self.assertNotIn("sslmode", manifest_text)
            self.assertNotIn("example.test", manifest_text)
            self.assertIn("PASS", manifest_text)
            self.assertIn('"reconciled": true', manifest_text)
            self.assertIn("revisions", manifest["baseline"])
            self.assertIn("settings", manifest["baseline"])
            self.assertIn("grants", manifest["baseline"])
            self.assertIn("migrations", manifest["baseline"])
            ownership = manifest["run_ownership"]
            self.assertTrue(ownership["fixture_ids"])
            self.assertTrue(ownership["auth_user_ids"])
            self.assertTrue(ownership["operation_receipt_ids"])
            self.assertEqual(len(ownership["operation_receipt_ids"]), len(ownership["operation_receipts"]))
            self.assertEqual(ownership["persistent_rows_expected"], 0)

    def test_failed_or_malformed_cli_migration_inventory_writes_blocked_evidence(self):
        for mode in ("failed", "malformed"):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as temp:
                directory = Path(temp)
                psql_capture = directory / "psql-calls.jsonl"
                fake_psql = directory / "fake_psql.py"
                core_snapshot = {
                    "counts": {
                        "public.converts": 1, "public.ministry_people": 1,
                        "public.weekly_reports": 1, "private.mutation_receipts": 1,
                        "public.photo_assets": 1, "storage.objects": 1,
                        "auth.users": 1, "private.congregation_week_guards": 1,
                        "public.user_access": 1,
                    },
                    "revisions": {
                        "public.converts": {"max": 1, "distribution": {"1": 1}},
                        "public.ministry_people": {"max": 1, "distribution": {"1": 1}},
                    },
                    "settings": None, "grants": {},
                }
                fake_psql.write_text(
                    "import json, os, sys\n"
                    "args=sys.argv[1:]\n"
                    "sql=args[args.index('-c')+1] if '-c' in args else ''\n"
                    "with open(os.environ['FAKE_PSQL_CAPTURE'], 'a', encoding='utf-8') as f: "
                    "f.write(json.dumps({'args':args,'sql':sql})+'\\n')\n"
                    "if 'supabase_migrations' in sql: sys.exit(8)\n"
                    f"print({json.dumps(core_snapshot)!r} if \"'counts'\" in sql else 't')\n",
                    encoding="utf-8",
                )
                cli_capture = directory / "supabase-calls.jsonl"
                fake_supabase = directory / "fake_supabase.py"
                fake_supabase.write_text(
                    "import json, os, sys\n"
                    "args=sys.argv[1:]\n"
                    "with open(os.environ['FAKE_SUPABASE_CAPTURE'], 'a', encoding='utf-8') as f: "
                    "f.write(json.dumps(args)+'\\n')\n"
                    "if args[:2] == ['projects','list']:\n"
                    " print(json.dumps([{'id':'abcdefghijklmnopqrst'}]))\n"
                    "elif args[:2] == ['migration','list']:\n"
                    " if os.environ['FAKE_MIGRATION_MODE']=='failed': sys.exit(9)\n"
                    " print('not-json')\n"
                    "else: sys.exit(10)\n",
                    encoding="utf-8",
                )
                backup = self.make_backup(directory)
                evidence = directory / "evidence.json"
                env = os.environ.copy()
                env.update({
                    "PUBLIC_INTAKE_TRUSTED_PROJECT_REF": "abcdefghijklmnopqrst",
                    "SUPABASE_URL": "https://abcdefghijklmnopqrst.supabase.co",
                    "PUBLIC_INTAKE_DATABASE_URL": (
                        "postgresql://operator:fake-secret@db.abcdefghijklmnopqrst.supabase.co/"
                        "postgres?sslmode=require"
                    ),
                    "FAKE_PSQL_CAPTURE": str(psql_capture),
                    "FAKE_SUPABASE_CAPTURE": str(cli_capture),
                    "FAKE_MIGRATION_MODE": mode,
                })
                result = subprocess.run([
                    sys.executable, str(ROOT / "scripts/test_public_intake_hosted.py"),
                    "--project-ref", "abcdefghijklmnopqrst",
                    "--run-id", "01234567-89ab-4cde-8fab-0123456789ab",
                    "--scenario", "public_registration_authority_test.sql",
                    "--backup-manifest", str(backup), "--evidence-manifest", str(evidence),
                    "--psql-command-json", json.dumps([sys.executable, str(fake_psql)]),
                    "--supabase-command-json", json.dumps([sys.executable, str(fake_supabase)]),
                ], input="abcdefghijklmnopqrst\n", text=True, capture_output=True, env=env, cwd=ROOT)

                self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
                self.assertTrue(evidence.is_file())
                manifest = json.loads(evidence.read_text(encoding="utf-8"))
                self.assertEqual(manifest["status"], "BLOCKED")
                self.assertTrue(manifest["target_confirmed"])
                self.assertEqual(manifest["baseline_scope"], "core-only")
                self.assertFalse(manifest["migration_inventory_verified"])
                self.assertIsNone(manifest["baseline"]["migrations"])
                self.assertFalse(manifest["hosted_write_attempted"])
                self.assertFalse(manifest["scenario_dispatched"])
                self.assertIsNone(manifest["run_ownership"])
                self.assertIn("inventory", manifest["reason"].lower())
                psql_calls = [json.loads(line) for line in psql_capture.read_text(encoding="utf-8").splitlines()]
                self.assertTrue(psql_calls)
                self.assertFalse(any("supabase_migrations" in call["sql"] for call in psql_calls))
                self.assertFalse(any("-f" in call["args"] for call in psql_calls))

    def test_baseline_access_failure_writes_external_blocked_evidence_without_scenario(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            psql_capture = directory / "psql-calls.jsonl"
            cli_capture = directory / "supabase-calls.jsonl"
            fake_psql = directory / "fake_psql.py"
            fake_psql.write_text(
                "import json, os, sys\n"
                "args=sys.argv[1:]\n"
                "sql=args[args.index('-c')+1] if '-c' in args else ''\n"
                "with open(os.environ['FAKE_PSQL_CAPTURE'], 'a', encoding='utf-8') as f: "
                "f.write(json.dumps({'args':args,'sql':sql})+'\\n')\n"
                "if 'current_database()' in sql: print('t')\n"
                "else:\n"
                " print('permission denied for schema private', file=sys.stderr)\n"
                " sys.exit(7)\n",
                encoding="utf-8",
            )
            fake_supabase = directory / "fake_supabase.py"
            fake_supabase.write_text(
                "import json, os, sys\n"
                "args=sys.argv[1:]\n"
                "with open(os.environ['FAKE_SUPABASE_CAPTURE'], 'a', encoding='utf-8') as f: "
                "f.write(json.dumps(args)+'\\n')\n"
                "if args[:2] == ['projects','list']: "
                "print(json.dumps([{'id':'abcdefghijklmnopqrst'}]))\n"
                "elif args[:2] == ['migration','list']: "
                "print(json.dumps({'migrations':[]}))\n"
                "else: sys.exit(9)\n",
                encoding="utf-8",
            )
            backup = self.make_backup(directory)
            evidence = directory / "baseline-denied.json"
            env = os.environ.copy()
            env.update({
                "PUBLIC_INTAKE_TRUSTED_PROJECT_REF": "abcdefghijklmnopqrst",
                "SUPABASE_URL": "https://abcdefghijklmnopqrst.supabase.co",
                "PUBLIC_INTAKE_DATABASE_URL": (
                    "postgresql://operator:fake-secret@db.abcdefghijklmnopqrst.supabase.co/"
                    "postgres?sslmode=require"
                ),
                "FAKE_PSQL_CAPTURE": str(psql_capture),
                "FAKE_SUPABASE_CAPTURE": str(cli_capture),
            })
            result = subprocess.run([
                sys.executable, str(ROOT / "scripts/test_public_intake_hosted.py"),
                "--project-ref", "abcdefghijklmnopqrst",
                "--run-id", "01234567-89ab-4cde-8fab-0123456789ab",
                "--scenario", "public_registration_authority_test.sql",
                "--backup-manifest", str(backup), "--evidence-manifest", str(evidence),
                "--psql-command-json", json.dumps([sys.executable, str(fake_psql)]),
                "--supabase-command-json", json.dumps([sys.executable, str(fake_supabase)]),
            ], input="abcdefghijklmnopqrst\n", text=True, capture_output=True, env=env, cwd=ROOT)

            self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
            self.assertTrue(evidence.is_file())
            manifest = json.loads(evidence.read_text(encoding="utf-8"))
            self.assertEqual(manifest["status"], "BLOCKED")
            self.assertTrue(manifest["target_confirmed"])
            self.assertEqual(manifest["baseline"], None)
            self.assertEqual(manifest["baseline_scope"], "unavailable")
            self.assertEqual(manifest["blocker_code"], "baseline_unavailable")
            self.assertFalse(manifest["hosted_write_attempted"])
            self.assertFalse(manifest["scenario_dispatched"])
            self.assertIsNone(manifest["run_ownership"])
            self.assertFalse(manifest["migration_inventory_verified"])
            self.assertNotIn("permission denied", evidence.read_text(encoding="utf-8"))
            psql_calls = [json.loads(line) for line in psql_capture.read_text(encoding="utf-8").splitlines()]
            self.assertEqual(len(psql_calls), 2)
            self.assertFalse(any("-f" in call["args"] for call in psql_calls))
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
                "PUBLIC_INTAKE_DATABASE_URL": "postgresql://operator:fake-secret@db.abcdefghijklmnopqrst.supabase.co/postgres?sslmode=require",
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

    def test_short_t2_smoke_preflights_and_records_rollback_evidence(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            capture = directory / "psql-calls.jsonl"
            fake_psql = directory / "fake_psql.py"
            snapshot = {
                "counts": {
                    "public.converts": 4, "public.ministry_people": 4,
                    "public.weekly_reports": 2, "private.mutation_receipts": 5,
                    "public.photo_assets": 1, "storage.objects": 1,
                    "auth.users": 6, "private.congregation_week_guards": 3,
                    "public.user_access": 6, "private.public_intake_submissions": 3,
                    "private.public_intake_receipts": 3, "private.public_intake_decisions": 1,
                    "private.public_intake_accepted_events": 3,
                },
                "revisions": {
                    "public.converts": {"max": 2, "distribution": {"1": 3, "2": 1}},
                    "public.ministry_people": {"max": 1, "distribution": {"1": 4}},
                    "private.public_intake_submissions": {"max": 1, "distribution": {"1": 3}},
                },
                "settings": {"enabled": True, "global_pending_limit": 1000},
                "grants": {
                    "public.ieadpe_create_convert(uuid,jsonb).anon": False,
                    "public.ieadpe_create_convert(uuid,jsonb).authenticated": True,
                    "public.ieadpe_create_convert(uuid,jsonb).service_role": True,
                    "public.ieadpe_create_photo_draft(uuid,jsonb).anon": False,
                    "public.ieadpe_create_photo_draft(uuid,jsonb).authenticated": True,
                    "public.ieadpe_create_photo_draft(uuid,jsonb).service_role": True,
                    "public.ieadpe_receive_public_intake(jsonb).anon": False,
                    "public.ieadpe_receive_public_intake(jsonb).authenticated": False,
                    "public.ieadpe_receive_public_intake(jsonb).service_role": True,
                    "public.ieadpe_public_congregations(jsonb).anon": True,
                    "public.ieadpe_public_congregations(jsonb).authenticated": True,
                    "public.ieadpe_public_congregations(jsonb).service_role": False,
                    "private.public_intake_submissions.anon.select": False,
                    "private.public_intake_submissions.authenticated.select": False,
                    "private.public_intake_submissions.service_role.select": False,
                    "private.public_intake_receipts.anon.select": False,
                    "private.public_intake_receipts.authenticated.select": False,
                    "private.public_intake_receipts.service_role.select": False,
                    "private.public_intake_accepted_events.anon.select": False,
                    "private.public_intake_accepted_events.authenticated.select": False,
                    "private.public_intake_accepted_events.service_role.select": False,
                    "private.public_intake_decisions.anon.select": False,
                    "private.public_intake_decisions.authenticated.select": False,
                    "private.public_intake_decisions.service_role.select": False,
                },
                "migrations": ["202610250002", "202610250003"],
            }
            preflight = {
                "two_slot_capacity_headroom": True, "intake_enabled": True,
                "submission_id_unused": True, "network_hash_unused": True,
                "cleanup_candidates_absent": True,
                "active_congregation_available": True,
            }
            fake_psql.write_text(
                "import json, sys\n"
                "stdin=sys.stdin.read()\n"
                "with open(__import__('os').environ['FAKE_PSQL_CAPTURE'], 'a', encoding='utf-8') as f: "
                "f.write(json.dumps({'args':sys.argv[1:], 'stdin':stdin})+'\\n')\n"
                "args=sys.argv[1:]\n"
                "sql=args[args.index('-c')+1] if '-c' in args else ''\n"
                f"print({json.dumps(preflight)!r} if 'two_slot_capacity_headroom' in sql else "
                f"({json.dumps(snapshot)!r} if \"'counts'\" in sql else "
                "('t' if '-c' in args else (__import__('os').environ.get('FAKE_SMOKE_RESULT', 'T2_SMOKE_PASS') "
                "if 'pg_temp.run_smoke();' in stdin else ''))))\n",
                encoding="utf-8",
            )
            fake_supabase = directory / "fake_supabase.py"
            fake_supabase.write_text(
                "import json, sys\n"
                "args=sys.argv[1:]\n"
                "if args[:2] == ['projects','list']:\n"
                " print(json.dumps([{'id':'abcdefghijklmnopqrst'}]))\n"
                "elif args[:2] == ['migration','list']:\n"
                " print(json.dumps({'migrations':["
                "{'local':'202610250002','remote':'202610250002','time':'202610250002'},"
                "{'local':'202610250003','remote':'202610250003','time':'202610250003'}]}))\n"
                "else: sys.exit(9)\n",
                encoding="utf-8",
            )
            backup = self.make_backup(directory)
            evidence = directory / "t2-smoke-evidence.json"
            run_id = "01234567-89ab-4cde-8fab-0123456789ab"
            env = os.environ.copy()
            env.update({
                "PUBLIC_INTAKE_TRUSTED_PROJECT_REF": "abcdefghijklmnopqrst",
                "SUPABASE_URL": "https://abcdefghijklmnopqrst.supabase.co",
                "PUBLIC_INTAKE_DATABASE_URL": "postgresql://operator:fake-secret@db.abcdefghijklmnopqrst.supabase.co/postgres?sslmode=require",
                "FAKE_PSQL_CAPTURE": str(capture),
            })
            result = subprocess.run([
                sys.executable, str(ROOT / "scripts/test_public_intake_hosted.py"),
                "--project-ref", "abcdefghijklmnopqrst", "--run-id", run_id,
                "--scenario", "public_intake_hosted_smoke_test.sql",
                "--backup-manifest", str(backup), "--evidence-manifest", str(evidence),
                "--psql-command-json", json.dumps([sys.executable, str(fake_psql)]),
                "--supabase-command-json", json.dumps([sys.executable, str(fake_supabase)]),
            ], input="abcdefghijklmnopqrst\n", text=True, capture_output=True, env=env, cwd=ROOT)
            self.assertEqual(result.returncode, 0, result.stderr)
            calls = [json.loads(line) for line in capture.read_text(encoding="utf-8").splitlines()]
            self.assertEqual(len(calls), 6)
            self.assertIn("current_database()", calls[0]["args"][-1])
            self.assertIn("'counts'", calls[1]["args"][-1])
            self.assertFalse(any(
                "supabase_migrations" in " ".join(call["args"]) for call in calls
            ))
            self.assertIn("'counts'", calls[2]["args"][-1])
            self.assertIn("two_slot_capacity_headroom", calls[3]["args"][-1])
            self.assertIn("+ 1 < s.global_pending_limit", calls[3]["args"][-1])
            self.assertIn("cleanup_candidates_absent", calls[3]["args"][-1])
            owned_id = runner._run_owned_uuid(run_id, runner.T2_SMOKE_SUBMISSION_PLACEHOLDER)
            owned_network = hashlib.sha256(
                f"public-intake-hosted-smoke:{owned_id}".encode("utf-8")).hexdigest()
            self.assertIn(owned_id, calls[3]["args"][-1])
            self.assertIn(owned_network, calls[3]["args"][-1])
            self.assertIn("-f", calls[4]["args"])
            self.assertIn("'counts'", calls[5]["args"][-1])
            scenario = calls[4]["stdin"]
            self.assertTrue(scenario.startswith("BEGIN;"))
            self.assertTrue(scenario.rstrip().endswith("ROLLBACK;"))
            self.assertEqual(scenario.count("first_response:=public.ieadpe_receive_public_intake("), 1)
            self.assertEqual(scenario.count("replay_response:=public.ieadpe_receive_public_intake("), 1)
            self.assertIn("SELECT pg_temp.run_smoke();", scenario)
            self.assertNotIn("TRUNCATE", scenario.upper())
            self.assertNotIn("operator@", " ".join(" ".join(call["args"]) for call in calls))
            manifest = json.loads(evidence.read_text(encoding="utf-8"))
            self.assertEqual(manifest["status"], "PASS")
            self.assertTrue(manifest["reconciled"])
            self.assertTrue(manifest["hosted_preflight"]["two_slot_capacity_headroom"])
            self.assertEqual(manifest["run_ownership"]["persistent_rows_expected"], 0)
            self.assertTrue(manifest["run_ownership"]["fixture_ids"])
            self.assertEqual(manifest["run_ownership"]["auth_user_ids"], [])
            self.assertEqual(manifest["run_ownership"]["operation_receipt_ids"], [])
            owned_intake_receipt = runner._run_owned_uuid(
                run_id, runner.T2_SMOKE_SUBMISSION_PLACEHOLDER)
            self.assertEqual(manifest["run_ownership"]["intake_receipt_ids"],
                             [owned_intake_receipt])
            self.assertEqual(manifest["run_ownership"]["intake_receipts"], [{
                "table": "private.public_intake_receipts",
                "submission_id": owned_intake_receipt,
                "persistent_after_rollback": False,
            }])
            self.assertNotIn("operator@", evidence.read_text(encoding="utf-8"))
            self.assertNotIn("sslmode", evidence.read_text(encoding="utf-8"))

            blocked_evidence = directory / "t2-smoke-lock-blocked.json"
            env["FAKE_SMOKE_RESULT"] = "T2_SMOKE_BLOCKED:lock_timeout"
            blocked_result = subprocess.run([
                sys.executable, str(ROOT / "scripts/test_public_intake_hosted.py"),
                "--project-ref", "abcdefghijklmnopqrst", "--run-id", run_id,
                "--scenario", "public_intake_hosted_smoke_test.sql",
                "--backup-manifest", str(backup), "--evidence-manifest", str(blocked_evidence),
                "--psql-command-json", json.dumps([sys.executable, str(fake_psql)]),
                "--supabase-command-json", json.dumps([sys.executable, str(fake_supabase)]),
            ], input="abcdefghijklmnopqrst\n", text=True, capture_output=True, env=env, cwd=ROOT)
            self.assertEqual(blocked_result.returncode, 2)
            blocked_manifest = json.loads(blocked_evidence.read_text(encoding="utf-8"))
            self.assertEqual(blocked_manifest["status"], "BLOCKED")
            self.assertIn("lock_timeout", blocked_manifest["reason"])
            self.assertTrue(blocked_manifest["reconciled"])
            self.assertIn("rollback", blocked_manifest["cleanup_outcome"].lower())

    def test_t2_smoke_capacity_preflight_writes_blocked_manifest_before_scenario(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            capture = directory / "psql-calls.jsonl"
            fake_psql = directory / "fake_psql.py"
            snapshot = {
                "counts": {"public.converts": 0, "public.ministry_people": 0,
                           "public.weekly_reports": 0, "private.mutation_receipts": 0,
                           "public.photo_assets": 0, "storage.objects": 0, "auth.users": 0,
                           "private.congregation_week_guards": 0, "public.user_access": 0,
                           "private.public_intake_submissions": 0, "private.public_intake_receipts": 0,
                           "private.public_intake_decisions": 0, "private.public_intake_accepted_events": 0},
                "revisions": {"public.converts": {"max": 0, "distribution": {}},
                              "public.ministry_people": {"max": 0, "distribution": {}},
                              "private.public_intake_submissions": {"max": 0, "distribution": {}}},
                "settings": {"enabled": True, "global_pending_limit": 1},
                "grants": {}, "migrations": ["202610250002", "202610250003"],
            }
            preflight = {
                "two_slot_capacity_headroom": False, "intake_enabled": True,
                "submission_id_unused": True, "network_hash_unused": True,
                "cleanup_candidates_absent": True,
                "active_congregation_available": True,
            }
            fake_psql.write_text(
                "import json, sys\n"
                "with open(__import__('os').environ['FAKE_PSQL_CAPTURE'], 'a', encoding='utf-8') as f: "
                "f.write(json.dumps({'args':sys.argv[1:], 'stdin':sys.stdin.read()})+'\\n')\n"
                "args=sys.argv[1:]\n"
                "sql=args[args.index('-c')+1] if '-c' in args else ''\n"
                f"print({json.dumps(preflight)!r} if 'two_slot_capacity_headroom' in sql else "
                f"({json.dumps(snapshot)!r} if \"'counts'\" in sql else "
                "('t' if '-c' in args else '')))\n",
                encoding="utf-8",
            )
            fake_supabase = directory / "fake_supabase.py"
            fake_supabase.write_text(
                "import json, sys\n"
                "args=sys.argv[1:]\n"
                "if args[:2] == ['projects','list']:\n"
                " print(json.dumps([{'id':'abcdefghijklmnopqrst'}]))\n"
                "elif args[:2] == ['migration','list']:\n"
                " print(json.dumps({'migrations':["
                "{'local':'202610250002','remote':'202610250002','time':'202610250002'},"
                "{'local':'202610250003','remote':'202610250003','time':'202610250003'}]}))\n"
                "else: sys.exit(9)\n",
                encoding="utf-8",
            )
            backup = self.make_backup(directory)
            evidence = directory / "blocked-headroom.json"
            env = os.environ.copy()
            env.update({
                "PUBLIC_INTAKE_TRUSTED_PROJECT_REF": "abcdefghijklmnopqrst",
                "SUPABASE_URL": "https://abcdefghijklmnopqrst.supabase.co",
                "PUBLIC_INTAKE_DATABASE_URL": "postgresql://operator:fake-secret@db.abcdefghijklmnopqrst.supabase.co/postgres?sslmode=require",
                "FAKE_PSQL_CAPTURE": str(capture),
            })
            result = subprocess.run([
                sys.executable, str(ROOT / "scripts/test_public_intake_hosted.py"),
                "--project-ref", "abcdefghijklmnopqrst", "--run-id", str(uuid.uuid4()),
                "--scenario", "public_intake_hosted_smoke_test.sql",
                "--backup-manifest", str(backup), "--evidence-manifest", str(evidence),
                "--psql-command-json", json.dumps([sys.executable, str(fake_psql)]),
                "--supabase-command-json", json.dumps([sys.executable, str(fake_supabase)]),
            ], input="abcdefghijklmnopqrst\n", text=True, capture_output=True, env=env, cwd=ROOT)
            self.assertNotEqual(result.returncode, 0)
            calls = [json.loads(line) for line in capture.read_text(encoding="utf-8").splitlines()]
            self.assertEqual(len(calls), 4)
            self.assertNotIn("-f", calls[-1]["args"])
            manifest = json.loads(evidence.read_text(encoding="utf-8"))
            self.assertEqual(manifest["status"], "BLOCKED")
            self.assertFalse(manifest["hosted_write_attempted"])
            self.assertTrue(manifest["hosted_subprocesses_invoked"])
            self.assertEqual(manifest["hosted_preflight"]["two_slot_capacity_headroom"], False)
            self.assertIn("capacity", manifest["reason"].lower())
            self.assertEqual(manifest["run_ownership"]["persistent_rows_expected"], 0)

    def test_t2_capacity_scenario_and_concurrency_write_blocked_evidence_without_subprocesses(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            psql_marker = directory / "psql-called"
            fake = directory / "fake_psql.py"
            fake.write_text(
                "from pathlib import Path\n"
                f"Path({str(psql_marker)!r}).write_text('called')\n", encoding="utf-8")
            supabase_marker = directory / "supabase-called"
            fake_supabase = directory / "fake_supabase.py"
            fake_supabase.write_text(
                "from pathlib import Path\n"
                f"Path({str(supabase_marker)!r}).write_text('called')\n", encoding="utf-8")
            backup = self.make_backup(directory)
            env = os.environ.copy()
            env.update({
                "PUBLIC_INTAKE_TRUSTED_PROJECT_REF": "abcdefghijklmnopqrst",
                "SUPABASE_URL": "https://abcdefghijklmnopqrst.supabase.co",
                "PUBLIC_INTAKE_DATABASE_URL": "postgresql://operator@db.abcdefghijklmnopqrst.supabase.co/postgres?sslmode=require",
            })
            for suffix, extra_args in (("scenario", []), ("concurrency", ["--concurrency"])):
                psql_marker.unlink(missing_ok=True)
                supabase_marker.unlink(missing_ok=True)
                evidence = directory / f"{suffix}-blocked.json"
                args = [
                    sys.executable, str(ROOT / "scripts/test_public_intake_hosted.py"),
                    "--project-ref", "abcdefghijklmnopqrst", "--run-id", str(uuid.uuid4()),
                    "--scenario", "public_intake_test.sql", *extra_args,
                    "--backup-manifest", str(backup), "--evidence-manifest", str(evidence),
                    "--psql-command-json", json.dumps([sys.executable, str(fake)]),
                    "--supabase-command-json", json.dumps([sys.executable, str(fake_supabase)]),
                ]
                result = subprocess.run(args, text=True, capture_output=True, env=env, cwd=ROOT)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(psql_marker.exists())
                self.assertFalse(supabase_marker.exists())
                self.assertIn("BLOCKED", result.stdout + result.stderr)
                manifest = json.loads(evidence.read_text(encoding="utf-8"))
                self.assertEqual(manifest["status"], "BLOCKED")
                self.assertFalse(manifest["hosted_subprocesses_invoked"])
                self.assertFalse(manifest["hosted_write_attempted"])
                self.assertTrue(manifest["reason"])


if __name__ == "__main__":
    unittest.main()
