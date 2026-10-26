# T8 amended-acceptance follow-up report — 2026-10-25

## Scope and result

Baseline: `91e4f71` (`test: record T2 intake smoke receipt evidence`) on `feat/public-web-intake`. This offline-only follow-up adds a pinned Deno CI prerequisite, a regression contract, and source-bound acceptance evidence for the amended no-Docker/backup-first hosted plan. Hosted acceptance remains **INCOMPLETE**.

No loopback guards, product behavior, migrations, or hosted runners were changed. No Supabase/Postgres call, Docker/service attempt, hosted browser journey, migration/function deployment, account change, publication, or secret output occurred.

## CI defect and TDD receipt

`.github/workflows/verify-unified.yml` invokes `scripts/verify_unified.sh`, whose gate runs Deno checks, but the workflow had no Deno installation step. Existing local evidence uses Deno 2.9.8. Added `denoland/setup-deno@v2` with `deno-version: v2.9.8` immediately before the unified-gate step.

Added `UnifiedGateContractTests.test_workflow_pins_deno_before_running_unified_gate` in `scripts/test_unified_gate.py`. RED: before the workflow edit, the focused test failed at its intended assertion: `workflow must install Deno with denoland/setup-deno@v2`. GREEN is recorded below.

## Acceptance evidence

The prior local T8 PASS entries in `docs/verification/public-intake-acceptance.md` remain historical, source-bound results from the original offline run. The original local browser command was BLOCKED because local Supabase was unavailable at that time; the amended plan does not require Docker. This follow-up did not attempt Docker or run the journey locally or against a hosted target.

Hosted evidence is separate and remains blocked/incomplete:

- Read-only Supabase migration list records `202610250001` applied and `202610250002`–`004` pending; the functions list is empty. No migration or function was deployed.
- T1's offline hosted-runner verification passed 11/11 at `69fcb29`; T2's offline safety suite passed 15/15 at `91e4f71`. Both use fake subprocesses. They do not establish hosted behavior.
- There is no fresh external full-backup archive/manifest or `PUBLIC_INTAKE_DATABASE_URL` in this environment. The prior read-only linked query is not a write authorization or replacement for backup evidence.
- T2 hosted rate-window/capacity and concurrency cases remain intentionally BLOCKED: the legacy full scenario and concurrency helper reset shared tables/use committed fixtures, and the runner refuses both paths.
- T3's production address resolver remains fail-closed because an authoritative managed gateway address source has not been verified. No function deployment or trusted-address bypass occurred.
- Hosted Turnstile hostname/configuration and temporary synthetic reviewer identities/grants are not available. No hosted anonymous browser journey or user/disability/device completion observations are claimed.

Resumption requires a fresh external full backup with checksum, readability and restore-path manifest; a secure TLS database connection; a coordinated, reviewed migration/function candidate; authoritative address-trust evidence; verified real Turnstile hostname and server configuration; temporary synthetic reviewer identities/grants; and exact cleanup authorization. T2 hosted limits/concurrency additionally require a reviewed non-interfering run-owned fixture design with exact cleanup and reconciliation.

Detailed status and evidence source paths are maintained in `docs/verification/public-intake-acceptance.md` and the SDD ledger `progress.md`. Existing loopback-only guards remain intact.

## Verification

- `python -m unittest scripts.test_unified_gate.UnifiedGateContractTests.test_workflow_pins_deno_before_running_unified_gate -v` — PASS after the workflow change.
- `python -m unittest scripts.test_unified_gate.UnifiedGateContractTests.test_workflow_pins_deno_before_running_unified_gate -v` — PASS, 1/1.
- `python -m py_compile scripts/test_unified_gate.py` — PASS.
- `git diff --check` — PASS.

No broader test suite or service-backed test was run, consistent with the offline-only scope.
