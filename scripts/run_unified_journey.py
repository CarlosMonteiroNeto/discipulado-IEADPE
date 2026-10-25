"""Run the unified Flutter journey against an explicitly local Supabase stack.

The runner deliberately ignores ambient Supabase and PostgreSQL configuration.
It learns endpoints only from `supabase status --output json`, rejects anything
except loopback, and keeps the local service-role key in this host process.
"""

from __future__ import annotations

import argparse
import hmac
import http.server
import json
import os
import re
import secrets
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import time
import uuid
from dataclasses import dataclass, field, replace
from pathlib import Path
from typing import Callable
from urllib.error import HTTPError
from urllib.parse import quote, urlsplit

from local_supabase_guard import (
    DatabaseTarget,
    UnsafeSupabaseTarget,
    parse_database_url,
    request_json,
    require_loopback_url,
)

PASS = 0
FAIL = 1
BLOCKED = 2

ROOT = Path(__file__).resolve().parents[1]
SUPERVISOR_ROLE = "Membro da supervisão das campanhas"
DIRECTION_ROLE = "Membro da direção da campanha"


class PrerequisiteBlocked(RuntimeError):
    """A local service or tool needed to run the journey is unavailable."""


class JourneyFailure(RuntimeError):
    """The local journey or one of its assertions failed."""


@dataclass(frozen=True)
class LocalSupabase:
    api_url: str
    database_url: str = field(repr=False)
    anon_key: str = field(repr=False)
    service_role_key: str = field(repr=False)


@dataclass(frozen=True)
class JourneyFixture:
    run_id: str
    congregation_a_id: str
    congregation_b_id: str
    class_id: str
    session_id: str
    student_id: str
    person_id: str
    enrollment_id: str
    attack_enrollment_id: str
    registrar_id: str
    supervisor_id: str
    direction_id: str
    out_of_scope_id: str
    registrar_email: str
    supervisor_email: str
    direction_email: str
    out_of_scope_email: str
    registrar_password: str = field(repr=False)
    supervisor_password: str = field(repr=False)
    direction_password: str = field(repr=False)
    out_of_scope_password: str = field(repr=False)
    supervisor_assignment_id: str
    direction_assignment_id: str
    out_of_scope_assignment_id: str
    convert_name: str
    public_convert_name: str
    public_submission_id: str | None = None

    @property
    def run_slug(self) -> str:
        return self.run_id.replace("-", "")

    @property
    def congregation_a_name(self) -> str:
        return f"Journey {self.run_slug} A"

    @property
    def congregation_b_name(self) -> str:
        return f"Journey {self.run_slug} B"

    def browser_values(self) -> dict[str, str]:
        """Values required by the browser; this intentionally excludes admin credentials."""

        return {
            "JOURNEY_RUN_ID": self.run_id,
            "JOURNEY_CONGREGATION_A_ID": self.congregation_a_id,
            "JOURNEY_CONGREGATION_A_NAME": self.congregation_a_name,
            "JOURNEY_CONGREGATION_B_ID": self.congregation_b_id,
            "JOURNEY_CLASS_ID": self.class_id,
            "JOURNEY_SESSION_ID": self.session_id,
            "JOURNEY_STUDENT_ID": self.student_id,
            "JOURNEY_PERSON_ID": self.person_id,
            "JOURNEY_ENROLLMENT_ID": self.enrollment_id,
            "JOURNEY_ATTACK_ENROLLMENT_ID": self.attack_enrollment_id,
            "JOURNEY_REGISTRAR_EMAIL": self.registrar_email,
            "JOURNEY_REGISTRAR_PASSWORD": self.registrar_password,
            "JOURNEY_SUPERVISOR_EMAIL": self.supervisor_email,
            "JOURNEY_SUPERVISOR_PASSWORD": self.supervisor_password,
            "JOURNEY_DIRECTION_EMAIL": self.direction_email,
            "JOURNEY_DIRECTION_PASSWORD": self.direction_password,
            "JOURNEY_OUT_OF_SCOPE_EMAIL": self.out_of_scope_email,
            "JOURNEY_OUT_OF_SCOPE_PASSWORD": self.out_of_scope_password,
            "JOURNEY_CONVERT_NAME": self.convert_name,
            "JOURNEY_PUBLIC_CONVERT_NAME": self.public_convert_name,
            "JOURNEY_DIRECTION_ASSIGNMENT_ID": self.direction_assignment_id,
            "JOURNEY_ALLOWED_ORIGIN": "http://127.0.0.1:7357",
        }


@dataclass(frozen=True)
class JourneyUser:
    id: str
    email: str
    password: str = field(repr=False)


def _uuid(value: str) -> uuid.UUID:
    try:
        result = uuid.UUID(value)
    except (AttributeError, TypeError, ValueError) as error:
        raise ValueError("A valid UUID is required for this journey fixture.") from error
    if str(result) != value.lower():
        raise ValueError("A canonical UUID is required for this journey fixture.")
    return result


def make_fixture(
    run_id: str | None = None,
    *,
    password_factory: Callable[[], str] | None = None,
) -> JourneyFixture:
    """Create deterministic IDs and unique, synthetic credentials for one run."""

    parsed = _uuid(run_id or str(uuid.uuid4()))
    if parsed.version is None:
        raise ValueError("A versioned UUID is required for this journey fixture.")
    password_factory = password_factory or (lambda: secrets.token_urlsafe(24))

    def id_for(label: str) -> str:
        return str(uuid.uuid5(parsed, f"ieadpe-unified-journey:{label}"))

    prefix = parsed.hex
    return JourneyFixture(
        run_id=str(parsed),
        congregation_a_id=id_for("congregation-a"),
        congregation_b_id=id_for("congregation-b"),
        class_id=id_for("class-a"),
        session_id=id_for("session-a"),
        student_id=id_for("student"),
        person_id=id_for("person"),
        enrollment_id=id_for("expected-enrollment"),
        attack_enrollment_id=id_for("out-of-scope-enrollment-attempt"),
        registrar_id=id_for("registrar"),
        supervisor_id=id_for("supervisor"),
        direction_id=id_for("direction"),
        out_of_scope_id=id_for("out-of-scope"),
        registrar_email=f"journey-{prefix}-registrar@example.test",
        supervisor_email=f"journey-{prefix}-supervisor@example.test",
        direction_email=f"journey-{prefix}-direction@example.test",
        out_of_scope_email=f"journey-{prefix}-outside@example.test",
        registrar_password=password_factory(),
        supervisor_password=password_factory(),
        direction_password=password_factory(),
        out_of_scope_password=password_factory(),
        supervisor_assignment_id=id_for("supervisor-assignment"),
        direction_assignment_id=id_for("direction-assignment-a"),
        out_of_scope_assignment_id=id_for("direction-assignment-b"),
        convert_name=f"Journey Convert {prefix}",
        public_convert_name=f"Journey Pending Convert {prefix}",
    )


