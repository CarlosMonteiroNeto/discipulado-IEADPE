import importlib
import http.client
import json
import os
from pathlib import Path
import tempfile
import threading
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
        self.assertIn(fixture.session_id, sql)
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
        self.assertIn("c.internal_id=c.id::text", convert_selector)
        self.assertNotIn("c.congregation_id", convert_selector)
        self.assertNotIn("synthetic-only-password", sql)
        self.assertNotRegex(sql, r"(?is)DELETE\s+FROM\s+(?:public\.)?congregations\s*;")
        with self.assertRaises(ValueError):
            runner.make_fixture("congregation-a; DROP TABLE public.user_access;--")

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
                with mock.patch.object(
                    runner, "_command_exists", return_value="C:/tools/chromedriver.exe"
                ):
                    self.assertEqual(
                        runner._chromedriver_executable(), "C:/tools/chromedriver.exe"
                    )
                with mock.patch.object(runner, "_command_exists", return_value=None):
                    self.assertEqual(
                        runner._chromedriver_executable(), str(installed)
                    )

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
