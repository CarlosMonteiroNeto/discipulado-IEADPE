import importlib
import http.client
import json
import os
from dataclasses import replace
from pathlib import Path
import tempfile
import threading
import uuid
from contextlib import redirect_stderr
from io import StringIO
from types import SimpleNamespace
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer
from unittest import mock
from urllib.error import HTTPError


def _load_optional(name):
    try:
        return importlib.import_module(name)
    except ImportError:
        return None


guard = _load_optional("local_supabase_guard")
runner = _load_optional("run_unified_journey")


class LocalSupabaseGuardTests(unittest.TestCase):
    def require_guard(self):
        if guard is None:
            self.fail("local_supabase_guard is missing; loopback checks are absent")

    def test_accepts_only_loopback_api_urls(self):
        self.require_guard()
        for value in (
            "http://127.0.0.1:54321",
            "http://localhost:54321",
            "http://[::1]:54321",
        ):
            with self.subTest(value=value):
                self.assertEqual(guard.require_loopback_url(value), value)

    def test_rejects_remote_api_urls(self):
        self.require_guard()
        for value in (
            "https://hosted-project.supabase.co",
            "http://localhost.example.test:54321",
            "http://8.8.8.8:54321",
        ):
            with self.subTest(value=value):
                with self.assertRaises(guard.UnsafeSupabaseTarget):
                    guard.require_loopback_url(value)

    def test_bypasses_proxy_environment_and_does_not_follow_redirects(self):
        self.require_guard()
        requests = []

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                requests.append(self.path)
                if self.path == "/redirect":
                    self.send_response(302)
                    self.send_header(
                        "Location", "http://example.invalid/hosted-target"
                    )
                    self.end_headers()
                    return
                body = json.dumps({"ok": True}).encode()
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def log_message(self, _format, *_args):
                pass

        server = HTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(server.server_close)
        self.addCleanup(thread.join, 2)
        self.addCleanup(server.shutdown)
        base = f"http://127.0.0.1:{server.server_port}"

        with mock.patch.dict(
            os.environ,
            {
                "HTTP_PROXY": "http://127.0.0.1:1",
                "HTTPS_PROXY": "http://127.0.0.1:1",
                "ALL_PROXY": "http://127.0.0.1:1",
                "NO_PROXY": "",
                "http_proxy": "http://127.0.0.1:1",
                "https_proxy": "http://127.0.0.1:1",
                "all_proxy": "http://127.0.0.1:1",
                "no_proxy": "",
            },
        ):
            self.assertEqual(
                guard.request_json(base + "/health"), {"ok": True}
            )
            with self.assertRaises((HTTPError, guard.UnsafeSupabaseTarget)):
                guard.request_json(base + "/redirect")

        self.assertEqual(requests, ["/health", "/redirect"])

    def test_rejects_database_hostaddr_multihost_and_connection_overrides(self):
        self.require_guard()
        unsafe_urls = (
            "postgresql://postgres:secret@127.0.0.1,127.0.0.2:54322/postgres",
            "postgresql://postgres:secret@127.0.0.1:54322/postgres?hostaddr=127.0.0.1",
            "postgresql://postgres:secret@127.0.0.1:54322/postgres?service=hosted",
            "postgresql://postgres:secret@127.0.0.1:54322/postgres?servicefile=/tmp/pg_service.conf",
            "postgresql://postgres:secret@127.0.0.1:54322/postgres?options=-c%20search_path=public",
            "host=127.0.0.1 port=54322 dbname=postgres",
        )
        for value in unsafe_urls:
            with self.subTest(value=value):
                with self.assertRaises(guard.UnsafeSupabaseTarget):
                    guard.parse_database_url(value)

        accepted = guard.parse_database_url(
            "postgresql://postgres:local-password@127.0.0.1:54322/postgres"
        )
        self.assertEqual(accepted.host, "127.0.0.1")
        self.assertEqual(accepted.port, 54322)

    def test_rejects_database_name_conninfo_overrides(self):
        self.require_guard()
        unsafe_urls = (
            "postgresql://postgres:pw@127.0.0.1:54322/host=hosted.example",
            "postgresql://postgres:pw@127.0.0.1:54322/"
            "host%3Dhosted.example%20port%3D5432%20dbname%3Dpostgres",
        )
        for value in unsafe_urls:
            with self.subTest(value=value):
                with self.assertRaises(guard.UnsafeSupabaseTarget):
                    guard.parse_database_url(value)

        valid = guard.parse_database_url(
            "postgresql://postgres:local-password@127.0.0.1:54322/postgres"
        )
        self.assertEqual(valid.database, "postgres")


