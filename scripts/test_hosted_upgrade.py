"""Behavioral safety tests for the hosted upgrade preparation CLIs."""
import hashlib
import json
import os
import stat
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import rehearse_hosted_upgrade as rehearsal
import inspect_hosted_contracts as inspector
try:
    import migration_semantic_manifest as semantic_manifest
except ImportError:
    semantic_manifest = None


class HostedUpgradePreparationTests(unittest.TestCase):
    def run_cli(self, script, *args):
        return subprocess.run(
            [sys.executable, str(ROOT / "scripts" / script), *args],
            cwd=ROOT,
            text=True,
            capture_output=True,
            timeout=20,
        )

    def test_rehearsal_rejects_non_loopback_before_connecting(self):
        result = self.run_cli(
            "rehearse_hosted_upgrade.py",
            "--database-url",
            "postgresql://tester@db.example.invalid/app",
            "--output",
            "unused.json",
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("loopback", (result.stderr + result.stdout).lower())

    def test_inventory_requires_explicit_project_and_output(self):
        result = self.run_cli("inspect_hosted_contracts.py")
        self.assertEqual(result.returncode, 2)
        self.assertIn("--project-ref", result.stderr)
        self.assertIn("--output", result.stderr)

    def test_rehearsal_emits_exact_sequence_and_repair_proposal_without_applying(self):
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_cli(
                "rehearse_hosted_upgrade.py",
                "--plan-only",
                "--output",
                str(Path(directory) / "plan.json"),
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            report = json.loads((Path(directory) / "plan.json").read_text())
        versions = [item["version"] for item in report["migration_sequence"]]
        self.assertEqual(versions, [
            "202610180003",
            "202610190001", "202610190002", "202610190003", "202610190004",
            "202610190005", "202610190006", "202610190007", "202610190008",
            "202610190009",
            "202610200001", "202610200002", "202610200003", "202610200004",
            "202610200005", "202610200006",
        ])
        self.assertEqual(report["migration_sequence"][-1]["filename"],
                         "202610200006_attendance_roster_preview.sql")
        source = ROOT / "supabase/migrations/202610200006_attendance_roster_preview.sql"
        self.assertEqual(report["migration_sequence"][-1]["sha256"],
                         hashlib.sha256(source.read_bytes()).hexdigest())
        self.assertTrue(report["ledger_repair_proposal"]["review_required"])
        self.assertFalse(report["effects"]["ledger_repaired"])
        self.assertFalse(report["effects"]["migrations_applied"])


    def test_rehearsal_sanitizes_every_libpq_target_override(self):
        sanitizer = getattr(rehearsal, "sanitize_libpq_environment", None)
        self.assertTrue(callable(sanitizer), "missing libpq environment sanitizer")
        source = {
            "PATH": "/safe/bin", "PGHOST": "203.0.113.8", "PGHOSTADDR": "127.0.0.2",
            "PGPORT": "6543", "PGSERVICE": "attacker", "PGSERVICEFILE": "/tmp/attacker.conf",
            "PGOPTIONS": "-c search_path=attacker", "PGDATABASE": "attacker",
            "PGUSER": "attacker", "IEADPE_DATABASE_URL": "attacker",
        }
        safe = sanitizer("postgresql://tester@127.0.0.1:54329/postgres", source)
        self.assertEqual(safe["PATH"], "/safe/bin")
        self.assertEqual(safe["IEADPE_DATABASE_URL"], "postgresql://tester@127.0.0.1:54329/postgres")
        self.assertFalse(any(key.startswith("PG") for key in safe))

    def test_poisoned_libpq_environment_never_reaches_psql_or_executes_sql(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            capture = directory / "invocations.jsonl"
            fake_psql = directory / "psql"
            fake_psql.write_text(
                "#!/usr/bin/env python3\n"
                "import json, os, sys\n"
                f"open({str(capture)!r}, 'a').write(json.dumps({{'args':sys.argv[1:], 'pg':{{k:v for k,v in os.environ.items() if k.startswith('PG')}}}})+'\\n')\n"
                "raise SystemExit(78)\n",
                encoding="utf-8",
            )
            fake_psql.chmod(fake_psql.stat().st_mode | stat.S_IXUSR)
            env = os.environ.copy()
            env.update({
                "PATH": str(directory) + os.pathsep + env.get("PATH", ""),
                "PGHOST": "203.0.113.8", "PGHOSTADDR": "127.0.0.2", "PGPORT": "6543",
                "PGSERVICE": "attacker", "PGSERVICEFILE": str(directory / "attacker.conf"),
                "PGOPTIONS": "-c search_path=attacker",
            })
            result = subprocess.run(
                [sys.executable, str(ROOT / "scripts" / "rehearse_hosted_upgrade.py"),
                 "--database-url", "postgresql://tester@127.0.0.1:54329/postgres",
                 "--output", str(directory / "report.json")],
                cwd=ROOT, env=env, text=True, capture_output=True, timeout=20,
            )
            self.assertNotEqual(result.returncode, 0)
            calls = [json.loads(line) for line in capture.read_text().splitlines()]
            self.assertTrue(calls)
            self.assertTrue(all(call["pg"] == {} for call in calls))
            self.assertTrue(all("203.0.113." not in " ".join(call["args"]) for call in calls))
            self.assertTrue(all("127.0.0.2" not in " ".join(call["args"]) for call in calls))
            self.assertTrue(all(any(arg == "postgresql://tester@127.0.0.1:54329/postgres" for arg in call["args"])
                                or any("127.0.0.1" in arg for arg in call["args"]) for call in calls))

    def test_rehearsal_rejects_connection_string_override_and_password(self):
        for value in (
            "postgresql://tester@127.0.0.1:54329/postgres?hostaddr=203.0.113.8",
            "postgresql://tester:password@127.0.0.1:54329/postgres",
        ):
            with self.subTest(value=value):
                with self.assertRaises(ValueError):
                    rehearsal.sanitize_libpq_environment(value, {"PGHOSTADDR": "203.0.113.8"})

    def test_catalog_resume_fingerprint_fails_closed_on_drift(self):
        check = getattr(rehearsal, "require_catalog_fingerprint_match", None)
        self.assertTrue(callable(check), "missing catalog fingerprint drift guard")
        self.assertTrue(check("fingerprint-a", "fingerprint-a"))
        with self.assertRaisesRegex(ValueError, "catalog drift"):
            check("fingerprint-a", "fingerprint-b")

    def test_partial_resume_skips_only_matching_prefix_and_rejects_catalog_drift(self):
        planner = getattr(rehearsal, "build_migration_resume_plan", None)
        self.assertTrue(callable(planner), "missing migration resume/drift planner")
        expected = [{"version": "v1", "sha256": "a"}, {"version": "v2", "sha256": "b"},
                    {"version": "v3", "sha256": "c"}]
        plan = planner(expected, {"v1": "a"})
        self.assertEqual([item["version"] for item in plan], ["v2", "v3"])
        with self.assertRaisesRegex(ValueError, "drift"):
            planner(expected, {"v1": "a", "v2": "tampered"})
        with self.assertRaisesRegex(ValueError, "gap"):
            planner(expected, {"v2": "b"})

    def test_exact_sequence_accepts_all_sixteen_authoritative_sources(self):
        sequence = rehearsal.migration_sequence()
        self.assertEqual(len(sequence), 16)
        self.assertEqual(sequence[-1]["filename"], "202610200006_attendance_roster_preview.sql")
        source = ROOT / "supabase" / "migrations" / sequence[-1]["filename"]
        self.assertEqual(sequence[-1]["sha256"], hashlib.sha256(source.read_bytes()).hexdigest())

    def test_exact_sequence_rejects_missing_gap_duplicate_and_extra_sources(self):
        import tempfile
        original = rehearsal.MIGRATIONS
        names = ["202610180003_base.sql", *(f"20261019{i:04d}_m.sql" for i in range(1, 10)),
                 *(f"20261020{i:04d}_m.sql" for i in range(1, 7))]
        try:
            with tempfile.TemporaryDirectory() as directory:
                folder = Path(directory)
                rehearsal.MIGRATIONS = folder
                for name in names:
                    (folder / name).write_text("-- synthetic source\n", encoding="utf-8")
                self.assertEqual(len(rehearsal.migration_sequence()), 16)
                (folder / names[-1]).unlink()
                with self.assertRaisesRegex(ValueError, "incomplete|unexpected"):
                    rehearsal.migration_sequence()
                (folder / "202610200007_m.sql").write_text("-- unexpected\n", encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "incomplete|unexpected"):
                    rehearsal.migration_sequence()
                (folder / "202610200007_m.sql").unlink()
                (folder / names[-1]).write_text("-- synthetic source\n", encoding="utf-8")
                (folder / "202610200006_duplicate.sql").write_text("-- duplicate\n", encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "incomplete|unexpected"):
                    rehearsal.migration_sequence()
                (folder / "202610200006_duplicate.sql").unlink()
                (folder / names[10]).rename(folder / "202610200000_gap.sql")
                with self.assertRaisesRegex(ValueError, "incomplete|unexpected"):
                    rehearsal.migration_sequence()
        finally:
            rehearsal.MIGRATIONS = original

    def test_resume_accepts_005_prefix_and_final_006_prefix_only(self):
        sequence = rehearsal.migration_sequence()
        ledger_005 = {item["version"]: item["sha256"] for item in sequence[:-1]}
        pending = rehearsal.build_migration_resume_plan(sequence, ledger_005)
        self.assertEqual([item["version"] for item in pending], ["202610200006"])
        ledger_006 = {item["version"]: item["sha256"] for item in sequence}
        self.assertEqual(rehearsal.build_migration_resume_plan(sequence, ledger_006), [])
        wrong_006 = dict(ledger_005, **{"202610200006": "0" * 64})
        with self.assertRaisesRegex(ValueError, "checksum drift"):
            rehearsal.build_migration_resume_plan(sequence, wrong_006)
        with self.assertRaisesRegex(ValueError, "gap"):
            rehearsal.build_migration_resume_plan(sequence, {sequence[-1]["version"]: sequence[-1]["sha256"]})
        with self.assertRaisesRegex(ValueError, "outside"):
            rehearsal.build_migration_resume_plan(sequence, dict(ledger_006, **{"202610200007": "a" * 64}))

    def test_plan_records_working_tree_candidate_digests(self):
        builder = getattr(rehearsal, "build_candidate_provenance", None)
        self.assertTrue(callable(builder), "missing working-tree candidate provenance")
        provenance = builder([ROOT / "scripts" / "rehearse_hosted_upgrade.py"])
        entry = provenance["files"]["scripts/rehearse_hosted_upgrade.py"]
        self.assertEqual(len(entry["sha256"]), 64)
        self.assertTrue(entry["working_tree"])
        complete = builder()
        self.assertNotIn("docs/verification/ministry-corrective-activation-package.md", complete["files"])
        self.assertEqual(len(complete["candidate_sha256"]), 64)

    def test_rehearsal_command_uses_180002_seed_and_exact_following_chain(self):
        builder = getattr(rehearsal, "build_local_rehearsal_command", None)
        self.assertTrue(callable(builder), "missing synthetic baseline rehearsal command")
        command = builder("postgresql://postgres@127.0.0.1:54329/postgres", "/tmp/report.json")
        self.assertIn("202610180002_base44_archive_weekly_consistency.sql", command)
        self.assertIn("t12_pre_180002_rehearsal.sql", command)
        self.assertIn("t12_post_forward_rehearsal.sql", command)
        self.assertIn("--verify-after-migration", command)
        self.assertIn("t12_post_180002_baseline.sql", command)
        self.assertIn("--t12-resume-and-drift", command)
        self.assertIn("--t12-semantic-snapshots", command)

    def test_project_endpoint_is_bound_to_project_ref(self):
        validator = getattr(inspector, "validate_project_endpoint", None)
        self.assertTrue(callable(validator), "missing verifiable endpoint binding")
        self.assertEqual(
            validator("voqmtnqjrbugpazcimvh", "db.voqmtnqjrbugpazcimvh.supabase.co"),
            "db.voqmtnqjrbugpazcimvh.supabase.co",
        )
        with self.assertRaises(ValueError):
            validator("voqmtnqjrbugpazcimvh", "db.some-other-project.supabase.co")
        with self.assertRaises(ValueError):
            validator("voqmtnqjrbugpazcimvh", "pooler.supabase.com")

    def test_migration_classifier_requires_full_semantic_equivalence(self):
        classify = getattr(inspector, "classify_migration_version", None)
        self.assertTrue(callable(classify), "missing per-version semantic classifier")
        expected = {"columns": {"public.t.id": "uuid"}, "constraints": {"t_pk": "primary"},
                    "indexes": {"t_pk": "unique"}, "policies": {"public.t": {"t_scope": "qual-hash"}},
                    "functions": {"f()": {"definition_fingerprint": "definition-sha", "security_definer": True}},
                    "rls": {"public.t": {"enabled": True, "forced": False}},
                    "table_grants": {"public.t": {"authenticated": ["select"]}},
                    "function_grants": {"public.f()": {"authenticated": ["execute"]}},
                    "data_invariants": {"count": 4}}
        self.assertEqual(classify(True, expected, expected), "recorded+present")
        self.assertEqual(classify(False, expected, expected), "unrecorded+fully-equivalent")
        self.assertEqual(classify(False, expected, {key: {} for key in expected}), "absent")
        partial = dict(expected, indexes={})
        self.assertEqual(classify(True, expected, partial), "partial/conflicting")
        self.assertEqual(classify(True, expected, {key: {} for key in expected}), "partial/conflicting")
        for category in expected:
            changed = dict(expected)
            changed[category] = dict(expected[category])
            if changed[category]:
                first = next(iter(changed[category]))
                changed[category][first] = "deliberate-catalog-drift"
            else:
                changed[category]["unexpected"] = "drift"
            self.assertEqual(classify(True, expected, changed), "partial/conflicting", category)
        unexpected_grant = json.loads(json.dumps(expected))
        unexpected_grant["table_grants"]["public.t"]["anon"] = ["select"]
        self.assertEqual(classify(False, expected, unexpected_grant), "partial/conflicting")
        unexpected_policy = json.loads(json.dumps(expected))
        unexpected_policy["policies"]["public.t"]["unexpected_public_read"] = "policy-fingerprint"
        self.assertEqual(classify(False, expected, unexpected_policy), "partial/conflicting")

    def test_catalog_grants_and_policies_are_exact_per_owned_target(self):
        expected = {key: {} for key in inspector.CONTRACT_KEYS}
        expected["table_grants"] = {"private.snapshot": {"authenticated": []}}
        expected["policies"] = {"public.converts": {"converts_scope": {
            "command": "SELECT", "roles": ["authenticated"], "qual_fingerprint": "q",
            "check_fingerprint": "c"}}}
        observed = {key: {} for key in inspector.CONTRACT_KEYS}
        raw = {
            "table_grants": [
                {"schema": "private", "table": "snapshot", "grantee": "authenticated", "privilege": "SELECT"},
                {"schema": "private", "table": "snapshot", "grantee": "anon", "privilege": "SELECT"}],
            "policies": [
                {"schema": "public", "table": "converts", "name": "converts_scope", "command": "SELECT",
                 "roles": ["authenticated"], "qual_fingerprint": "q", "check_fingerprint": "c"},
                {"schema": "public", "table": "converts", "name": "unexpected_public_read", "command": "SELECT",
                 "roles": ["PUBLIC"], "qual_fingerprint": "true", "check_fingerprint": ""}],
        }
        observed.update(inspector.catalog_as_contract(raw))
        self.assertEqual(inspector.classify_migration_version(False, expected, observed), "partial/conflicting")
        self.assertIn("anon", observed["table_grants"]["private.snapshot"])
        self.assertIn("unexpected_public_read", observed["policies"]["public.converts"])

    def test_function_grants_normalize_by_signature_not_oid(self):
        raw_a = {"function_grants": [{"routine_schema": "public", "routine_name": "f",
            "identity_arguments": "uuid", "specific_name": "f_123", "grantee": "authenticated",
            "privilege": "EXECUTE"}]}
        raw_b = {"function_grants": [{"routine_schema": "public", "routine_name": "f",
            "identity_arguments": "uuid", "specific_name": "f_999", "grantee": "authenticated",
            "privilege": "EXECUTE"}]}
        self.assertEqual(inspector.catalog_as_contract(raw_a)["function_grants"],
                         inspector.catalog_as_contract(raw_b)["function_grants"])
        self.assertEqual(inspector.catalog_as_contract(raw_a)["function_grants"],
                         {"public.f(uuid)": {"authenticated": ["EXECUTE"]}})

    def test_inventory_contract_requires_exact_ordered_versions_and_complete_maps(self):
        validate = getattr(inspector, "validate_contract_document", None)
        self.assertTrue(callable(validate), "missing strict semantic contract validation")
        sequence = [item["version"] for item in rehearsal.migration_sequence()]
        empty = {key: {} for key in inspector.CONTRACT_KEYS}
        valid = {"schema_version": 1, "baseline": {"version": "202610180002"},
                 "versions": [{"version": version, "source_sha256": migration["sha256"],
                     "effects": {"functions": {"public.synthetic()": {"kind": "added"}}},
                     "lineage": [{"identity": "public.synthetic()"}], "invariants": {"synthetic": 0},
                     "contract": {**empty, "functions": {"public.synthetic()": "sha256"}}}
                     for version, migration in zip(sequence, rehearsal.migration_sequence())]}
        self.assertEqual(validate(valid), sequence)
        with self.assertRaisesRegex(ValueError, "ordered migration sequence"):
            shortened = json.loads(json.dumps(valid))
            shortened["versions"] = shortened["versions"][:-1]
            validate(shortened)
        incomplete = json.loads(json.dumps(valid))
        del incomplete["versions"][0]["contract"]["indexes"]
        with self.assertRaisesRegex(ValueError, "semantic categories"):
            validate(incomplete)
        reordered = json.loads(json.dumps(valid))
        reordered["versions"][0], reordered["versions"][1] = reordered["versions"][1], reordered["versions"][0]
        with self.assertRaisesRegex(ValueError, "ordered migration sequence"):
            validate(reordered)

    def test_data_invariant_drift_is_partial_not_absent(self):
        expected = {key: {} for key in inspector.CONTRACT_KEYS}
        expected["data_invariants"] = {"weekly_guard.stale": 0}
        observed = {key: {} for key in inspector.CONTRACT_KEYS}
        observed["data_invariants"] = {"weekly_guard.stale": 1}
        self.assertEqual(inspector.classify_migration_version(False, expected, observed),
                         "partial/conflicting")

    def test_inspector_conninfo_pins_project_target_and_tls_despite_managed_service(self):
        conninfo = inspector.build_endpoint_conninfo(
            "voqmtnqjrbugpazcimvh", "db.voqmtnqjrbugpazcimvh.supabase.co", "192.0.2.19", "managed")
        self.assertIn("host=db.voqmtnqjrbugpazcimvh.supabase.co", conninfo)
        self.assertIn("hostaddr=192.0.2.19", conninfo)
        self.assertIn("port=5432 dbname=postgres", conninfo)
        self.assertIn("sslmode=verify-full sslrootcert=system", conninfo)
        safe = inspector.sanitized_libpq_environment({
            "PATH": "/safe", "PGHOSTADDR": "127.0.0.2", "PGSERVICE": "other",
            "PGSERVICEFILE": "/tmp/override", "PGOPTIONS": "-c role=service_role"})
        self.assertEqual(safe, {"PATH": "/safe"})

    def test_semantic_manifest_requires_all_versions_and_tracks_lineage(self):
        builder = getattr(semantic_manifest, "build_manifest", None) if semantic_manifest else None
        self.assertTrue(callable(builder), "missing snapshot-derived semantic manifest builder")
        sequence = rehearsal.migration_sequence()
        categories = {key: {} for key in inspector.CONTRACT_KEYS}
        categories["functions"]["public.baseline()"] = {
            "definition_fingerprint": "baseline", "security_definer": False}
        categories["functions"]["public.lineage()"] = {
            "definition_fingerprint": "old", "security_definer": False}
        baseline = json.loads(json.dumps(categories))
        snapshots = []
        current = baseline
        for migration in sequence:
            current = json.loads(json.dumps(current))
            if migration["version"] == sequence[0]["version"]:
                current["functions"]["public.lineage()"] = {
                    "definition_fingerprint": "superseding", "security_definer": True}
            if migration["version"] == sequence[1]["version"]:
                del current["functions"]["public.lineage()"]
            current["functions"][f"public.synthetic_{migration['version']}()"] = {
                "definition_fingerprint": migration["sha256"], "security_definer": False}
            snapshots.append({"version": migration["version"], "source_sha256": migration["sha256"],
                              "contract": json.loads(json.dumps(current)),
                              "data_invariants": {"synthetic.count": len(snapshots)}})
        document = builder({"baseline": {"version": "202610180002", "contract": baseline,
                                          "data_invariants": {"synthetic.count": 0}},
                            "versions": snapshots})
        self.assertEqual([item["version"] for item in document["versions"]],
                         [item["version"] for item in sequence])
        self.assertTrue(all(item["effects"]["functions"] for item in document["versions"]))
        self.assertTrue(all(item["lineage"] for item in document["versions"]))
        lineage = next(item for item in document["lineage"] if item["identity"] == "public.lineage()")
        self.assertEqual([event["kind"] for event in lineage["events"]],
                         ["introduced", "altered", "removed"])
        with self.assertRaisesRegex(ValueError, "exact ordered"):
            builder({"baseline": {"version": "202610180002", "contract": baseline,
                                  "data_invariants": {"synthetic.count": 0}},
                     "versions": snapshots[:-1]})
        wrong_source = json.loads(json.dumps(snapshots))
        wrong_source[-1]["source_sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "source checksum"):
            builder({"baseline": {"version": "202610180002", "contract": baseline,
                                  "data_invariants": {"synthetic.count": 0}},
                     "versions": wrong_source})

    def test_006_replaces_existing_attendance_reader_and_005_state_is_not_final(self):
        sequence = rehearsal.migration_sequence()
        identity = "public.ieadpe_ministry_get_session_attendance(jsonb)"
        baseline = {key: {} for key in inspector.CONTRACT_KEYS}
        baseline["functions"][identity] = {"definition_fingerprint": "attendance-v005",
                                           "security_definer": True, "search_path": ""}
        versions = []
        current = json.loads(json.dumps(baseline))
        for item in sequence:
            current = json.loads(json.dumps(current))
            if item["version"] == "202610200006":
                current["functions"][identity] = {"definition_fingerprint": "attendance-v006",
                                                   "security_definer": True, "search_path": ""}
            else:
                current["functions"][f"public.synthetic_{item['version']}()"] = {
                    "definition_fingerprint": item["sha256"], "security_definer": False}
            current["data_invariants"][f"synthetic.{item['version']}"] = len(versions)
            versions.append({"version": item["version"], "source_sha256": item["sha256"],
                             "contract": json.loads(json.dumps(current)),
                             "data_invariants": {f"synthetic.{item['version']}": len(versions)}})
        manifest = semantic_manifest.build_manifest({
            "baseline": {"version": "202610180002", "contract": baseline,
                         "data_invariants": {"synthetic.baseline": 0}},
            "versions": versions})
        sixth = manifest["versions"][-1]
        self.assertEqual(sixth["effects"]["functions"][identity]["kind"], "altered")
        lineage = next(item for item in manifest["lineage"] if item["identity"] == identity)
        self.assertEqual(lineage["events"][-1]["version"], "202610200006")
        self.assertEqual(lineage["events"][-1]["kind"], "altered")
        final_versions = {item["version"] for item in sequence}
        stale_005 = versions[-2]["contract"]
        states = semantic_manifest.classify_manifest_inventory(manifest, stale_005, final_versions)
        self.assertTrue(all(item["state"] == "partial/conflicting" for item in states))

    def test_full_contract_classification_rejects_unexpected_anon_execute_and_function_drift(self):
        classify = inspector.classify_migration_version
        expected = {key: {} for key in inspector.CONTRACT_KEYS}
        expected["functions"]["public.reader(jsonb)"] = {
            "definition_fingerprint": "known", "security_definer": True, "search_path": ""}
        expected["function_grants"]["public.reader(jsonb)"] = {"authenticated": ["EXECUTE"]}
        self.assertEqual(classify(True, expected, json.loads(json.dumps(expected)),), "recorded+present")
        for category, identity, value in (
                ("function_grants", "public.reader(jsonb)", {"authenticated": ["EXECUTE"], "anon": ["EXECUTE"]}),
                ("function_grants", "public.reader(jsonb)", {"authenticated": ["EXECUTE"], "PUBLIC": ["EXECUTE"]}),
                ("function_grants", "public.rogue()", {"PUBLIC": ["EXECUTE"]}),
                ("functions", "public.reader(jsonb)", {"definition_fingerprint": "drift",
                 "security_definer": True, "search_path": ""}),
                ("functions", "public.rogue()", {"definition_fingerprint": "unknown",
                 "security_definer": False, "search_path": ""}),
                ("functions", "public.reader(jsonb)", {"definition_fingerprint": "known",
                 "security_definer": False, "search_path": ""}),
                ("functions", "public.reader(jsonb)", {"definition_fingerprint": "known",
                 "security_definer": True, "search_path": "public"})):
            observed = json.loads(json.dumps(expected))
            observed[category][identity] = value
            self.assertEqual(classify(True, expected, observed), "partial/conflicting")

    def test_each_manifest_checkpoint_has_four_fail_closed_classification_fixtures(self):
        sequence = rehearsal.migration_sequence()
        contract = {key: {} for key in inspector.CONTRACT_KEYS}
        bundle_versions = []
        previous = json.loads(json.dumps(contract))
        for index, migration in enumerate(sequence):
            current = json.loads(json.dumps(previous))
            current["functions"][f"public.version_{index}()"] = {
                "definition_fingerprint": migration["sha256"], "security_definer": False}
            current["data_invariants"][f"synthetic.invariant_{index}"] = index
            bundle_versions.append({"version": migration["version"], "source_sha256": migration["sha256"],
                                    "contract": current,
                                    "data_invariants": {f"synthetic.invariant_{index}": index}})
            previous = current
        baseline_contract = {key: {} for key in inspector.CONTRACT_KEYS}
        baseline_contract["functions"]["public.baseline()"] = "base"
        manifest = semantic_manifest.build_manifest({
            "baseline": {"version": "202610180002", "contract": baseline_contract,
                         "data_invariants": {"synthetic.baseline": 0}},
            "versions": bundle_versions})
        self.assertEqual(len(manifest["versions"]), len(sequence))
        empty = {key: {} for key in inspector.CONTRACT_KEYS}
        for entry in manifest["versions"]:
            checkpoint = entry["contract"]
            self.assertEqual(semantic_manifest.classify_checkpoint(entry, checkpoint, True),
                             "recorded+present", entry["version"])
            self.assertEqual(semantic_manifest.classify_checkpoint(entry, checkpoint, False),
                             "unrecorded+fully-equivalent", entry["version"])
            self.assertEqual(semantic_manifest.classify_checkpoint(entry, empty, False),
                             "absent", entry["version"])
            drift = json.loads(json.dumps(checkpoint))
            function = next(iter(drift["functions"]))
            drift["functions"][function]["definition_fingerprint"] = "drift"
            self.assertEqual(semantic_manifest.classify_checkpoint(entry, drift, True),
                             "partial/conflicting", entry["version"])

    def test_final_catalog_uses_manifest_lineage_for_all_recorded_versions(self):
        classify = getattr(semantic_manifest, "classify_manifest_inventory", None)
        self.assertTrue(callable(classify), "missing lineage-aware final-state inventory classifier")
        sequence = rehearsal.migration_sequence()
        baseline = {key: {} for key in inspector.CONTRACT_KEYS}
        baseline["functions"]["public.base()"] = "base"
        baseline["data_invariants"] = {
            "private.congregation_week_guards.stale": 0,
            "public.converts.backfill_wrong_scope": 0}
        snapshots, current = [], json.loads(json.dumps(baseline))
        for index, item in enumerate(sequence):
            current = json.loads(json.dumps(current))
            current["functions"][f"public.f{index}()"] = f"v{index}"
            if index == 4:
                current["functions"]["public.f0()"] = "superseded-v4"
            current["data_invariants"][f"synthetic.invariant_{index}"] = index
            snapshots.append({"version": item["version"], "source_sha256": item["sha256"],
                              "contract": json.loads(json.dumps(current)),
                              "data_invariants": {f"synthetic.invariant_{index}": index}})
        manifest = semantic_manifest.build_manifest({
            "baseline": {"version": "202610180002", "contract": baseline,
                         "data_invariants": {"synthetic.baseline": 0}},
            "versions": snapshots})
        baseline_states = classify(manifest, baseline, set())
        self.assertEqual([item["state"] for item in baseline_states], ["absent"] * len(sequence))
        prefix_states = classify(manifest, snapshots[1]["contract"],
                                 {item["version"] for item in sequence[:2]})
        self.assertEqual([item["state"] for item in prefix_states[:2]], ["recorded+present"] * 2)
        self.assertEqual([item["state"] for item in prefix_states[2:]], ["absent"] * (len(sequence) - 2))
        gapped_states = classify(manifest, snapshots[1]["contract"],
                                 {sequence[1]["version"]})
        self.assertEqual([item["state"] for item in gapped_states], ["partial/conflicting"] * len(sequence))
        final = manifest["versions"][-1]["contract"]
        all_versions = {item["version"] for item in sequence}
        states = classify(manifest, final, all_versions)
        self.assertEqual([item["state"] for item in states], ["recorded+present"] * len(sequence))
        partial_ledger = all_versions - {sequence[-1]["version"]}
        states = classify(manifest, final, partial_ledger)
        self.assertEqual([item["state"] for item in states[:-1]], ["recorded+present"] * (len(sequence) - 1))
        self.assertEqual(states[-1]["state"], "unrecorded+fully-equivalent")
        states = classify(manifest, {key: {} for key in inspector.CONTRACT_KEYS}, set())
        self.assertEqual([item["state"] for item in states], ["absent"] * len(sequence))
        drift = json.loads(json.dumps(final))
        drift["functions"]["public.f0()"] = "unexpected-drift"
        states = classify(manifest, drift, all_versions)
        self.assertIn("partial/conflicting", [item["state"] for item in states])
        for category, identity, value in (
                ("data_invariants", "private.congregation_week_guards.stale", 1),
                ("data_invariants", "public.converts.backfill_wrong_scope", 1),
                ("columns", "public.ministry_people.unexpected_column", {"type": "text"})):
            adversarial = json.loads(json.dumps(final))
            adversarial[category][identity] = value
            states = classify(manifest, adversarial, all_versions)
            self.assertEqual([item["state"] for item in states], ["partial/conflicting"] * len(sequence), identity)

    def test_backfill_transform_evidence_captures_aliased_top_level_updates(self):
        extract = getattr(semantic_manifest, "extract_migration_time_dml", None)
        self.assertTrue(callable(extract), "missing top-level migration DML evidence extractor")
        migration = (ROOT / "supabase/migrations/202610190001_ministry_people_identity.sql").read_text()
        statements = extract(migration)
        updates = [item["statement"] for item in statements if item["statement"].startswith("UPDATE")]
        self.assertTrue(any("UPDATE public.converts c SET person_id" in item for item in updates))
        self.assertTrue(any("UPDATE public.ministry_students s SET person_id" in item for item in updates))

    def test_inventory_rejects_unbound_endpoint_before_psql(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            marker = directory / "psql-invoked"
            fake = directory / "psql"
            fake.write_text(f"#!/bin/sh\ntouch {marker}\nexit 99\n", encoding="utf-8")
            fake.chmod(fake.stat().st_mode | stat.S_IXUSR)
            env = os.environ.copy()
            env["PATH"] = str(directory) + os.pathsep + env.get("PATH", "")
            result = subprocess.run(
                [sys.executable, str(ROOT / "scripts" / "inspect_hosted_contracts.py"),
                 "--project-ref", "voqmtnqjrbugpazcimvh", "--endpoint", "db.other.supabase.co",
                 "--service", "managed", "--output", str(directory / "report.json")],
                cwd=ROOT, env=env, text=True, capture_output=True, timeout=20,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(marker.exists())

    def test_catalog_query_uses_acl_expansion_and_stable_function_signatures(self):
        sql = inspector.CATALOG_SQL
        self.assertIn("aclexplode", sql)
        self.assertIn("identity_arguments", sql)
        self.assertIn("pg_get_function_identity_arguments", sql)
        self.assertNotIn("specific_name", sql)

    def test_raw_inspector_catalog_path_includes_190001_backfill_invariants(self):
        source = (ROOT / "scripts" / "inspect_hosted_contracts.py").read_text()
        self.assertIn("BACKFILL_CATALOG_SQL", source)
        self.assertIn("public.converts.backfill_unlinked", source)
        self.assertIn("public.converts.backfill_wrong_scope", source)
        self.assertIn("public.ministry_students.person_wrong_scope", source)
        self.assertIn("public.ministry_people.count_matches_scoped_converts", source)
        self.assertIn("capabilities", inspector.CATALOG_SQL)
        self.assertIn('catalog_raw["data_invariants"].update', source)
        harness = (ROOT / "scripts" / "test_database.py").read_text()
        self.assertIn("BACKFILL_CATALOG_SQL", harness)

    def test_inspector_source_is_catalog_only_and_never_invokes_scope(self):
        source = (ROOT / "scripts" / "inspect_hosted_contracts.py").read_text()
        self.assertIn("READ ONLY", source)
        self.assertIn("pg_catalog", source)
        self.assertNotIn("ieadpe_get_scope", source)
        self.assertNotIn("/rest/v1/", source)


if __name__ == "__main__":
    unittest.main()