def _sql_text(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def _sql_uuid(value: str) -> str:
    return f"{_sql_text(str(_uuid(value)))}::uuid"


def setup_sql(fixture: JourneyFixture) -> str:
    """Seed only this run's congregations, access rows, class, and session."""

    f = fixture
    return f"""BEGIN;
INSERT INTO public.congregations(id,name) VALUES
  ({_sql_uuid(f.congregation_a_id)},{_sql_text(f.congregation_a_name)}),
  ({_sql_uuid(f.congregation_b_id)},{_sql_text(f.congregation_b_name)});
INSERT INTO public.user_access(id,user_email,role,congregation_id) VALUES
  ({_sql_uuid(f.supervisor_assignment_id)},{_sql_text(f.supervisor_email)},{_sql_text(SUPERVISOR_ROLE)},NULL),
  ({_sql_uuid(f.direction_assignment_id)},{_sql_text(f.direction_email)},{_sql_text(DIRECTION_ROLE)},{_sql_uuid(f.congregation_a_id)}),
  ({_sql_uuid(f.out_of_scope_assignment_id)},{_sql_text(f.out_of_scope_email)},{_sql_text(DIRECTION_ROLE)},{_sql_uuid(f.congregation_b_id)});
INSERT INTO public.ministry_classes(id,congregation_id,name,normalized_name,start_date,updated_by)
VALUES ({_sql_uuid(f.class_id)},{_sql_uuid(f.congregation_a_id)},
  {_sql_text('Journey Class ' + f.run_slug)},{_sql_text('journey class ' + f.run_slug)},
  (now() AT TIME ZONE 'America/Recife')::date,{_sql_uuid(f.direction_id)});
INSERT INTO public.ministry_sessions(id,congregation_id,class_id,session_date,topic,updated_by)
VALUES ({_sql_uuid(f.session_id)},{_sql_uuid(f.congregation_a_id)},
  {_sql_uuid(f.class_id)},(now() AT TIME ZONE 'America/Recife')::date,
  {_sql_text('Journey ' + f.run_slug)},{_sql_uuid(f.direction_id)});
COMMIT;"""


def cleanup_sql(fixture: JourneyFixture) -> str:
    """Delete only this run's IDs and descendants tied to its synthetic users."""

    f = fixture
    convert_ids = (
        "SELECT c.id FROM public.converts c "
        f"WHERE c.internal_id=c.id::text AND ((c.created_by={_sql_uuid(f.registrar_id)} "
        f"AND c.name={_sql_text(f.convert_name)} AND c.congregation_id={_sql_uuid(f.congregation_a_id)}) "
        f"OR (c.created_by={_sql_uuid(f.supervisor_id)} "
        f"AND c.name={_sql_text(f.public_convert_name)} AND c.congregation_id={_sql_uuid(f.congregation_a_id)}))"
    )
    return f"""-- run_id: {f.run_id}
BEGIN;
CREATE TEMP TABLE journey_owned_converts ON COMMIT DROP AS
 {convert_ids};
CREATE TEMP TABLE journey_owned_public_submissions ON COMMIT DROP AS
 SELECT DISTINCT s.id FROM private.public_intake_submissions s
 LEFT JOIN private.public_intake_decisions d ON d.submission_id=s.id
  WHERE s.id={_sql_uuid(f.public_submission_id) if f.public_submission_id else 'NULL::uuid'}
     OR (s.congregation_id={_sql_uuid(f.congregation_a_id)}
         AND s.draft->'person'->>'name'={_sql_text(f.public_convert_name)})
    OR d.official_convert_id IN (SELECT id FROM journey_owned_converts);
CREATE TEMP TABLE journey_owned_students ON COMMIT DROP AS
 SELECT s.id FROM public.ministry_students s
 WHERE s.congregation_id={_sql_uuid(f.congregation_a_id)}
   AND (s.id={_sql_uuid(f.student_id)} OR s.convert_id IN (SELECT id FROM journey_owned_converts));
CREATE TEMP TABLE journey_owned_enrollments ON COMMIT DROP AS
 SELECT e.id FROM public.ministry_enrollments e
 WHERE e.congregation_id={_sql_uuid(f.congregation_a_id)}
   AND (e.class_id={_sql_uuid(f.class_id)} OR e.student_id IN (SELECT id FROM journey_owned_students));
CREATE TEMP TABLE journey_owned_sessions ON COMMIT DROP AS
 SELECT s.id FROM public.ministry_sessions s
 WHERE s.congregation_id={_sql_uuid(f.congregation_a_id)}
   AND s.class_id={_sql_uuid(f.class_id)};
CREATE TEMP TABLE journey_owned_people ON COMMIT DROP AS
 SELECT { _sql_uuid(f.person_id) } AS id
 UNION
 SELECT c.person_id FROM public.converts c
 WHERE c.id IN (SELECT id FROM journey_owned_converts) AND c.person_id IS NOT NULL
 UNION
 SELECT s.person_id FROM public.ministry_students s
 JOIN journey_owned_students owned ON owned.id=s.id
 WHERE s.person_id IS NOT NULL;
DELETE FROM public.ministry_attendance
 WHERE session_id IN (SELECT id FROM journey_owned_sessions)
    OR enrollment_id IN (SELECT id FROM journey_owned_enrollments);
DELETE FROM public.ministry_session_roster
 WHERE session_id IN (SELECT id FROM journey_owned_sessions)
    OR enrollment_id IN (SELECT id FROM journey_owned_enrollments);
DELETE FROM public.ministry_enrollments
 WHERE id IN (SELECT id FROM journey_owned_enrollments);
DO $journey_cleanup$
DECLARE owned_session record;
BEGIN
 FOR owned_session IN
  WITH RECURSIVE session_lineage(id,depth) AS (
   SELECT s.id,0 FROM public.ministry_sessions s
   JOIN journey_owned_sessions owned ON owned.id=s.id
   WHERE s.replaces_session_id IS NULL OR NOT EXISTS(
    SELECT FROM journey_owned_sessions parent WHERE parent.id=s.replaces_session_id)
   UNION ALL
   SELECT child.id,parent.depth+1 FROM public.ministry_sessions child
   JOIN journey_owned_sessions owned ON owned.id=child.id
   JOIN session_lineage parent ON child.replaces_session_id=parent.id
  )
  SELECT id,max(depth) AS depth FROM session_lineage
  GROUP BY id ORDER BY max(depth) DESC
 LOOP
  DELETE FROM public.ministry_sessions s
  WHERE s.id=owned_session.id AND EXISTS(
   SELECT FROM journey_owned_sessions owned WHERE owned.id=s.id);
 END LOOP;
END
$journey_cleanup$;
DELETE FROM public.ministry_students
 WHERE id IN (SELECT id FROM journey_owned_students);
DELETE FROM private.public_intake_decisions
 WHERE submission_id IN (SELECT id FROM journey_owned_public_submissions);
DELETE FROM private.public_intake_receipts
 WHERE submission_id IN (SELECT id FROM journey_owned_public_submissions);
DELETE FROM private.public_intake_accepted_events
 WHERE submission_id IN (SELECT id FROM journey_owned_public_submissions);
DELETE FROM private.public_intake_submissions
 WHERE id IN (SELECT id FROM journey_owned_public_submissions);
DELETE FROM public.convert_events
 WHERE convert_id IN (SELECT id FROM journey_owned_converts);
DELETE FROM public.converts
 WHERE id IN (SELECT id FROM journey_owned_converts);
DELETE FROM public.ministry_people
 WHERE id IN (SELECT id FROM journey_owned_people)
   AND congregation_id={_sql_uuid(f.congregation_a_id)};
DELETE FROM public.ministry_classes
 WHERE id={_sql_uuid(f.class_id)} AND congregation_id={_sql_uuid(f.congregation_a_id)};
DELETE FROM public.user_access
 WHERE (id={_sql_uuid(f.supervisor_assignment_id)} AND user_email={_sql_text(f.supervisor_email)}
        AND role={_sql_text(SUPERVISOR_ROLE)} AND congregation_id IS NULL)
    OR (id={_sql_uuid(f.direction_assignment_id)} AND user_email={_sql_text(f.direction_email)}
        AND role={_sql_text(DIRECTION_ROLE)} AND congregation_id={_sql_uuid(f.congregation_a_id)})
    OR (id={_sql_uuid(f.out_of_scope_assignment_id)} AND user_email={_sql_text(f.out_of_scope_email)}
        AND role={_sql_text(DIRECTION_ROLE)} AND congregation_id={_sql_uuid(f.congregation_b_id)});
DELETE FROM private.congregation_week_guards
 WHERE congregation_id IN ({_sql_uuid(f.congregation_a_id)},{_sql_uuid(f.congregation_b_id)});
DELETE FROM private.mutation_receipts WHERE actor_uid IN (
  {_sql_uuid(f.registrar_id)},{_sql_uuid(f.supervisor_id)},
  {_sql_uuid(f.direction_id)},{_sql_uuid(f.out_of_scope_id)});
DELETE FROM auth.users WHERE
  (id={_sql_uuid(f.registrar_id)} AND email={_sql_text(f.registrar_email)}) OR
  (id={_sql_uuid(f.supervisor_id)} AND email={_sql_text(f.supervisor_email)}) OR
  (id={_sql_uuid(f.direction_id)} AND email={_sql_text(f.direction_email)}) OR
  (id={_sql_uuid(f.out_of_scope_id)} AND email={_sql_text(f.out_of_scope_email)});
DELETE FROM public.congregations WHERE
  (id={_sql_uuid(f.congregation_a_id)} AND name={_sql_text(f.congregation_a_name)}) OR
  (id={_sql_uuid(f.congregation_b_id)} AND name={_sql_text(f.congregation_b_name)});
COMMIT;"""


def public_intake_acceptance_sql(fixture: JourneyFixture) -> str:
    """Check the one run-owned submission, erased payload, and canonical row."""

    if fixture.public_submission_id is None:
        raise ValueError("The browser did not report an intake submission ID.")
    f = fixture
    return f"""WITH target AS (
 SELECT s.id,s.status,s.draft,s.payload_erased_at
 FROM private.public_intake_submissions s
 WHERE s.id={_sql_uuid(f.public_submission_id)}
   AND s.congregation_id={_sql_uuid(f.congregation_a_id)}
), decided AS (
 SELECT d.submission_id,d.outcome,d.reviewer_uid,d.official_convert_id
 FROM private.public_intake_decisions d
 JOIN target t ON t.id=d.submission_id
)
SELECT CASE WHEN
 (SELECT count(*) FROM target)=1
 AND (SELECT count(*) FROM target
      WHERE status='approved' AND draft IS NULL AND payload_erased_at IS NOT NULL)=1
 AND (SELECT count(*) FROM decided
      WHERE outcome='approved' AND reviewer_uid={_sql_uuid(f.supervisor_id)})=1
 AND (SELECT count(*) FROM public.converts c
      JOIN decided d ON d.official_convert_id=c.id
      WHERE c.internal_id=c.id::text
        AND c.created_by={_sql_uuid(f.supervisor_id)}
        AND c.name={_sql_text(f.public_convert_name)}
        AND c.congregation_id={_sql_uuid(f.congregation_a_id)})=1
 AND (SELECT count(*) FROM private.public_intake_receipts r
      JOIN target t ON t.id=r.submission_id)=1
 AND (SELECT count(*) FROM private.public_intake_accepted_events e
      JOIN target t ON t.id=e.submission_id)=1
 THEN 'PASS' ELSE 'FAIL' END;"""


def revocation_sql(fixture: JourneyFixture, assignment_id: str) -> str:
    """Revoke only the fixed direction assignment for this fixture."""

    f = fixture
    if assignment_id != fixture.direction_assignment_id:
        raise ValueError("Revocation target is not the fixed journey assignment.")
    return f"""WITH revoked AS (
  DELETE FROM public.user_access
   WHERE id={_sql_uuid(f.direction_assignment_id)}
     AND user_id={_sql_uuid(f.direction_id)}
     AND user_email={_sql_text(f.direction_email)}
     AND role={_sql_text(DIRECTION_ROLE)}
     AND congregation_id={_sql_uuid(f.congregation_a_id)}
   RETURNING user_id
)
UPDATE private.access_versions v SET version=v.version+1
FROM revoked r WHERE v.user_id=r.user_id;"""


def flutter_settings(
    *,
    api_url: str,
    anon_key: str,
    service_role_key: str,
    fixture: dict[str, str],
) -> dict[str, str]:
    """Build allowlisted compile-time values without carrying admin secrets."""

    api_url = require_loopback_url(api_url)
    if not anon_key or not service_role_key:
        raise ValueError("Local Supabase keys are missing.")
    allowed = {
        "JOURNEY_RUN_ID",
        "JOURNEY_CONGREGATION_A_ID",
        "JOURNEY_CONGREGATION_B_ID",
        "JOURNEY_CLASS_ID",
        "JOURNEY_SESSION_ID",
        "JOURNEY_STUDENT_ID",
        "JOURNEY_PERSON_ID",
        "JOURNEY_ENROLLMENT_ID",
        "JOURNEY_ATTACK_ENROLLMENT_ID",
        "JOURNEY_REGISTRAR_EMAIL",
        "JOURNEY_REGISTRAR_PASSWORD",
        "JOURNEY_SUPERVISOR_EMAIL",
        "JOURNEY_SUPERVISOR_PASSWORD",
        "JOURNEY_DIRECTION_EMAIL",
        "JOURNEY_DIRECTION_PASSWORD",
        "JOURNEY_OUT_OF_SCOPE_EMAIL",
        "JOURNEY_OUT_OF_SCOPE_PASSWORD",
        "JOURNEY_CONVERT_NAME",
        "JOURNEY_PUBLIC_CONVERT_NAME",
        "JOURNEY_CONGREGATION_A_NAME",
        "JOURNEY_INTAKE_TEST_ENDPOINT",
        "JOURNEY_DIRECTION_ASSIGNMENT_ID",
        "JOURNEY_ALLOWED_ORIGIN",
        "JOURNEY_CONTROL_URL",
        "JOURNEY_CONTROL_CAPABILITY",
    }
    if any(key not in allowed for key in fixture):
        raise ValueError("Unexpected value requested for the Flutter test bundle.")
    intake_endpoint = fixture.get("JOURNEY_INTAKE_TEST_ENDPOINT")
    if intake_endpoint is not None:
        endpoint = urlsplit(intake_endpoint)
        if (
            require_loopback_url(intake_endpoint, label="intake test endpoint")
            != intake_endpoint
            or endpoint.path != "/functions/v1/public-intake"
            or endpoint.query
            or endpoint.fragment
        ):
            raise UnsafeSupabaseTarget("Unsafe local intake test endpoint.")
    return {
        "SUPABASE_URL": api_url,
        "SUPABASE_PUBLISHABLE_KEY": anon_key,
        **fixture,
    }


class RevocationControl:
    """Loopback-only, capability-protected control for one fixed assignment."""

    def __init__(
        self,
        *,
        run_id: str,
        assignment_id: str,
        user_id: str,
        congregation_id: str,
        allowed_origin: str,
        revoke: Callable[[str], object],
    ) -> None:
        self.run_id = str(_uuid(run_id))
        self.assignment_id = str(_uuid(assignment_id))
        self.user_id = str(_uuid(user_id))
        self.congregation_id = str(_uuid(congregation_id))
        self.allowed_origin = allowed_origin
        origin = urlsplit(allowed_origin)
        if (
            require_loopback_url(allowed_origin, label="control Origin") != allowed_origin
            or origin.path != ""
            or origin.query
            or origin.fragment
        ):
            raise UnsafeSupabaseTarget("Unsafe revocation control Origin.")
        self.capability = secrets.token_urlsafe(32)
        self._revoke = revoke
        self._revoked = False
        self._lock = threading.Lock()
        owner = self

        class Handler(http.server.BaseHTTPRequestHandler):
            server_version = "LocalJourneyControl/1"
            sys_version = ""

            def log_message(self, _format: str, *_args: object) -> None:
                return

            def _finish(self, status: int, *, cors: bool = False) -> None:
                body = (
                    b""
                    if status == 204
                    else (b"{\"ok\":true}" if status == 200 else b"{\"ok\":false}")
                )
                self.send_response(status)
                if cors:
                    self.send_header("Access-Control-Allow-Origin", owner.allowed_origin)
                    self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
                    self.send_header("Access-Control-Allow-Headers", "X-Run-Capability, Content-Type")
                    self.send_header("Vary", "Origin")
                self.send_header("Content-Type", "application/json")
                self.send_header("Cache-Control", "no-store")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def do_OPTIONS(self) -> None:
                if self.headers.get("Origin") != owner.allowed_origin:
                    self._finish(403)
                    return
                if self.path != f"/revoke/{owner.assignment_id}":
                    self._finish(404)
                    return
                self._finish(204, cors=True)

            def do_POST(self) -> None:
                if self.headers.get("Origin") != owner.allowed_origin:
                    self._finish(403)
                    return
                if self.path != f"/revoke/{owner.assignment_id}":
                    self._finish(404)
                    return
                if not hmac.compare_digest(
                    self.headers.get("X-Run-Capability", ""), owner.capability
                ):
                    self._finish(401, cors=True)
                    return
                try:
                    length = int(self.headers.get("Content-Length", "0"))
                except ValueError:
                    self._finish(400, cors=True)
                    return
                if length != 0:
                    self._finish(400, cors=True)
                    return
                with owner._lock:
                    if not owner._revoked:
                        try:
                            owner._revoke(owner.assignment_id)
                        except Exception:
                            self._finish(500, cors=True)
                            return
                        owner._revoked = True
                self._finish(200, cors=True)

        self._server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self._server.daemon_threads = True
        self.address = self._server.server_address[:2]
        self._thread = threading.Thread(target=self._server.serve_forever, daemon=True)
        self._thread.start()

    def close(self) -> None:
        self._server.shutdown()
        self._server.server_close()
        self._thread.join(timeout=3)


class LocalPublicIntakeTestFunction:
    """Serve the production intake handler with local-only deterministic dependencies."""

    def __init__(
        self,
        config: LocalSupabase,
        fixture: JourneyFixture,
        *,
        allowed_origin: str,
    ) -> None:
        origin = urlsplit(allowed_origin)
        if (
            require_loopback_url(allowed_origin, label="intake test Origin")
            != allowed_origin
            or origin.path
            or origin.query
            or origin.fragment
        ):
            raise UnsafeSupabaseTarget("Unsafe local intake test Origin.")
        self.config = config
        self.fixture = fixture
        self.allowed_origin = allowed_origin
        self.port = _free_loopback_port()
        self.endpoint = (
            f"http://127.0.0.1:{self.port}/functions/v1/public-intake"
        )
        self.health_url = f"http://127.0.0.1:{self.port}/__journey_health"
        self.process: subprocess.Popen[bytes] | None = None

    def start(self) -> None:
        deno = _deno_executable()
        if deno is None:
            raise PrerequisiteBlocked("Deno is unavailable for the local intake test.")
        api = urlsplit(self.config.api_url)
        if api.scheme != "http" or api.hostname not in {
            "localhost",
            "127.0.0.1",
            "::1",
        }:
            raise UnsafeSupabaseTarget("Unsafe local intake test API URL.")
        api_host = f"[{api.hostname}]" if ":" in api.hostname else api.hostname
        api_authority = f"{api_host}:{api.port or 80}"
        script = ROOT / "scripts" / "public_intake_test_server.ts"
        if not script.is_file():
            raise PrerequisiteBlocked("Local intake test handler is missing.")
        env = _safe_environment()
        for key in (
            "JOURNEY_LOCAL_API_URL",
            "JOURNEY_LOCAL_SERVICE_ROLE_KEY",
            "JOURNEY_RUN_ID",
            "JOURNEY_ALLOWED_ORIGIN",
            "JOURNEY_TEST_PORT",
        ):
            env.pop(key, None)
        env.update(
            {
                "JOURNEY_LOCAL_API_URL": self.config.api_url,
                "JOURNEY_LOCAL_SERVICE_ROLE_KEY": self.config.service_role_key,
                "JOURNEY_RUN_ID": self.fixture.run_id,
                "JOURNEY_ALLOWED_ORIGIN": self.allowed_origin,
                "JOURNEY_TEST_PORT": str(self.port),
            }
        )
        command = [
            deno,
            "run",
            f"--allow-net=127.0.0.1:{self.port},{api_authority}",
            "--allow-env=JOURNEY_LOCAL_API_URL,JOURNEY_LOCAL_SERVICE_ROLE_KEY,JOURNEY_RUN_ID,JOURNEY_ALLOWED_ORIGIN,JOURNEY_TEST_PORT",
            str(script),
        ]
        try:
            self.process = subprocess.Popen(
                command,
                cwd=ROOT,
                env=env,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except OSError as error:
            raise PrerequisiteBlocked("Local intake test handler could not start.") from error
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            process = self.process
            if process is None or process.poll() is not None:
                self.close()
                raise PrerequisiteBlocked("Local intake test handler stopped during startup.")
            try:
                health = request_json(self.health_url, timeout=1)
                if health == {"ready": True}:
                    return
            except Exception:
                pass
            time.sleep(0.1)
        self.close()
        raise PrerequisiteBlocked("Local intake test handler did not become ready.")

    def close(self) -> None:
        process = self.process
        self.process = None
        if process is None or process.poll() is not None:
            return
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=3)


def _safe_environment() -> dict[str, str]:
    """Remove ambient backend/proxy/libpq settings from every child process."""

    blocked = ("SUPABASE_", "PG", "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY")
    env = {
        key: value
        for key, value in os.environ.items()
        if not key.upper().startswith(blocked)
        and key.upper() not in {"DATABASE_URL", "SUPABASE_URL"}
    }
    return env


def _supabase_executable() -> str | None:
    """Resolve a native Supabase CLI binary so Windows script shims stay bounded."""
    native = _command_exists("supabase.exe") if os.name == "nt" else None
    if native:
        return native
    executable = _command_exists("supabase")
    if executable is None or os.name != "nt":
        return executable
    if Path(executable).suffix.lower() not in {".cmd", ".bat", ".ps1"}:
        return executable
    local_app_data = os.environ.get("LOCALAPPDATA")
    if not local_app_data:
        return None
    candidate = (
        Path(local_app_data)
        / "Programs"
        / "supabase-cli"
        / "node_modules"
        / "@supabase"
        / "cli-windows-x64"
        / "bin"
        / "supabase.exe"
    )
    return str(candidate) if candidate.is_file() else None


def read_supabase_status() -> dict[str, object]:
    """Read local CLI status only; never consult an environment URL fallback."""

    executable = _supabase_executable()
    if executable is None:
        raise PrerequisiteBlocked("Supabase CLI is unavailable.")
    try:
        result = subprocess.run(
            [executable, "status", "--output", "json"],
            cwd=ROOT,
            env=_safe_environment(),
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        raise PrerequisiteBlocked("Local Supabase status is unavailable.") from error
    if result.returncode != 0:
        raise PrerequisiteBlocked("Local Supabase stack is not running.")
    try:
        value = json.loads(result.stdout)
    except (TypeError, json.JSONDecodeError) as error:
        raise PrerequisiteBlocked("Supabase CLI did not return local JSON status.") from error
    if not isinstance(value, dict):
        raise PrerequisiteBlocked("Supabase CLI returned an invalid local status.")
    return value


def local_supabase_from_status(status: dict[str, object]) -> LocalSupabase:
    """Validate both endpoints before any HTTP request or SQL operation."""

    api = status.get("API_URL")
    database = status.get("DB_URL")
    anon_key = status.get("ANON_KEY")
    service_key = status.get("SERVICE_ROLE_KEY")
    if not all(isinstance(value, str) and value for value in (api, database, anon_key, service_key)):
        raise PrerequisiteBlocked("Local Supabase status is missing required services.")
    checked_api = require_loopback_url(api, label="API URL")
    api_parts = urlsplit(checked_api)
    if api_parts.path not in {"", "/"}:
        raise UnsafeSupabaseTarget("Unsafe local Supabase API URL.")
    parse_database_url(database)
    return LocalSupabase(checked_api, database, anon_key, service_key)


def run_sql(sql: str, database_url: str) -> str:
    """Run SQL over one explicitly parsed loopback libpq URI."""

    target: DatabaseTarget = parse_database_url(database_url)
    executable = shutil.which("psql")
    if executable is None:
        raise PrerequisiteBlocked("PostgreSQL client is unavailable.")
    env = _safe_environment()
    env["PGPASSWORD"] = target.password
    command = [
        executable,
        "-X",
        "-w",
        "-v",
        "ON_ERROR_STOP=1",
        "-h",
        target.host,
        "-p",
        str(target.port),
        "-U",
        target.user,
        "-d",
        target.database,
        "-At",
        "-c",
        sql,
    ]
    try:
        result = subprocess.run(
            command,
            cwd=ROOT,
            env=env,
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        raise PrerequisiteBlocked("Local PostgreSQL is unavailable.") from error
    if result.returncode != 0:
        raise JourneyFailure("A local database operation failed.")
    return result.stdout.strip()


def cleanup_public_intake_photo(config: LocalSupabase, fixture: JourneyFixture) -> None:
    """Remove only the exact anonymous-upload probe object from this local run."""

    api_url = require_loopback_url(config.api_url, label="API URL")
    api_parts = urlsplit(api_url)
    if api_parts.path not in {"", "/"}:
        raise UnsafeSupabaseTarget("Unsafe local storage cleanup API URL.")
    object_path = f"journey-test/{fixture.run_id}/unsigned.jpg"
    endpoint = (
        api_url.rstrip("/")
        + "/storage/v1/object/convert-photos/"
        + quote(object_path, safe="/")
    )
    try:
        request_json(
            endpoint,
            method="DELETE",
            headers={
                "apikey": config.service_role_key,
                "Authorization": f"Bearer {config.service_role_key}",
            },
            timeout=10,
        )
    except HTTPError as error:
        if error.code != 404:
            raise


def _admin_create_user(config: LocalSupabase, user: JourneyUser) -> None:
    body = json.dumps(
        {
            "id": user.id,
            "email": user.email,
            "password": user.password,
            "email_confirm": True,
        },
        separators=(",", ":"),
    ).encode("utf-8")
    result = request_json(
        config.api_url + "/auth/v1/admin/users",
        method="POST",
        headers={
            "apikey": config.service_role_key,
            "Authorization": "Bearer " + config.service_role_key,
        },
        body=body,
        timeout=15,
    )
    if not isinstance(result, dict) or result.get("id") != user.id:
        raise JourneyFailure("Local Auth did not create the expected synthetic user.")


def _admin_delete_user(config: LocalSupabase, user_id: str) -> None:
    """Delete one exact run-generated Auth user from the validated local API."""

    owned_user_id = str(_uuid(user_id))
    try:
        request_json(
            config.api_url + "/auth/v1/admin/users/" + owned_user_id,
            method="DELETE",
            headers={
                "apikey": config.service_role_key,
                "Authorization": "Bearer " + config.service_role_key,
            },
            timeout=15,
        )
    except HTTPError as error:
        if error.code != 404:
            raise


def _fixture_users(fixture: JourneyFixture) -> tuple[JourneyUser, ...]:
    return (
        JourneyUser(fixture.registrar_id, fixture.registrar_email, fixture.registrar_password),
        JourneyUser(fixture.supervisor_id, fixture.supervisor_email, fixture.supervisor_password),
        JourneyUser(fixture.direction_id, fixture.direction_email, fixture.direction_password),
        JourneyUser(fixture.out_of_scope_id, fixture.out_of_scope_email, fixture.out_of_scope_password),
    )


def _command_exists(name: str) -> str | None:
    return shutil.which(name)


def _deno_executable() -> str | None:
    """Resolve installed Deno without requiring a persistent PATH change."""

    names = ("deno.exe", "deno") if os.name == "nt" else ("deno",)
    for name in names:
        executable = _command_exists(name)
        if executable is not None:
            return executable
    if os.name == "nt":
        candidate = Path.home() / ".codex" / "tools" / "deno-local" / "bin" / "deno.exe"
        if candidate.is_file():
            return str(candidate)
    return None


def _chromedriver_executable() -> str | None:
    driver = _command_exists("chromedriver")
    if driver:
        return driver
    if os.name != "nt":
        return None
    local_app_data = os.environ.get("LOCALAPPDATA")
    if not local_app_data:
        return None
    candidate = Path(local_app_data) / "Programs" / "ChromeDriver" / "chromedriver.exe"
    return str(candidate) if candidate.is_file() else None


def _version_output(command: list[str], *, env: dict[str, str]) -> str:
    try:
        result = subprocess.run(
            command,
            env=env,
            capture_output=True,
            text=True,
            timeout=15,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        raise PrerequisiteBlocked("A browser test tool is unavailable.") from error
    if result.returncode != 0:
        raise PrerequisiteBlocked("A browser test tool is unavailable.")
    return (result.stdout + " " + result.stderr).strip()


def _windows_file_version(path: str) -> str:
    """Read an executable's version resource without launching the executable."""
    if os.name != "nt":
        raise PrerequisiteBlocked("Browser tool versions could not be verified.")

    import ctypes
    from ctypes import wintypes

    class VsFixedFileInfo(ctypes.Structure):
        _fields_ = [
            ("signature", wintypes.DWORD),
            ("struct_version", wintypes.DWORD),
            ("file_version_ms", wintypes.DWORD),
            ("file_version_ls", wintypes.DWORD),
            ("product_version_ms", wintypes.DWORD),
            ("product_version_ls", wintypes.DWORD),
            ("file_flags_mask", wintypes.DWORD),
            ("file_flags", wintypes.DWORD),
            ("file_os", wintypes.DWORD),
            ("file_type", wintypes.DWORD),
            ("file_subtype", wintypes.DWORD),
            ("file_date_ms", wintypes.DWORD),
            ("file_date_ls", wintypes.DWORD),
        ]

    version_api = ctypes.WinDLL("version", use_last_error=True)
    get_info_size = version_api.GetFileVersionInfoSizeW
    get_info_size.argtypes = [wintypes.LPCWSTR, ctypes.POINTER(wintypes.DWORD)]
    get_info_size.restype = wintypes.DWORD
    get_info = version_api.GetFileVersionInfoW
    get_info.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, ctypes.c_void_p]
    get_info.restype = wintypes.BOOL
    query_value = version_api.VerQueryValueW
    query_value.argtypes = [
        ctypes.c_void_p,
        wintypes.LPCWSTR,
        ctypes.POINTER(ctypes.c_void_p),
        ctypes.POINTER(wintypes.UINT),
    ]
    query_value.restype = wintypes.BOOL

    ignored_handle = wintypes.DWORD()
    size = get_info_size(str(path), ctypes.byref(ignored_handle))
    if not size:
        raise PrerequisiteBlocked("Browser tool versions could not be verified.")
    data = ctypes.create_string_buffer(size)
    if not get_info(str(path), 0, size, data):
        raise PrerequisiteBlocked("Browser tool versions could not be verified.")
    value = ctypes.c_void_p()
    value_size = wintypes.UINT()
    if not query_value(data, "\\", ctypes.byref(value), ctypes.byref(value_size)):
        raise PrerequisiteBlocked("Browser tool versions could not be verified.")
    if value_size.value < ctypes.sizeof(VsFixedFileInfo):
        raise PrerequisiteBlocked("Browser tool versions could not be verified.")
    info = ctypes.cast(value, ctypes.POINTER(VsFixedFileInfo)).contents
    if info.signature != 0xFEEF04BD:
        raise PrerequisiteBlocked("Browser tool versions could not be verified.")
    version = (
        info.file_version_ms >> 16,
        info.file_version_ms & 0xFFFF,
        info.file_version_ls >> 16,
        info.file_version_ls & 0xFFFF,
    )
    return "Google Chrome " + ".".join(str(part) for part in version)


def _chrome_executable() -> str | None:
    for name in ("chrome", "chrome.exe", "google-chrome", "chromium", "chromium-browser"):
        candidate = shutil.which(name)
        if candidate:
            return candidate
    if os.name == "nt":
        candidates = (
            Path(os.environ.get("PROGRAMFILES", "C:/Program Files"))
            / "Google/Chrome/Application/chrome.exe",
            Path(os.environ.get("PROGRAMFILES(X86)", "C:/Program Files (x86)"))
            / "Google/Chrome/Application/chrome.exe",
            Path(os.environ.get("LOCALAPPDATA", ""))
            / "Google/Chrome/Application/chrome.exe",
        )
        return next((str(path) for path in candidates if path.is_file()), None)
    return None


def check_browser_prerequisites() -> tuple[str, str]:
    env = _safe_environment()
    flutter = _command_exists("flutter")
    driver = _chromedriver_executable()
    chrome = _chrome_executable()
    if not flutter or not driver or not chrome:
        raise PrerequisiteBlocked("Flutter, Chrome, or ChromeDriver is unavailable.")
    flutter_version = _version_output(
        [flutter, "--no-version-check", "--suppress-analytics", "--version", "--machine"],
        env=env,
    )
    driver_version = _version_output([driver, "--version"], env=env)
    if os.name == "nt":
        chrome_version = _windows_file_version(chrome)
    else:
        chrome_version = _version_output([chrome, "--version"], env=env)
    driver_major = re.search(r"ChromeDriver\s+(\d+)", driver_version)
    chrome_major = re.search(r"(?:Google Chrome|Chromium)\s+(\d+)", chrome_version)
    if not flutter_version or not driver_major or not chrome_major:
        raise PrerequisiteBlocked("Browser tool versions could not be verified.")
    if driver_major.group(1) != chrome_major.group(1):
        raise PrerequisiteBlocked("Chrome and ChromeDriver versions do not match.")
    return driver, chrome


def _free_loopback_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def _wait_for_chromedriver(port: int, process: subprocess.Popen[bytes]) -> None:
    url = f"http://127.0.0.1:{port}/status"
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise PrerequisiteBlocked("ChromeDriver could not start.")
        try:
            response = request_json(url, timeout=1)
        except Exception:
            time.sleep(0.15)
            continue
        if isinstance(response, dict) and response.get("value", {}).get("ready") is True:
            return
    raise PrerequisiteBlocked("ChromeDriver did not become ready.")


def _start_chromedriver(executable: str, port: int) -> subprocess.Popen[bytes]:
    try:
        process = subprocess.Popen(
            [executable, f"--port={port}", "--allowed-ips=127.0.0.1"],
            cwd=ROOT,
            env=_safe_environment(),
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except OSError as error:
        raise PrerequisiteBlocked("ChromeDriver could not start.") from error
    try:
        _wait_for_chromedriver(port, process)
    except Exception:
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
        raise
    return process


def _drive_command(
    settings_path: Path, driver_port: int, chrome: str
) -> list[str]:
    flutter = _command_exists("flutter")
    if flutter is None:
        raise PrerequisiteBlocked("Flutter is unavailable.")
    return [
        flutter,
        "--no-version-check",
        "--suppress-analytics",
        "drive",
        "--no-pub",
        "--no-web-resources-cdn",
        "--browser-name=chrome",
        "--headless",
        f"--chrome-binary={chrome}",
        "--driver=test_driver/integration_test.dart",
        "--target=integration_test/unified_journey_test.dart",
        "--device-id=web-server",
        "--driver-port",
        str(driver_port),
        "--web-port=7357",
        "--web-hostname=127.0.0.1",
        "--web-launch-url=http://127.0.0.1:7357/",
        "--web-browser-flag=--no-proxy-server",
        f"--dart-define-from-file={settings_path}",
    ]


def _run_browser_journey(
    config: LocalSupabase,
    fixture: JourneyFixture,
    driver: str,
    chrome: str,
    *,
    on_owned_identity: Callable[[str, str], None] | None = None,
    on_public_submission: Callable[[str], None] | None = None,
) -> None:
    driver_port = _free_loopback_port()
    control: RevocationControl | None = None
    intake_test_server: LocalPublicIntakeTestFunction | None = None
    process: subprocess.Popen[bytes] | None = None
    try:
        control = RevocationControl(
            run_id=fixture.run_id,
            assignment_id=fixture.direction_assignment_id,
            user_id=fixture.direction_id,
            congregation_id=fixture.congregation_a_id,
            allowed_origin="http://127.0.0.1:7357",
            revoke=lambda assignment: run_sql(
                revocation_sql(fixture, assignment), config.database_url
            ),
        )
        intake_test_server = LocalPublicIntakeTestFunction(
            config,
            fixture,
            allowed_origin="http://127.0.0.1:7357",
        )
        intake_test_server.start()
        settings = flutter_settings(
            api_url=config.api_url,
            anon_key=config.anon_key,
            service_role_key=config.service_role_key,
            fixture={
                **fixture.browser_values(),
                "JOURNEY_INTAKE_TEST_ENDPOINT": intake_test_server.endpoint,
                "JOURNEY_CONTROL_URL": f"http://{control.address[0]}:{control.address[1]}",
                "JOURNEY_CONTROL_CAPABILITY": control.capability,
            },
        )
        with tempfile.TemporaryDirectory(prefix="ieadpe-unified-journey-") as temp_dir:
            settings_path = Path(temp_dir) / "settings.json"
            settings_path.write_text(
                json.dumps(settings, separators=(",", ":")), encoding="utf-8"
            )
            process = _start_chromedriver(driver, driver_port)
            env = _safe_environment()
            env["CHROME_EXECUTABLE"] = chrome
            result = subprocess.run(
                _drive_command(settings_path, driver_port, chrome),
                cwd=ROOT,
                env=env,
                stdin=subprocess.DEVNULL,
                capture_output=True,
                text=True,
                timeout=900,
                check=False,
            )
        owned_identity = _owned_identity_from_output(
            (result.stdout or "") + "\n" + (result.stderr or "")
        )
        public_submission_id = _public_submission_id_from_output(
            (result.stdout or "") + "\n" + (result.stderr or "")
        )
        if owned_identity is not None and on_owned_identity is not None:
            on_owned_identity(*owned_identity)
        if public_submission_id is not None and on_public_submission is not None:
            on_public_submission(public_submission_id)
        if result.returncode != 0:
            if any(
                marker in (result.stdout + result.stderr).lower()
                for marker in (
                    "chrome binary not found",
                    "unable to start browser",
                    "chromedriver only supports",
                    "failed to launch chrome",
                    "connection refused",
                )
            ):
                raise PrerequisiteBlocked("Local Chromium journey could not start.")
            raise JourneyFailure("The local Chromium journey failed.")
        if owned_identity is None:
            raise JourneyFailure("The browser journey did not report its owned student identity.")
        if "PUBLIC_INTAKE_JOURNEY=PASS" not in (result.stdout or ""):
            raise JourneyFailure("The public intake browser journey did not report completion.")
    except subprocess.TimeoutExpired as error:
        output = error.stdout or ""
        stderr = error.stderr or ""
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        if isinstance(stderr, bytes):
            stderr = stderr.decode("utf-8", errors="replace")
        owned_identity = _owned_identity_from_output(str(output) + "\n" + str(stderr))
        public_submission_id = _public_submission_id_from_output(
            str(output) + "\n" + str(stderr)
        )
        if owned_identity is not None and on_owned_identity is not None:
            on_owned_identity(*owned_identity)
        if public_submission_id is not None and on_public_submission is not None:
            on_public_submission(public_submission_id)
        raise JourneyFailure("The local Chromium journey timed out after launch.") from error
    finally:
        if process is not None and process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=3)
        if control is not None:
            control.close()
        if intake_test_server is not None:
            intake_test_server.close()


def _owned_identity_from_output(output: str) -> tuple[str, str] | None:
    """Read only UUIDs emitted by the integration test for exact cleanup."""

    matches = set(
        re.findall(
            r"T11_CLEANUP_IDS=([0-9a-fA-F-]{36}),([0-9a-fA-F-]{36})",
            output,
        )
    )
    if not matches:
        return None
    if len(matches) != 1:
        raise JourneyFailure("The browser journey reported conflicting cleanup identities.")
    student_id, person_id = next(iter(matches))
    return str(_uuid(student_id)), str(_uuid(person_id))


def _public_submission_id_from_output(output: str) -> str | None:
    """Read only the one UI-generated submission UUID used for exact cleanup."""

    matches = set(
        re.findall(r"PUBLIC_INTAKE_CLEANUP_ID=([0-9a-fA-F-]{36})", output)
    )
    if not matches:
        return None
    if len(matches) != 1:
        raise JourneyFailure("The browser journey reported conflicting intake cleanup IDs.")
    submission_id = next(iter(matches))
    if not re.fullmatch(
        r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}",
        submission_id,
    ):
        raise JourneyFailure("The browser journey reported an invalid intake cleanup ID.")
    return str(_uuid(submission_id))


def _preflight_local_services(config: LocalSupabase) -> None:
    try:
        response = request_json(
            config.api_url + "/auth/v1/health",
            headers={"apikey": config.anon_key},
            timeout=5,
        )
    except Exception as error:
        raise PrerequisiteBlocked("Local Supabase Auth is unavailable.") from error
    if response is None:
        raise PrerequisiteBlocked("Local Supabase Auth is unavailable.")
    try:
        result = run_sql("SELECT 1;", config.database_url)
    except (PrerequisiteBlocked, JourneyFailure) as error:
        raise PrerequisiteBlocked("Local Supabase database is unavailable.") from error
    if result != "1":
        raise PrerequisiteBlocked("Local Supabase database is unavailable.")


def run_journey() -> int:
    """Run one fully isolated journey and always attempt exact fixture cleanup."""

    failures: list[tuple[str, str]] = []
    try:
        config = local_supabase_from_status(read_supabase_status())
    except PrerequisiteBlocked as error:
        _write_failure("prerequisite", error)
        return BLOCKED
    except (UnsafeSupabaseTarget, ValueError) as error:
        _write_failure("target", error)
        return BLOCKED

    try:
        driver, chrome = check_browser_prerequisites()
        _preflight_local_services(config)
    except PrerequisiteBlocked as error:
        _write_failure("prerequisite", error)
        return BLOCKED

    fixture = make_fixture()
    cleanup_fixture = fixture

    def record_owned_identity(student_id: str, person_id: str) -> None:
        nonlocal cleanup_fixture
        cleanup_fixture = replace(
            fixture,
            student_id=str(_uuid(student_id)),
            person_id=str(_uuid(person_id)),
        )

    def record_public_submission(submission_id: str) -> None:
        nonlocal cleanup_fixture
        cleanup_fixture = replace(
            cleanup_fixture,
            public_submission_id=str(_uuid(submission_id)),
        )

    setup_attempted = False
    primary_error: int | None = None
    attempted_users: list[JourneyUser] = []
    try:
        setup_attempted = True
        for user in _fixture_users(fixture):
            attempted_users.append(user)
            _admin_create_user(config, user)
        run_sql(setup_sql(fixture), config.database_url)
        _run_browser_journey(
            config,
            fixture,
            driver,
            chrome,
            on_owned_identity=record_owned_identity,
            on_public_submission=record_public_submission,
        )
        if run_sql(
            public_intake_acceptance_sql(cleanup_fixture),
            config.database_url,
        ) != "PASS":
            raise JourneyFailure("Public intake local SQL acceptance assertions failed.")
    except PrerequisiteBlocked as error:
        primary_error = BLOCKED
        failures.append(("primary", _safe_failure_reason(error)))
    except Exception as error:
        primary_error = FAIL
        failures.append(("primary", type(error).__name__))
    finally:
        if setup_attempted:
            try:
                cleanup_public_intake_photo(config, cleanup_fixture)
            except Exception as error:
                primary_error = FAIL
                failures.append(("photo_cleanup", type(error).__name__))
            try:
                run_sql(cleanup_sql(cleanup_fixture), config.database_url)
            except Exception as error:
                primary_error = FAIL
                failures.append(("cleanup", type(error).__name__))
            for user in reversed(attempted_users):
                try:
                    _admin_delete_user(config, user.id)
                except Exception as error:
                    primary_error = FAIL
                    failures.append(("auth_cleanup", type(error).__name__))
    if failures:
        _write_failure_summary(failures)
    return primary_error if primary_error is not None else PASS


def _write_failure(stage: str, error: Exception) -> None:
    """Print safe prerequisite detail while hiding external exception text."""

    _write_failure_summary([(stage, _safe_failure_reason(error))])


def _safe_failure_reason(error: Exception) -> str:
    """Prerequisite messages are runner-authored constants; other errors are opaque."""

    if isinstance(error, PrerequisiteBlocked):
        return str(error)
    return type(error).__name__


def _write_failure_summary(failures: list[tuple[str, str]]) -> None:
    summary = ",".join(f"{stage}:{kind}" for stage, kind in failures)
    print(f"UNIFIED_JOURNEY_FAILURES={summary}", file=sys.stderr)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args(argv)
    result = run_journey()
    label = {PASS: "PASS", FAIL: "FAIL", BLOCKED: "BLOCKED"}[result]
    print(f"UNIFIED_JOURNEY={label}")
    return result


if __name__ == "__main__":
    sys.exit(main())