class UnifiedJourneyRunnerTests(unittest.TestCase):
    def require_runner(self):
        if runner is None:
            self.fail("run_unified_journey is missing; guarded runner is absent")

    def test_remote_cli_status_stops_before_http_or_sql(self):
        self.require_runner()
        with (
            mock.patch.object(
                runner,
                "read_supabase_status",
                return_value={
                    "API_URL": "https://hosted-project.supabase.co",
                    "DB_URL": "postgresql://postgres:pw@db.hosted.example:5432/postgres",
                    "ANON_KEY": "public-test-key",
                    "SERVICE_ROLE_KEY": "host-secret",
                },
            ),
            mock.patch.object(runner, "request_json") as request_json,
            mock.patch.object(runner, "run_sql") as run_sql,
        ):
            result = runner.run_journey()

        self.assertEqual(result, runner.BLOCKED)
        request_json.assert_not_called()
        run_sql.assert_not_called()

    def test_missing_prerequisite_diagnostic_names_unavailable_service(self):
        self.require_runner()
        stderr = StringIO()
        with (
            redirect_stderr(stderr),
            mock.patch.object(
                runner,
                "read_supabase_status",
                side_effect=runner.PrerequisiteBlocked("Supabase CLI is unavailable."),
            ),
        ):
            result = runner.run_journey()
        self.assertEqual(result, runner.BLOCKED)
        self.assertIn("prerequisite:Supabase CLI is unavailable.", stderr.getvalue())

    def test_failure_diagnostic_hides_external_error_message(self):
        self.require_runner()
        stderr = StringIO()
        with redirect_stderr(stderr):
            runner._write_failure("primary", RuntimeError("secret synthetic marker"))
        self.assertIn("primary:RuntimeError", stderr.getvalue())
        self.assertNotIn("secret synthetic marker", stderr.getvalue())

    def test_service_role_key_never_enters_flutter_settings(self):
        self.require_runner()
        service_role = "super-secret-service-role-value"
        settings = runner.flutter_settings(
            api_url="http://127.0.0.1:54321",
            anon_key="public-anon-key",
            service_role_key=service_role,
            fixture={
                "JOURNEY_REGISTRAR_EMAIL": "runner@example.test",
                "JOURNEY_CONVERT_NAME": "Journey Convert test",
            },
        )
        serialized = json.dumps(settings)
        self.assertNotIn(service_role, serialized)
        self.assertNotIn("service_role", serialized.lower())
        self.assertEqual(settings["JOURNEY_CONVERT_NAME"], "Journey Convert test")

    def test_local_intake_endpoint_is_the_only_test_server_value_in_flutter_settings(self):
        self.require_runner()
        endpoint = "http://127.0.0.1:7358/functions/v1/public-intake"
        settings = runner.flutter_settings(
            api_url="http://127.0.0.1:54321",
            anon_key="public-anon-key",
            service_role_key="service-role-never-in-browser",
            fixture={"JOURNEY_INTAKE_TEST_ENDPOINT": endpoint},
        )
        self.assertEqual(settings["JOURNEY_INTAKE_TEST_ENDPOINT"], endpoint)
        self.assertNotIn("service-role-never-in-browser", json.dumps(settings))

        for unsafe in (
            "https://hosted.example/functions/v1/public-intake",
            "http://127.0.0.1:7358/unrelated",
            "http://127.0.0.1:7358/functions/v1/public-intake?target=hosted",
        ):
            with self.subTest(endpoint=unsafe):
                with self.assertRaises(runner.UnsafeSupabaseTarget):
                    runner.flutter_settings(
                        api_url="http://127.0.0.1:54321",
                        anon_key="public-anon-key",
                        service_role_key="service-role-never-in-browser",
                        fixture={"JOURNEY_INTAKE_TEST_ENDPOINT": unsafe},
                    )

    def test_local_intake_server_keeps_service_role_host_side_and_limits_network(self):
        self.require_runner()
        fixture = runner.make_fixture("17b98af0-dfd2-4ae0-94cc-c44eb7258f9a")
        config = runner.LocalSupabase(
            "http://127.0.0.1:54321",
            "postgresql://postgres:pw@127.0.0.1:54329/postgres",
            "local-anon",
            "host-only-service-role-secret",
        )
        server = runner.LocalPublicIntakeTestFunction(
            config,
            fixture,
            allowed_origin="http://127.0.0.1:7357",
        )
        process = mock.Mock()
        process.poll.return_value = None
        captured = {}

        def start_process(command, **kwargs):
            captured.update(command=command, **kwargs)
            return process

        with (
            mock.patch.object(runner, "_deno_executable", return_value="deno"),
            mock.patch.object(runner, "_free_loopback_port", return_value=7358),
            mock.patch.object(runner.subprocess, "Popen", side_effect=start_process),
            mock.patch.object(runner, "request_json", return_value={"ready": True}),
        ):
            server.start()
            server.close()

        self.assertEqual(
            server.endpoint,
            f"http://127.0.0.1:{server.port}/functions/v1/public-intake",
        )
        self.assertIn(
            f"--allow-net=127.0.0.1:{server.port},127.0.0.1:54321",
            captured["command"],
        )
        self.assertNotIn("host-only-service-role-secret", captured["command"])
        self.assertEqual(
            captured["env"]["JOURNEY_LOCAL_SERVICE_ROLE_KEY"],
            "host-only-service-role-secret",
        )
        self.assertEqual(captured["stdout"], runner.subprocess.DEVNULL)
        self.assertEqual(captured["stderr"], runner.subprocess.DEVNULL)

    def test_local_intake_server_rejects_remote_api_before_process_start(self):
        self.require_runner()
        fixture = runner.make_fixture("17b98af0-dfd2-4ae0-94cc-c44eb7258f9a")
        config = runner.LocalSupabase(
            "https://remote.example",
            "postgresql://postgres:pw@127.0.0.1:54329/postgres",
            "local-anon",
            "service-secret",
        )
        server = runner.LocalPublicIntakeTestFunction(
            config,
            fixture,
            allowed_origin="http://127.0.0.1:7357",
        )
        with (
            mock.patch.object(runner, "_deno_executable", return_value="deno"),
            mock.patch.object(runner.subprocess, "Popen") as popen,
            self.assertRaises(runner.UnsafeSupabaseTarget),
        ):
            server.start()
        popen.assert_not_called()

    def test_cleanup_targets_run_owned_pending_intake_and_approved_convert(self):
        self.require_runner()
        fixture = runner.make_fixture(
            "17b98af0-dfd2-4ae0-94cc-c44eb7258f9a",
            password_factory=lambda: "synthetic-only-password",
        )
        sql = runner.cleanup_sql(fixture)
        self.assertIn(fixture.public_convert_name, sql)
        self.assertRegex(sql, r"(?is)journey_owned_public_submissions")
        self.assertIn("private.public_intake_submissions", sql)
        self.assertIn("private.public_intake_receipts", sql)
        self.assertIn("private.public_intake_decisions", sql)
        self.assertIn("private.public_intake_accepted_events", sql)
        self.assertNotRegex(sql, r"(?is)DELETE\s+FROM\s+private\.public_intake_submissions\s*;")
        self.assertNotRegex(sql, r"(?is)TRUNCATE")
        self.assertNotIn("synthetic-only-password", sql)

    def test_cleanup_pins_public_submission_id_and_acceptance_sql_checks_erasure(self):
        self.require_runner()
        fixture = replace(
            runner.make_fixture("17b98af0-dfd2-4ae0-94cc-c44eb7258f9a"),
            public_submission_id="22222222-2222-4222-8222-222222222222",
        )
        cleanup = runner.cleanup_sql(fixture)
        self.assertIn(fixture.public_submission_id, cleanup)
        self.assertIn(
            f"s.congregation_id={runner._sql_uuid(fixture.congregation_a_id)}",
            cleanup,
        )

        acceptance = runner.public_intake_acceptance_sql(fixture)
        self.assertIn("status='approved' AND draft IS NULL", acceptance)
        self.assertIn("payload_erased_at IS NOT NULL", acceptance)
        self.assertIn("private.public_intake_decisions", acceptance)
        self.assertIn("private.public_intake_accepted_events", acceptance)
        self.assertIn(f"c.created_by={runner._sql_uuid(fixture.supervisor_id)}", acceptance)
        with self.assertRaises(ValueError):
            runner.public_intake_acceptance_sql(runner.make_fixture(fixture.run_id))

    def test_partial_anonymous_upload_cleanup_is_exact_and_loopback_only(self):
        self.require_runner()
        fixture = runner.make_fixture("17b98af0-dfd2-4ae0-94cc-c44eb7258f9a")
        config = runner.LocalSupabase(
            "http://127.0.0.1:54321",
            "postgresql://postgres:pw@127.0.0.1:54329/postgres",
            "local-anon",
            "host-only-service-role",
        )
        with mock.patch.object(runner, "request_json") as request:
            runner.cleanup_public_intake_photo(config, fixture)
        request.assert_called_once_with(
            "http://127.0.0.1:54321/storage/v1/object/convert-photos/"
            f"journey-test/{fixture.run_id}/unsigned.jpg",
            method="DELETE",
            headers={
                "apikey": "host-only-service-role",
                "Authorization": "Bearer host-only-service-role",
            },
            timeout=10,
        )

        remote = replace(config, api_url="https://hosted.example")
        with mock.patch.object(runner, "request_json") as request:
            with self.assertRaises(runner.UnsafeSupabaseTarget):
                runner.cleanup_public_intake_photo(remote, fixture)
        request.assert_not_called()

    def test_public_submission_cleanup_marker_accepts_one_uuid_only(self):
        self.require_runner()
        submission_id = "22222222-2222-4222-8222-222222222222"
        self.assertEqual(
            runner._public_submission_id_from_output(
                f"PUBLIC_INTAKE_CLEANUP_ID={submission_id}"
            ),
            submission_id,
        )
        with self.assertRaises(runner.JourneyFailure):
            runner._public_submission_id_from_output(
                f"PUBLIC_INTAKE_CLEANUP_ID={submission_id}\n"
                "PUBLIC_INTAKE_CLEANUP_ID=33333333-3333-4333-8333-333333333333"
            )

    def test_cleanup_sql_is_scoped_to_generated_run_fixture_ids(self):
        self.require_runner()
        fixture = runner.make_fixture(
            "17b98af0-dfd2-4ae0-94cc-c44eb7258f9a",
            password_factory=lambda: "synthetic-only-password",
        )
        sql = runner.cleanup_sql(fixture)
        self.assertIn(fixture.run_id, sql)
        self.assertIn(fixture.congregation_a_id, sql)
        self.assertIn(fixture.congregation_b_id, sql)
        self.assertIn(fixture.class_id, sql)
        self.assertRegex(
            sql,
            rf"(?is)journey_owned_sessions.*?s\.congregation_id={runner._sql_uuid(fixture.congregation_a_id)}.*?s\.class_id={runner._sql_uuid(fixture.class_id)}",
        )
        selector_start = sql.index("SELECT c.id FROM public.converts c")
        selector_end = sql.index(");", selector_start)
        convert_selector = sql[selector_start:selector_end]
        self.assertIn(
            f"c.created_by={runner._sql_uuid(fixture.registrar_id)}",
            convert_selector,
        )
        self.assertIn(
            f"c.name={runner._sql_text(fixture.convert_name)}", convert_selector
        )
        self.assertIn(
            f"c.name={runner._sql_text(fixture.public_convert_name)}",
            convert_selector,
        )
        self.assertIn("c.internal_id=c.id::text", convert_selector)
        self.assertIn(
            f"c.congregation_id={runner._sql_uuid(fixture.congregation_a_id)}",
            convert_selector,
        )
        self.assertNotIn("synthetic-only-password", sql)
        self.assertNotRegex(sql, r"(?is)DELETE\s+FROM\s+(?:public\.)?congregations\s*;")
        with self.assertRaises(ValueError):
            runner.make_fixture("congregation-a; DROP TABLE public.user_access;--")

    def test_cleanup_includes_run_owned_canonical_and_replacement_dependencies(self):
        self.require_runner()
        fixture = runner.make_fixture(
            "17b98af0-dfd2-4ae0-94cc-c44eb7258f9a",
            password_factory=lambda: "synthetic-only-password",
        )
        sql = runner.cleanup_sql(fixture)
        expected_student_id = str(uuid.uuid5(uuid.UUID(fixture.run_id), "ieadpe-unified-journey:student"))
        expected_person_id = str(uuid.uuid5(uuid.UUID(fixture.run_id), "ieadpe-unified-journey:person"))
        self.assertIn(expected_student_id, sql)
        self.assertIn(expected_person_id, sql)
        self.assertIn("public.ministry_people", sql)
        self.assertIn("public.ministry_session_roster", sql)
        self.assertIn("public.ministry_attendance", sql)
        self.assertIn("private.congregation_week_guards", sql)
        self.assertIn("replaces_session_id", sql)
        self.assertRegex(sql, r"(?is)GROUP BY id ORDER BY max\(depth\) DESC")
        self.assertRegex(
            sql,
            r"(?is)journey_owned_people.*?SELECT s\.person_id FROM public\.ministry_students",
        )
        self.assertNotRegex(sql, r"(?is)DELETE\s+FROM\s+public\.ministry_people\s*;")
        self.assertNotRegex(
            sql, r"(?is)DELETE\s+FROM\s+private\.congregation_week_guards\s*;"
        )
        sentinel_id = "11111111-1111-4111-8111-111111111111"
        self.assertNotIn(sentinel_id, sql)
        self.assertNotRegex(sql, r"(?is)TRUNCATE")
        self.assertNotIn("synthetic-only-password", sql)

    def test_partial_setup_failure_still_cleans_owned_fixture(self):
        self.require_runner()
        cleanup_calls = []
        created_user_ids = []
        deleted_user_ids = []
        fixture = runner.make_fixture(
            "17b98af0-dfd2-4ae0-94cc-c44eb7258f9a",
            password_factory=lambda: "synthetic-only-password",
        )

        def create_user(_config, user):
            if user.id == fixture.supervisor_id:
                raise runner.JourneyFailure("synthetic setup failure")
            created_user_ids.append(user.id)

        stderr = StringIO()
        with (
            redirect_stderr(stderr),
            mock.patch.object(
                runner,
                "local_supabase_from_status",
                return_value=runner.LocalSupabase(
                    "http://127.0.0.1:54321",
                    "postgresql://postgres:pw@127.0.0.1:54329/postgres",
                    "local-anon",
                    "local-service-role",
                ),
            ),
            mock.patch.object(runner, "read_supabase_status", return_value={}),
            mock.patch.object(runner, "check_browser_prerequisites", return_value=("driver", "chrome")),
            mock.patch.object(runner, "_preflight_local_services"),
            mock.patch.object(runner, "make_fixture", return_value=fixture),
            mock.patch.object(runner, "_admin_create_user", side_effect=create_user),
            mock.patch.object(
                runner,
                "_admin_delete_user",
                side_effect=lambda _config, user_id: deleted_user_ids.append(user_id),
                create=True,
            ),
            mock.patch.object(runner, "run_sql", side_effect=lambda sql, _url: cleanup_calls.append(sql) or ""),
            mock.patch.object(runner, "cleanup_public_intake_photo"),
        ):
            result = runner.run_journey()
        self.assertEqual(result, runner.FAIL)
        self.assertEqual(created_user_ids, [fixture.registrar_id])
        self.assertEqual(
            deleted_user_ids,
            [fixture.supervisor_id, fixture.registrar_id],
            "teardown attempts only the exact generated IDs through the failed setup step",
        )
        self.assertEqual(len(cleanup_calls), 1)
        self.assertIn(fixture.run_id, cleanup_calls[0])
        for created_user_id in created_user_ids:
            self.assertIn(created_user_id, cleanup_calls[0])
        self.assertIn("primary:JourneyFailure", stderr.getvalue())
        self.assertNotIn("synthetic setup failure", stderr.getvalue())

    def test_browser_reported_student_and_person_ids_are_used_for_partial_cleanup(self):
        self.require_runner()
        fixture = runner.make_fixture("17b98af0-dfd2-4ae0-94cc-c44eb7258f9a")
        actual_student_id = "22222222-2222-4222-8222-222222222222"
        actual_person_id = "77777777-7777-4777-8777-777777777777"
        actual_submission_id = "33333333-3333-4333-8333-333333333333"
        cleanup_calls = []

        def report_then_fail(_config, _fixture, _driver, _chrome, **kwargs):
            callback = kwargs.get("on_owned_identity")
            if callback is not None:
                callback(actual_student_id, actual_person_id)
            submission_callback = kwargs.get("on_public_submission")
            if submission_callback is not None:
                submission_callback(actual_submission_id)
            raise runner.JourneyFailure("synthetic post-registration browser failure")

        stderr = StringIO()
        with (
            redirect_stderr(stderr),
            mock.patch.object(
                runner,
                "local_supabase_from_status",
                return_value=runner.LocalSupabase(
                    "http://127.0.0.1:54321",
                    "postgresql://postgres:pw@127.0.0.1:54329/postgres",
                    "local-anon",
                    "local-service-role",
                ),
            ),
            mock.patch.object(runner, "read_supabase_status", return_value={}),
            mock.patch.object(runner, "check_browser_prerequisites", return_value=("driver", "chrome")),
            mock.patch.object(runner, "_preflight_local_services"),
            mock.patch.object(runner, "make_fixture", return_value=fixture),
            mock.patch.object(runner, "_admin_create_user"),
            mock.patch.object(runner, "_admin_delete_user"),
            mock.patch.object(
                runner,
                "run_sql",
                side_effect=lambda sql, _url: cleanup_calls.append(sql) or "",
            ),
            mock.patch.object(runner, "_run_browser_journey", side_effect=report_then_fail),
            mock.patch.object(runner, "cleanup_public_intake_photo"),
        ):
            result = runner.run_journey()

        self.assertEqual(result, runner.FAIL)
        self.assertEqual(len(cleanup_calls), 2)
        self.assertIn(actual_student_id, cleanup_calls[-1])
        self.assertIn(actual_person_id, cleanup_calls[-1])
        self.assertIn(actual_submission_id, cleanup_calls[-1])
        self.assertNotIn("synthetic post-registration browser failure", stderr.getvalue())

    def test_browser_failure_releases_the_run_control(self):
        self.require_runner()
        fixture = runner.make_fixture(
            "17b98af0-dfd2-4ae0-94cc-c44eb7258f9a",
            password_factory=lambda: "synthetic-only-password",
        )
        config = runner.LocalSupabase(
            "http://127.0.0.1:54321",
            "postgresql://postgres:pw@127.0.0.1:54329/postgres",
            "local-anon",
            "local-service-role",
        )
        closed = []

        class FakeControl:
            address = ("127.0.0.1", 43210)
            capability = "x" * 48

            def close(self):
                closed.append(True)

        class FakeIntakeTestServer:
            endpoint = "http://127.0.0.1:43212/functions/v1/public-intake"

            def start(self):
                return None

            def close(self):
                closed.append(True)

        with (
            mock.patch.object(runner, "RevocationControl", return_value=FakeControl()),
            mock.patch.object(
                runner,
                "LocalPublicIntakeTestFunction",
                return_value=FakeIntakeTestServer(),
            ),
            mock.patch.object(
                runner,
                "_start_chromedriver",
                side_effect=runner.PrerequisiteBlocked("synthetic browser failure"),
            ),
            mock.patch.object(runner, "run_sql") as run_sql,
        ):
            with self.assertRaises(runner.PrerequisiteBlocked):
                runner._run_browser_journey(config, fixture, "driver", "chrome")
        self.assertEqual(closed, [True, True])
        run_sql.assert_not_called()

    def test_browser_timeout_after_launch_is_journey_failure_and_releases_control(self):
        self.require_runner()
        fixture = runner.make_fixture(
            "17b98af0-dfd2-4ae0-94cc-c44eb7258f9a",
            password_factory=lambda: "synthetic-only-password",
        )
        config = runner.LocalSupabase(
            "http://127.0.0.1:54321",
            "postgresql://postgres:pw@127.0.0.1:54329/postgres",
            "local-anon",
            "local-service-role",
        )
        closed = []
        terminated = []

        class FakeControl:
            address = ("127.0.0.1", 43210)
            capability = "x" * 48

            def close(self):
                closed.append(True)

        class FakeIntakeTestServer:
            endpoint = "http://127.0.0.1:43212/functions/v1/public-intake"

            def start(self):
                return None

            def close(self):
                closed.append(True)

        class FakeProcess:
            def poll(self):
                return None

            def terminate(self):
                terminated.append(True)

            def wait(self, timeout):
                return 0

        with (
            mock.patch.object(runner, "_free_loopback_port", return_value=43211),
            mock.patch.object(runner, "RevocationControl", return_value=FakeControl()),
            mock.patch.object(
                runner,
                "LocalPublicIntakeTestFunction",
                return_value=FakeIntakeTestServer(),
            ),
            mock.patch.object(runner, "_start_chromedriver", return_value=FakeProcess()),
            mock.patch.object(runner, "_safe_environment", return_value={}),
            mock.patch.object(runner, "_drive_command", return_value=["flutter", "drive"]),
            mock.patch.object(
                runner.subprocess,
                "run",
                side_effect=runner.subprocess.TimeoutExpired(["flutter", "drive"], 900),
            ),
        ):
            with self.assertRaises(runner.JourneyFailure):
                runner._run_browser_journey(config, fixture, "driver", "chrome")
        self.assertEqual(closed, [True, True])
        self.assertEqual(terminated, [True])

    def test_cleanup_failure_cannot_report_pass_and_retains_sanitized_cause(self):
        self.require_runner()
        fixture = runner.make_fixture("17b98af0-dfd2-4ae0-94cc-c44eb7258f9a")
        user_count = 0

        def create_user(_config, _user):
            nonlocal user_count
            user_count += 1

        def run_sql(sql, _url):
            if "-- run_id:" in sql:
                raise runner.JourneyFailure("synthetic cleanup failure")
            if "WITH target AS" in sql:
                return "PASS"
            return ""

        def report_submission(_config, _fixture, _driver, _chrome, **kwargs):
            callback = kwargs.get("on_public_submission")
            if callback is not None:
                callback("33333333-3333-4333-8333-333333333333")

        stderr = StringIO()
        with (
            redirect_stderr(stderr),
            mock.patch.object(
                runner,
                "local_supabase_from_status",
                return_value=runner.LocalSupabase(
                    "http://127.0.0.1:54321",
                    "postgresql://postgres:pw@127.0.0.1:54329/postgres",
                    "local-anon",
                    "local-service-role",
                ),
            ),
            mock.patch.object(runner, "read_supabase_status", return_value={}),
            mock.patch.object(runner, "check_browser_prerequisites", return_value=("driver", "chrome")),
            mock.patch.object(runner, "_preflight_local_services"),
            mock.patch.object(runner, "make_fixture", return_value=fixture),
            mock.patch.object(runner, "_admin_create_user", side_effect=create_user),
            mock.patch.object(runner, "_admin_delete_user"),
            mock.patch.object(runner, "run_sql", side_effect=run_sql),
            mock.patch.object(runner, "_run_browser_journey", side_effect=report_submission),
            mock.patch.object(runner, "cleanup_public_intake_photo"),
        ):
            result = runner.run_journey()
        self.assertEqual(user_count, 4)
        self.assertEqual(result, runner.FAIL)
        self.assertIn("cleanup:JourneyFailure", stderr.getvalue())
        self.assertNotIn("synthetic cleanup failure", stderr.getvalue())

    def test_run_sql_rejects_remote_database_before_starting_a_process(self):
        self.require_runner()
        with mock.patch.object(runner.shutil, "which", return_value="psql"), mock.patch.object(
            runner.subprocess, "run"
        ) as process:
            with self.assertRaises(guard.UnsafeSupabaseTarget):
                runner.run_sql(
                    "SELECT 1;",
                    "postgresql://postgres:pw@db.hosted.example:5432/postgres",
                )
        process.assert_not_called()

    def test_status_child_does_not_inherit_hosted_supabase_environment(self):
        self.require_runner()
        completed = mock.Mock(returncode=1, stdout="", stderr="")
        with (
            mock.patch.dict(os.environ, {"SUPABASE_URL": "https://hosted.example"}),
            mock.patch.object(runner.shutil, "which", return_value="supabase"),
            mock.patch.object(runner.subprocess, "run", return_value=completed) as process,
        ):
            with self.assertRaises(runner.PrerequisiteBlocked):
                runner.read_supabase_status()
        child_env = process.call_args.kwargs["env"]
        self.assertNotIn("SUPABASE_URL", child_env)

    def test_drive_command_pins_headless_chrome_and_loopback_origin(self):
        self.require_runner()
        with mock.patch.object(runner, "_command_exists", return_value="flutter"):
            command = runner._drive_command(
                Path("settings.json"), 4444, "C:/Chrome/chrome.exe"
            )

        self.assertIn("--browser-name=chrome", command)
        self.assertIn("--headless", command)
        self.assertIn("--chrome-binary=C:/Chrome/chrome.exe", command)
        self.assertIn("--device-id=web-server", command)
        self.assertIn("--driver-port", command)
        self.assertEqual(command[command.index("--driver-port") + 1], "4444")
        self.assertIn("--web-port=7357", command)
        self.assertIn("--web-hostname=127.0.0.1", command)
        self.assertIn("--web-launch-url=http://127.0.0.1:7357/", command)
        self.assertIn("--no-pub", command)
        self.assertIn("--no-web-resources-cdn", command)
        self.assertIn("--no-version-check", command)
        self.assertIn("--suppress-analytics", command)

    def test_chromedriver_resolution_prefers_path_then_localappdata_install(self):
        self.require_runner()
        with tempfile.TemporaryDirectory() as temp_dir:
            installed = Path(temp_dir) / "Programs" / "ChromeDriver" / "chromedriver.exe"
            installed.parent.mkdir(parents=True)
            installed.write_bytes(b"test executable placeholder")
            with mock.patch.dict(os.environ, {"LOCALAPPDATA": temp_dir}, clear=False):
                windows = SimpleNamespace(name="nt", environ=os.environ)
                with mock.patch.object(runner, "os", windows):
                    with mock.patch.object(
                        runner,
                        "_command_exists",
                        return_value="C:/tools/chromedriver.exe",
                    ):
                        self.assertEqual(
                            runner._chromedriver_executable(),
                            "C:/tools/chromedriver.exe",
                        )
                    with mock.patch.object(runner, "_command_exists", return_value=None):
                        self.assertEqual(
                            runner._chromedriver_executable(), str(installed)
                        )

    def test_posix_chromedriver_resolution_ignores_windows_localappdata(self):
        self.require_runner()
        with tempfile.TemporaryDirectory() as temp_dir:
            installed = Path(temp_dir) / "Programs" / "ChromeDriver" / "chromedriver.exe"
            installed.parent.mkdir(parents=True)
            installed.write_bytes(b"test executable placeholder")
            with mock.patch.dict(os.environ, {"LOCALAPPDATA": temp_dir}, clear=False):
                posix = SimpleNamespace(name="posix", environ=os.environ)
                with mock.patch.object(runner, "os", posix), mock.patch.object(
                    runner, "_command_exists", return_value=None
                ):
                    self.assertIsNone(runner._chromedriver_executable())

    def test_windows_browser_version_check_reads_chrome_file_metadata(self):
        self.require_runner()
        with (
            mock.patch.object(runner.os, "name", "nt"),
            mock.patch.object(runner, "_safe_environment", return_value={}),
            mock.patch.object(
                runner,
                "_command_exists",
                side_effect=lambda name: {
                    "flutter": "flutter.exe",
                    "chromedriver": "chromedriver.exe",
                }.get(name),
            ),
            mock.patch.object(runner, "_chrome_executable", return_value="chrome.exe"),
            mock.patch.object(
                runner,
                "_version_output",
                side_effect=("Flutter 3.0", "ChromeDriver 155.0.1.0"),
            ),
            mock.patch.object(
                runner, "_windows_file_version", return_value="Google Chrome 155.0.1.1"
            ) as file_version,
        ):
            driver, chrome = runner.check_browser_prerequisites()

        self.assertEqual((driver, chrome), ("chromedriver.exe", "chrome.exe"))
        file_version.assert_called_once_with("chrome.exe")

    def test_supabase_status_prefers_native_binary_over_windows_script_shim(self):
        self.require_runner()
        with tempfile.TemporaryDirectory() as temp_dir:
            installed = (
                Path(temp_dir)
                / "Programs"
                / "supabase-cli"
                / "node_modules"
                / "@supabase"
                / "cli-windows-x64"
                / "bin"
                / "supabase.exe"
            )
            installed.parent.mkdir(parents=True)
            installed.write_bytes(b"test executable placeholder")
            with mock.patch.dict(os.environ, {"LOCALAPPDATA": temp_dir}, clear=False):
                windows = SimpleNamespace(name="nt", environ=os.environ)
                with mock.patch.object(runner, "os", windows):
                    with mock.patch.object(
                        runner,
                        "_command_exists",
                        side_effect=lambda name: {
                            "supabase.exe": None,
                            "supabase": "C:/npm/supabase.cmd",
                        }.get(name),
                    ):
                        self.assertEqual(runner._supabase_executable(), str(installed))
                    with mock.patch.object(
                        runner,
                        "_command_exists",
                        side_effect=lambda name: {
                            "supabase.exe": "C:/tools/supabase.exe",
                            "supabase": "C:/npm/supabase.cmd",
                        }.get(name),
                    ):
                        self.assertEqual(
                            runner._supabase_executable(), "C:/tools/supabase.exe"
                        )

    def test_posix_supabase_resolution_keeps_path_when_localappdata_has_windows_binary(self):
        self.require_runner()
        with tempfile.TemporaryDirectory() as temp_dir:
            installed = (
                Path(temp_dir)
                / "Programs"
                / "supabase-cli"
                / "node_modules"
                / "@supabase"
                / "cli-windows-x64"
                / "bin"
                / "supabase.exe"
            )
            installed.parent.mkdir(parents=True)
            installed.write_bytes(b"test executable placeholder")
            with mock.patch.dict(os.environ, {"LOCALAPPDATA": temp_dir}, clear=False):
                posix = SimpleNamespace(name="posix", environ=os.environ)
                with mock.patch.object(runner, "os", posix), mock.patch.object(
                    runner,
                    "_command_exists",
                    side_effect=lambda name: "supabase" if name == "supabase" else None,
                ):
                    self.assertEqual(runner._supabase_executable(), "supabase")

    def test_setup_and_revoke_sql_use_only_fixture_assignments(self):
        self.require_runner()
        fixture = runner.make_fixture(
            "17b98af0-dfd2-4ae0-94cc-c44eb7258f9a",
            password_factory=lambda: "synthetic-only-password",
        )
        setup = runner.setup_sql(fixture)
        revoke = runner.revocation_sql(fixture, fixture.direction_assignment_id)
        self.assertIn(fixture.congregation_a_id, setup)
        self.assertIn(fixture.congregation_b_id, setup)
        self.assertIn(fixture.supervisor_assignment_id, setup)
        self.assertIn(fixture.direction_assignment_id, revoke)
        self.assertIn(fixture.direction_id, revoke)
        self.assertNotIn(fixture.out_of_scope_assignment_id, revoke)
        self.assertNotIn("synthetic-only-password", setup + revoke)
        self.assertNotRegex(
            setup,
            r"(?is)INSERT\s+INTO\s+public\.ministry_(?:session_roster|attendance)",
        )
        with self.assertRaises(ValueError):
            runner.revocation_sql(fixture, fixture.out_of_scope_assignment_id)


