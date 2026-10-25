"""Contract tests for the local/CI unified verification gates.

The shell gates run in an isolated temporary checkout with stub executables.
This keeps outcomes deterministic and prevents a test from contacting Supabase.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest


REPOSITORY = Path(__file__).resolve().parents[1]
GUARD = REPOSITORY / "scripts" / "local_supabase_guard.py"
REDACTOR = REPOSITORY / "scripts" / "redact_supabase_start.py"


class GateHarness:
    def __init__(self, shell: str, runner_exit: int, supabase_url: str | None):
        self.temp = tempfile.TemporaryDirectory(prefix="unified-gate-")
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        scripts = self.root / "scripts"
        scripts.mkdir()
        shutil.copy2(REPOSITORY / "scripts" / "verify_unified.ps1", scripts)
        shutil.copy2(REPOSITORY / "scripts" / "verify_unified.sh", scripts)
        shutil.copy2(REPOSITORY / "scripts" / "verification_cases.py", scripts)
        shutil.copy2(REPOSITORY / "scripts" / "verification_cases.json", scripts)
        shutil.copy2(GUARD, scripts)
        database_dir = self.root / "supabase" / "tests" / "database"
        database_dir.mkdir(parents=True)
        for scenario in (REPOSITORY / "supabase/tests/database").glob("*_test.sql"):
            (database_dir / scenario.name).touch()
        migrations_dir = self.root / "supabase" / "migrations"
        migrations_dir.mkdir(parents=True)
        for migration in (REPOSITORY / "supabase/migrations").glob("*.sql"):
            (migrations_dir / migration.name).touch()
        self.log_path = self.root / "stub-processes.jsonl"
        self.curl_path = self.root / "curl-calls.txt"
        dispatcher = self.root / "stub_dispatch.py"
        dispatcher.write_text(
            """from __future__ import annotations
import json, os, subprocess, sys
args = sys.argv[1:]
tool = args.pop(0)
with open(os.environ['STUB_PROCESS_LOG'], 'a', encoding='utf-8') as stream:
    stream.write(json.dumps([tool, *args]) + '\\n')
if tool == 'curl':
    with open(os.environ['STUB_CURL_LOG'], 'a', encoding='utf-8') as stream:
        stream.write(json.dumps(args) + '\\n')
    if '-o' not in args:
        print('AUTH_BODY_MARKER')
    raise SystemExit(0)
if tool in ('python', 'python3'):
    if args and args[0] == '-c':
        raise SystemExit(subprocess.call([sys.executable, *args]))
    if args and os.path.basename(args[0]) == 'verification_cases.py':
        raise SystemExit(subprocess.call([sys.executable, *args]))
    if args and os.path.basename(args[0]) == 'test_database.py':
        raise SystemExit(int(os.environ.get('STUB_DATABASE_EXIT', '0')))
    if any(os.path.basename(value) == 'run_unified_journey.py' for value in args):
        raise SystemExit(int(os.environ.get('STUB_RUNNER_EXIT', '0')))
