# Integrated Chromium Journey Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Exercise the unified registrar-to-attendance workflow in real Chromium against a loopback-only Supabase stack and enforce it in local and CI quality gates.

**Architecture:** A Python host runner validates local Supabase CLI status, provisions unique synthetic Auth identities and congregation grants, starts ChromeDriver, and supplies only test/public values to the Flutter integration test. The browser drives production Flutter widgets and real local Supabase Auth/PostgREST; the host runner owns privileged setup, the revocation control, and precise fixture cleanup.

**Tech Stack:** Flutter `integration_test`/`flutter drive`, ChromeDriver, Supabase CLI local stack, Python standard library, PostgreSQL `psql`, PowerShell, Bash, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-16-unified-quality-release-design.md`

## Global Constraints

- Validate Supabase API and database hosts as loopback before HTTP requests or SQL fixture writes; reject remote/user-hosted values before use.
- Use only per-run synthetic users and records. Never use hosted Supabase, production data, or production OAuth.
- Keep local `service_role` credentials on the host runner. Never pass them to Flutter defines, browser storage, logs, or artifacts.
- `public.user_access` is the authoritative congregation assignment for the unified campaign/ministry scope; revocation tests remove that exact assignment.
- Convert linking and class enrollment are separate explicit commands. Assert persisted state through fresh reads after each write.
- Missing browser/service prerequisites map to `BLOCKED`/overall `INCOMPLETE`; failed assertions map to `FAIL`; an unrun journey never passes.
- Keep hosted OAuth/Storage policy, Firefox/WebKit, Android, human accessibility review, backup/restore, and other release operations explicitly open.

## Review Focus

1. A hosted URL saved in the user's environment must be rejected before any outbound request or SQL write.
2. HTTP health/Auth calls must bypass proxy environment settings, reject redirects, and never follow a hosted endpoint; database targets must reject multi-host, `hostaddr`, service-file and connection-option overrides.
3. An out-of-congregation actor must not read referrals or forge writes; assert HTTP denial and unchanged persisted state.
4. Revocation must remove the exact scoped `user_access` grant and reject fresh requests made with the existing session, while clearing protected client state. The local revocation control must bind to loopback, use an unpredictable per-run capability and exact allowed Origin, and only revoke that run's known assignment; tests deny missing credentials, wrong Origin and arbitrary targets.
5. After finalized attendance, a newly loaded progress view must show persisted state and an edit-after-finalize HTTP request must be denied.
6. Fixture setup/cleanup must affect only this run's users, its two unique congregations, and their scoped descendants, including on failure.
7. Chrome/ChromeDriver mismatch or missing services must be reported as blocked rather than a failed assertion or a false pass.

## Task 1: Add the local-only fixture runner and Chromium journey

**Files:** `scripts/local_supabase_guard.py`, `scripts/run_unified_journey.py`, `scripts/test_unified_journey_runner.py`, `integration_test/unified_journey_test.dart`, `test_driver/integration_test.dart`.

- [ ] Write focused runner/guard tests for loopback URL acceptance; remote URL rejection before network/SQL operations; proxy bypass and redirect rejection; PostgreSQL multi-host/override rejection; no privileged-key propagation to Flutter settings; and cleanup restricted to generated run IDs.
- [ ] Run `python -m unittest discover -s scripts -p 'test_unified_journey_runner.py'`; verify the new assertions fail because the guard/runner behavior is absent.
- [ ] Implement the loopback guard and Python runner. Read local API/database/key values from Supabase CLI status, provision unique email-confirmed synthetic Auth users through the local Admin API, and create grants/lookup data through `psql`. Use a unique run marker and cleanup in `finally`; do not print secrets or HTTP response bodies.
- [ ] Add the minimal Flutter web driver and integration test. Sign in as synthetic test users through local email/password Auth, inject the real `AuthRepository`, and drive production widgets through no-grant registrar creation, campaign-supervisor congregation assignment/follow-up, the congregation direction user's scoped referral, explicit student linking, explicit class enrollment, finalized attendance, and fresh persisted reads.
- [ ] Assert an out-of-scope actor cannot read referral data or forge a cross-congregation write, no private convert fields leak to the ministry projection, and revoking the authoritative `user_access` row denies new requests with the existing token and clears protected UI state. Drive revocation only through a loopback listener with a per-run capability, exact Origin validation, and a fixed fixture assignment; test missing capability, wrong Origin, and arbitrary IDs.
- [ ] After attendance finalization, read progress through a newly loaded app route and assert persisted state; issue an attendance edit via the app HTTP API and assert denial plus unchanged stored attendance.
- [ ] Run the focused Python tests and `python scripts/run_unified_journey.py` against the installed Flutter/ChromeDriver versions. The runner must return `BLOCKED` without a local stack or when any target is not loopback.
- [ ] Commit only Task 1 files as `test: exercise unified workflow in local chromium`.

## Task 2: Wire the journey into local/CI gates and update evidence

**Files:** `scripts/verify_unified.ps1`, `scripts/verify_unified.sh`, `scripts/test_unified_gate.py`, `.github/workflows/verify-unified.yml`, `docs/superpowers/plans/2026-10-16-unified-quality-release-plan.json`, `docs/superpowers/plans/2026-10-16-unified-journey-plan.json`, `docs/verification/unified-matrix.md`, `docs/verification/unified-final-report.md`, `docs/operations/unified-release.md`.

- [ ] Add or extend focused tests proving runner exit 2/missing local prerequisites become `BLOCKED`, browser assertion or runner exit 1 becomes `FAIL`, and no verifier sends health requests to non-loopback `SUPABASE_URL` values. Use stub subprocesses so each outcome is deterministic.
- [ ] Run the focused gate/guard tests and confirm the new assertions fail before the gate changes.
- [ ] Invoke the shared runner from PowerShell and Bash. Use the same local-only guard before Auth/Storage health probes; keep command logs/artifacts free of service-role keys, passwords, access tokens, and Auth response bodies.
- [ ] Ensure CI installs compatible Chrome/ChromeDriver, starts local Supabase, and runs the same gate without hosted credentials.
- [ ] Keep the synthetic widget fixture as fast regression evidence and make only the real Chromium + local Supabase test close the integrated browser criterion. Replace the stale fixed migration count with “all checked-in migrations”.
- [ ] Update the final report and release runbook from fresh command output. Keep hosted OAuth/Storage policy, Firefox/WebKit, human accessibility review, Android, backup/restore, and release operations incomplete unless separate evidence exists.
- [ ] Run focused tests, `python scripts/run_unified_journey.py`, `powershell -File scripts/verify_unified.ps1`, and `bash scripts/verify_unified.sh` where available. Inspect the CI workflow change and classify any host-only blocker explicitly.
- [ ] Commit only Task 2 files as `test: gate unified chromium journey`.