class RevocationControlTests(unittest.TestCase):
    def test_loopback_control_requires_capability_origin_and_fixed_assignment(self):
        if runner is None:
            self.fail("run_unified_journey is missing; revocation control is absent")
        assignment_id = "ee868c65-15f4-431e-ab73-6a55e9d0274e"
        calls = []
        control = runner.RevocationControl(
            run_id="17b98af0-dfd2-4ae0-94cc-c44eb7258f9a",
            assignment_id=assignment_id,
            user_id="61ff879b-390a-4727-9a6a-c59c7e1c4c13",
            congregation_id="9e5118df-343c-4f12-b6bd-6e44882ee684",
            allowed_origin="http://127.0.0.1:7357",
            revoke=lambda target: calls.append(target),
        )
        self.addCleanup(control.close)
        host, port = control.address
        self.assertIn(host, {"127.0.0.1", "::1"})
        self.assertGreaterEqual(len(control.capability), 40)

        def post(path, *, origin=None, capability=None):
            connection = http.client.HTTPConnection(host, port, timeout=3)
            self.addCleanup(connection.close)
            headers = {}
            if origin is not None:
                headers["Origin"] = origin
            if capability is not None:
                headers["X-Run-Capability"] = capability
            connection.request("POST", path, body=b"", headers=headers)
            response = connection.getresponse()
            status = response.status
            body = response.read()
            return status, body

        fixed_path = f"/revoke/{assignment_id}"
        self.assertEqual(post(fixed_path, origin=control.allowed_origin)[0], 401)
        self.assertEqual(
            post(
                fixed_path,
                origin="http://127.0.0.1:7358",
                capability=control.capability,
            )[0],
            403,
        )
        self.assertEqual(
            post(
                "/revoke/aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
                origin=control.allowed_origin,
                capability=control.capability,
            )[0],
            404,
        )
        status, body = post(
            fixed_path,
            origin=control.allowed_origin,
            capability=control.capability,
        )
        self.assertEqual(status, 200)
        self.assertEqual(calls, [assignment_id])
        self.assertNotIn(control.capability.encode(), body)


if __name__ == "__main__":
    unittest.main()