raise SystemExit(0)
""",
            encoding="utf-8",
        )
        self.dispatcher = dispatcher
        self.shell = shell
        self.runner_exit = runner_exit
        self.supabase_url = supabase_url
        self._write_stubs()

    @staticmethod
    def _bash_path(path: Path | str) -> str:
        if os.name != "nt":
            return str(path)
        cygpath = shutil.which("cygpath.exe") or shutil.which("cygpath")
        if not cygpath:
            raise unittest.SkipTest("cygpath is unavailable for Bash path conversion")
        result = subprocess.run(
            [cygpath, "-u", str(path)], capture_output=True, text=True, check=True
        )
        return result.stdout.strip()

    @staticmethod
    def _set_environment_value(env: dict[str, str], name: str, value: str) -> None:
        # Windows treats environment names case-insensitively, but a plain
        # Python dict does not. Remove differently-cased inherited entries so
        # CreateProcess cannot keep the host PATH alongside our isolated one.
        for key in list(env):
            if key.casefold() == name.casefold():
                del env[key]
        env[name] = value

    def _write_stubs(self) -> None:
        python = self._bash_path(sys.executable)
        dispatcher = self._bash_path(self.dispatcher)
        names = ("python", "python3", "flutter", "dart", "psql", "supabase", "git")
        for name in names:
            posix = self.bin / name
            posix.write_text(
                "#!/usr/bin/env bash\n"
                f"exec \"{python}\" \"{dispatcher}\" {name} \"$@\"\n",
                encoding="utf-8",
            )
            try:
                posix.chmod(0o755)
            except OSError:
                pass
            if os.name == "nt":
                cmd = self.bin / f"{name}.cmd"
                cmd.write_text(
                    "@echo off\r\n"
                    f'"{sys.executable}" "{self.dispatcher}" {name} %*\r\n'
                    "@exit /b %ERRORLEVEL%\r\n",
                    encoding="utf-8",
                )
        curl = self.bin / "curl"
        curl.write_text(
            "#!/usr/bin/env bash\n"
            f"exec \"{python}\" \"{dispatcher}\" curl \"$@\"\n",
            encoding="utf-8",
        )
        try:
            curl.chmod(0o755)
        except OSError:
            pass

    def _environment(self) -> dict[str, str]:
        env = os.environ.copy()
        env.pop("SUPABASE_URL", None)
        env.pop("SUPABASE_ANON_KEY", None)
        env.pop("CHROME_EXECUTABLE", None)
        env["STUB_PROCESS_LOG"] = str(self.log_path)
        env["STUB_CURL_LOG"] = str(self.curl_path)
        env["STUB_RUNNER_EXIT"] = str(self.runner_exit)
        if self.supabase_url is not None:
            env["SUPABASE_URL"] = self.supabase_url
            env["SUPABASE_ANON_KEY"] = "test-anon-key"
        # PowerShell uses PATHEXT for .cmd tools. Keep its PATH isolated so
        # curl.exe cannot resolve to the host binary in the remote-target case.
        if self.shell == "powershell" and os.name == "nt":
            self._set_environment_value(env, "PATH", str(self.bin))
            if env.get("ComSpec"):
                env["ComSpec"] = env["ComSpec"]
        elif self.shell == "bash" and os.name == "nt":
            env["STUB_BIN_POSIX"] = self._bash_path(self.bin)
            env["GATE_SCRIPT_POSIX"] = self._bash_path(
                self.root / "scripts" / "verify_unified.sh"
            )
        else:
            host_path = next((value for key, value in env.items() if key.casefold() == "path"), "")
            self._set_environment_value(env, "PATH", str(self.bin) + ":" + host_path)
        return env

    def run(self, extra_env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
        env = self._environment()
        for name, value in (extra_env or {}).items():
            self._set_environment_value(env, name, value)
        if self.shell == "bash":
            bash = shutil.which("bash.exe") or shutil.which("bash")
            if not bash:
                raise unittest.SkipTest("Bash is unavailable")
            if os.name == "nt":
                command = [
                    bash,
                    "--noprofile",
                    "--norc",
                    "-c",
                    'export PATH="$STUB_BIN_POSIX:/usr/bin:/bin"; exec "$GATE_SCRIPT_POSIX"',
                ]
            else:
                command = [bash, "--noprofile", "--norc", str(self.root / "scripts" / "verify_unified.sh")]
        else:
            powershell = shutil.which("pwsh.exe") or shutil.which("pwsh") or shutil.which("powershell.exe")
            if not powershell:
                raise unittest.SkipTest("PowerShell is unavailable")
            command = [
                powershell,
                "-NoProfile",
                "-NonInteractive",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(self.root / "scripts" / "verify_unified.ps1"),
            ]
        return subprocess.run(command, cwd=self.root, env=env, text=True, capture_output=True, timeout=90)

    @property
    def report(self) -> str:
        report = self.root / "build" / "verification" / "unified-report.md"
        return report.read_text(encoding="utf-8") if report.exists() else ""

    def process_calls(self) -> list[list[str]]:
        if not self.log_path.exists():
            return []
        return [json.loads(line) for line in self.log_path.read_text(encoding="utf-8").splitlines()]

    def curl_calls(self) -> list[str]:
        if not self.curl_path.exists():
            return []
        return self.curl_path.read_text(encoding="utf-8").splitlines()

    def close(self) -> None:
        self.temp.cleanup()


class UnifiedGateContractTests(unittest.TestCase):
    def test_gate_executes_every_standalone_sql_case_and_all_manifest_races(self) -> None:
        for shell in self.available_shells():
            with self.subTest(shell=shell):
                harness = GateHarness(shell, runner_exit=2, supabase_url=None)
                try:
                    result = harness.run()
                    self.assertIn(result.returncode, (0, 2), result.stdout + result.stderr)
                    calls = harness.process_calls()
                    database_calls = [row[2:] for row in calls
                                      if len(row) >= 2 and row[0] in ("python", "python3")
                                      and row[1] == "scripts/test_database.py"]
                    trailing_cr = [argument for argv in database_calls
                                   for argument in argv if argument.endswith("\r")]
                    self.assertEqual(
                        trailing_cr,
                        [],
                        "verification gate forwarded CRLF remnants to test_database.py",
                    )
                    observed_sql = {argv[0] for argv in database_calls
                                    if argv and argv[0].endswith("_test.sql")}
                    expected_sql = {path.name for path in (REPOSITORY / "supabase/tests/database").glob("*_test.sql")}
                    self.assertSetEqual(observed_sql, expected_sql,
                                        "verification gate omitted or added a standalone SQL scenario")
                    observed_races = {argv[0] for argv in database_calls
                                      if argv and argv[0].startswith("--")}
                    self.assertSetEqual(observed_races, {
                        "--catalog-concurrency", "--access-concurrency", "--convert-concurrency",
                        "--import-concurrency", "--lifecycle-concurrency",
                        "--ministry-registry-concurrency", "--ministry-academic-concurrency",
                        "--convert-student-concurrency", "--ministry-follow-up-concurrency",
                        "--public-intake-concurrency",
                    }, "verification gate omitted or added a concurrency suite")
                    canonical = next(argv for argv in database_calls
                                     if argv and argv[0] == "canonical_person_link_test.sql")
                    self.assertEqual(canonical[1:], ["--seed-before-migration",
                        "202610200002_canonical_handoff_reads.sql", "--seed-scenario",
                        "canonical_person_link_test.sql"])
                finally:
                    harness.close()

    def test_both_platform_gates_consume_the_shared_argv_generator(self) -> None:
        bash = (REPOSITORY / "scripts" / "verify_unified.sh").read_text(encoding="utf-8")
        powershell = (REPOSITORY / "scripts" / "verify_unified.ps1").read_text(encoding="utf-8")
        self.assertIn("scripts/verification_cases.py --cases-lines", bash)
        self.assertIn("scripts/verification_cases.py' '--cases-lines'", powershell)
        self.assertNotIn("sql=(access_test.sql", bash)
        self.assertNotIn("$sqlNames = @(", powershell)

    def test_database_child_failure_is_retained_as_its_exact_exit_code(self) -> None:
        for shell in self.available_shells():
            with self.subTest(shell=shell):
                harness = GateHarness(shell, runner_exit=2, supabase_url=None)
                try:
                    result = harness.run({"STUB_DATABASE_EXIT": "19"})
                    self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                    self.assertRegex(harness.report, r"SQL canonical_person_link_test\.sql \| FAIL \| 19 \|")
                finally:
                    harness.close()

    def test_invalid_manifest_stops_sql_probes_on_both_platform_gates(self) -> None:
        for shell in self.available_shells():
            with self.subTest(shell=shell):
                harness = GateHarness(shell, runner_exit=2, supabase_url=None)
                try:
                    (harness.root / "scripts" / "verification_cases.json").write_text("{}", encoding="utf-8")
                    result = harness.run()
                    self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                    database_calls = [row for row in harness.process_calls()
                                      if len(row) >= 2 and row[0] in ("python", "python3")
                                      and row[1] == "scripts/test_database.py"]
                    self.assertEqual(database_calls, [], "invalid manifest reached a database scenario")
                    self.assertRegex(harness.report, r"Verification case manifest \| FAIL \|")
                finally:
                    harness.close()

    def test_runner_blocked_is_recorded_as_incomplete(self) -> None:
        for shell in self.available_shells():
            with self.subTest(shell=shell):
                harness = GateHarness(shell, runner_exit=2, supabase_url="http://127.0.0.1:54321")
                try:
                    result = harness.run()
                    calls = harness.process_calls()
                    self.assertTrue(
                        any("run_unified_journey.py" in call for row in calls for call in row),
                        "the shared browser journey runner was not invoked",
                    )
                    self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
                    self.assertIn("Overall: **INCOMPLETE**", harness.report)
                    self.assertRegex(harness.report, r"Integrated registrar-to-attendance browser journey \| BLOCKED \|")
                    gate_log = (harness.root / "build" / "verification" / "unified-commands.log").read_text(encoding="utf-8")
                    self.assertNotIn("test-anon-key", harness.report + gate_log)
                    self.assertNotIn("AUTH_BODY_MARKER", harness.report + gate_log)
                finally:
                    harness.close()

    def test_runner_failure_is_recorded_as_fail(self) -> None:
        for shell in self.available_shells():
            with self.subTest(shell=shell):
                harness = GateHarness(shell, runner_exit=1, supabase_url="http://127.0.0.1:54321")
                try:
                    result = harness.run()
                    self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                    self.assertIn("Overall: **FAIL**", harness.report)
                    self.assertRegex(harness.report, r"Integrated registrar-to-attendance browser journey \| FAIL \|")
                finally:
                    harness.close()

    def test_remote_supabase_url_never_reaches_health_client(self) -> None:
        for shell in self.available_shells():
            with self.subTest(shell=shell):
                harness = GateHarness(shell, runner_exit=2, supabase_url="https://example.invalid")
                try:
                    result = harness.run()
                    self.assertEqual(harness.curl_calls(), [], "a health request reached the curl stub")
                    self.assertRegex(harness.report, r"Auth HTTP health \| BLOCKED \|")
                    self.assertRegex(harness.report, r"Storage HTTP health \| BLOCKED \|")
                    self.assertRegex(harness.report, r"(?i)loopback|local.*url|unsafe")
                    self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
                finally:
                    harness.close()

    def test_health_curl_ignores_curl_configuration_and_ambient_proxies(self) -> None:
        proxies = {
            "HTTP_PROXY": "http://127.0.0.1:18081",
            "HTTPS_PROXY": "http://127.0.0.1:18082",
            "ALL_PROXY": "socks5://127.0.0.1:18083",
            "NO_PROXY": "",
        }
        if "bash" not in self.available_shells():
            self.skipTest("Bash is unavailable")
        harness = GateHarness("bash", runner_exit=2, supabase_url="http://127.0.0.1:54321")
        try:
            result = harness.run(proxies)
            self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
            calls = [json.loads(line) for line in harness.curl_calls()]
            self.assertEqual(len(calls), 2)
            for args in calls:
                self.assertEqual(args[:3], ["-q", "--noproxy", "*"])
                self.assertIn("-o", args)
                self.assertIn("apikey: test-anon-key", args)
        finally:
            harness.close()

    def test_powershell_health_curl_uses_proxy_safe_argument_array(self) -> None:
        script = (REPOSITORY / "scripts" / "verify_unified.ps1").read_text(encoding="utf-8")
        self.assertIn("@('-q','--noproxy','*','-fsS','-o','NUL'", script)

    def test_workflow_exports_only_local_url_and_anon_key(self) -> None:
        workflow = (REPOSITORY / ".github" / "workflows" / "verify-unified.yml").read_text(encoding="utf-8")
        start = workflow.index("      - name: Start local Supabase services")
        end = workflow.index("      - name: Run the unified gate", start)
        status_step = workflow[start:end]
        self.assertNotIn('eval "$(supabase status --output env)"', status_step)
        self.assertIn("supabase status --output json | python3 -c", status_step)
        self.assertIn('status.get("API_URL")', status_step)
        self.assertIn('status.get("ANON_KEY")', status_step)
        self.assertNotIn("SERVICE_ROLE_KEY", status_step)
        self.assertNotIn("DB_URL", status_step)

    def test_workflow_pins_flutter_font_hashes_and_compatible_browser_pair(self) -> None:
        workflow = (REPOSITORY / ".github" / "workflows" / "verify-unified.yml").read_text(encoding="utf-8")
        self.assertIn("flutter-version: '3.47.7'", workflow)
        self.assertIn("chrome-version: '139.0.7258.154'", workflow)
        self.assertIn("chromedriver-version: '139.0.7258.154'", workflow)
        self.assertIn("79e851404657dac2106b3d22ad256d47824a9a5765458edb72c9102a45816d95", workflow)
        self.assertIn("d9865b671a09d683d13a863089d8825e0f61a37696ce5d7d448bc8023aa62453", workflow)

    def test_workflow_uses_action_chrome_path_when_preinstalled_binary_conflicts(self) -> None:
        workflow = (REPOSITORY / ".github" / "workflows" / "verify-unified.yml").read_text(encoding="utf-8")
        lines = workflow.splitlines()
        step_start = lines.index("      - name: Verify pinned Flutter fonts and ChromeDriver")
        run_start = lines.index("        run: |", step_start)
        script_lines = []
        for line in lines[run_start + 1:]:
            if line.startswith("      - "):
                break
            script_lines.append(line[10:] if line.startswith("          ") else "")
        script = "\n".join(script_lines)

        flutter = shutil.which("flutter")
        if not flutter:
            self.skipTest("Flutter SDK fonts are unavailable")
        source_fonts = Path(flutter).resolve().parent.parent / "bin/cache/artifacts/material_fonts"
        with tempfile.TemporaryDirectory(prefix="pinned-chrome-contract-") as temporary:
            root = Path(temporary)
            bash_path = GateHarness._bash_path
            sdk_bin = root / "sdk" / "bin"
            font_dir = sdk_bin / "cache/artifacts/material_fonts"
            fake_bin = root / "preinstalled-bin"
            action_dir = root / "action"
            font_dir.mkdir(parents=True)
            fake_bin.mkdir()
            action_dir.mkdir()
            for filename in ("Roboto-Regular.ttf", "MaterialIcons-Regular.otf"):
                shutil.copy2(source_fonts / filename, font_dir / filename)
            (sdk_bin / "flutter").write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
            (sdk_bin / "flutter").chmod(0o755)
            system_marker = root / "system-chrome-used"
            action_marker = root / "action-chrome-used"
            (fake_bin / "google-chrome").write_text(
                f"#!/bin/sh\nprintf called >> '{bash_path(system_marker)}'\necho 'Google Chrome 140.0.7339.0'\n",
                encoding="utf-8",
            )
            (fake_bin / "google-chrome").chmod(0o755)
            pinned = action_dir / "chrome"
            pinned.write_text(
                f"#!/bin/sh\nprintf called >> '{bash_path(action_marker)}'\necho 'Google Chrome for Testing 139.0.7258.154'\n",
                encoding="utf-8",
            )
            pinned.chmod(0o755)
            (fake_bin / "chromedriver").write_text(
                "#!/bin/sh\necho 'ChromeDriver 139.0.7258.154 (synthetic)'\n", encoding="utf-8"
            )
            (fake_bin / "chromedriver").chmod(0o755)
            env = os.environ.copy()
            env["PATH"] = f"{bash_path(sdk_bin)}:{bash_path(fake_bin)}:/usr/bin:/bin"
            env["CHROME_EXECUTABLE"] = bash_path(pinned)
            result = subprocess.run(
                ["bash", "-e", "-u", "-o", "pipefail", "-c", script],
                env=env, text=True, capture_output=True, check=False,
            )
            self.assertFalse(system_marker.exists(), "a conflicting preinstalled Chrome shadowed the pinned path")
            self.assertTrue(action_marker.exists(), "the setup action's chrome-path was not executed")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

            system_marker.unlink(missing_ok=True)
            action_marker.unlink(missing_ok=True)
            missing_env = env.copy()
            missing_env.pop("CHROME_EXECUTABLE")
            missing = subprocess.run(
                ["bash", "-e", "-u", "-o", "pipefail", "-c", script],
                env=missing_env, text=True, capture_output=True, check=False,
            )
            self.assertNotEqual(missing.returncode, 0, "missing action output must fail closed")
            self.assertFalse(system_marker.exists(), "missing output fell back to a PATH Chrome")

            wrong_marker = root / "wrong-action-chrome-used"
            wrong_pinned = action_dir / "wrong-chrome"
            wrong_pinned.write_text(
                f"#!/bin/sh\nprintf called >> '{bash_path(wrong_marker)}'\necho 'Google Chrome 140.0.7339.0'\n",
                encoding="utf-8",
            )
            wrong_pinned.chmod(0o755)
            good_system_bin = root / "good-system-bin"
            good_system_bin.mkdir()
            good_system_marker = root / "good-system-chrome-used"
            (good_system_bin / "google-chrome").write_text(
                f"#!/bin/sh\nprintf called >> '{bash_path(good_system_marker)}'\necho 'Google Chrome 139.0.7258.154'\n",
                encoding="utf-8",
            )
            (good_system_bin / "google-chrome").chmod(0o755)
            wrong_env = env.copy()
            wrong_env["CHROME_EXECUTABLE"] = bash_path(wrong_pinned)
            wrong_env["PATH"] = f"{bash_path(sdk_bin)}:{bash_path(good_system_bin)}:/usr/bin:/bin"
            wrong = subprocess.run(
                ["bash", "-e", "-u", "-o", "pipefail", "-c", script],
                env=wrong_env, text=True, capture_output=True, check=False,
            )
            self.assertNotEqual(wrong.returncode, 0, "wrong action version must fail closed")
            self.assertTrue(wrong_marker.exists(), "version check did not inspect the action output")
            self.assertFalse(good_system_marker.exists(), "wrong action version fell back to a system Chrome")

        self.assertIn("id: pinned-chrome", workflow)
        action_output = "${{ steps.pinned-chrome.outputs.chrome-path }}"
        self.assertGreaterEqual(workflow.count(f"CHROME_EXECUTABLE: {action_output}"), 2)
        self.assertIn('chrome_bin="$CHROME_EXECUTABLE"', workflow)

    def test_supabase_start_output_is_redacted_and_pipeline_preserves_failure(self) -> None:
        workflow = (REPOSITORY / ".github" / "workflows" / "verify-unified.yml").read_text(encoding="utf-8")
        start = workflow.index("      - name: Start local Supabase services")
        end = workflow.index("      - name: Run the unified gate", start)
        status_step = workflow[start:end]
        self.assertIn("set -euo pipefail", status_step)
        self.assertIn(
            "supabase start --exclude studio,edge-runtime,logflare,vector,imgproxy,supavisor 2>&1 | python3 scripts/redact_supabase_start.py",
            status_step,
        )

    def test_supabase_start_redactor_masks_cli_credentials_and_database_url_password(self) -> None:
        sample = (
            "API URL: http://127.0.0.1:54321\n"
            "anon key: supabase-anon-secret\n"
            "service_role key: supabase-service-secret\n"
            "JWT secret: local-jwt-secret\n"
            "secret key: generic-secret-key\n"
            "standalone token: eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJsb2NhbCJ9.jwt-signature\n"
            "Supabase secret: sb_secret_example-secret-token\n"
            "Supabase publishable: sb_publishable_example-public-token\n"
            "DB URL: postgresql://postgres:database-password@127.0.0.1:54322/postgres\n"
            "SUPABASE_ANON_KEY=environment-anon-secret\n"
        )
        result = subprocess.run(
            [sys.executable, str(REDACTOR)],
            input=sample,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("API URL: http://127.0.0.1:54321", result.stdout)
        self.assertIn("anon key: [redacted]", result.stdout)
        self.assertIn("service_role key: [redacted]", result.stdout)
        self.assertIn("JWT secret: [redacted]", result.stdout)
        self.assertIn("secret key: [redacted]", result.stdout)
        self.assertIn("standalone token: [redacted]", result.stdout)
        self.assertIn("Supabase secret: [redacted]", result.stdout)
        self.assertIn("Supabase publishable: [redacted]", result.stdout)
        self.assertIn(
            "postgresql://postgres:[redacted]@127.0.0.1:54322/postgres",
            result.stdout,
        )
        for secret in (
            "supabase-anon-secret",
            "supabase-service-secret",
            "local-jwt-secret",
            "generic-secret-key",
            "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJsb2NhbCJ9.jwt-signature",
            "sb_secret_example-secret-token",
            "sb_publishable_example-public-token",
            "database-password",
            "environment-anon-secret",
        ):
            self.assertNotIn(secret, result.stdout)

    def test_supabase_start_redaction_keeps_start_command_failure_nonzero(self) -> None:
        bash = shutil.which("bash.exe") or shutil.which("bash")
        if not bash:
            self.skipTest("Bash is unavailable")
        python = GateHarness._bash_path(sys.executable)
        redactor = GateHarness._bash_path(REDACTOR)
        command = (
            "set -euo pipefail; "
            "supabase() { printf '%s\\n' 'anon key: pipeline-anon-secret'; "
            "printf '%s\\n' 'service_role key: pipeline-role-secret' >&2; return 23; }; "
            "supabase start --exclude studio,edge-runtime,logflare,vector,imgproxy,supavisor "
            f"2>&1 | {shlex.quote(python)} {shlex.quote(redactor)}"
        )
        result = subprocess.run(
            [bash, "--noprofile", "--norc", "-c", command],
            cwd=REPOSITORY,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 23, result.stdout + result.stderr)
        self.assertIn("anon key: [redacted]", result.stdout)
        self.assertIn("service_role key: [redacted]", result.stdout)
        self.assertNotIn("pipeline-anon-secret", result.stdout)
        self.assertNotIn("pipeline-role-secret", result.stdout)

    @staticmethod
    def available_shells() -> list[str]:
        shells = ["bash"] if (shutil.which("bash.exe") or shutil.which("bash")) else []
        if shutil.which("pwsh.exe") or shutil.which("pwsh") or shutil.which("powershell.exe"):
            shells.append("powershell")
        return shells


if __name__ == "__main__":
    unittest.main(verbosity=2)
