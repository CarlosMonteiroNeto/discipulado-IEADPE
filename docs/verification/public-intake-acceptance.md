# Public Intake Acceptance Evidence

Date: 2026-10-26 (R7 evidence close)
Implementation baseline: `origin/main` at `846a320619d3d8240df391a8b218c713bcceedc3`
T8 checkout baseline: T7 reviewed commit `d75ee355a5b197fd09485771608ed7864dac04b9`
Execution checkout: `feat/public-web-intake` in the isolated `public-web-intake` worktree
Current source candidate: `f0c960d87b75662ccbb3581311815290a6a160a2` (R3 hosted-runner safety fixes; no product/UI migrations were deployed).

T9 release handoff and current operator prerequisites: [Public Web intake operations](../operations/public-intake.md). The hosted gates below remain BLOCKED/INCOMPLETE; that runbook is not evidence of deployment or authorization.

## T8 historical candidate checks

The following T8 PASS/INCOMPLETE results describe the earlier T8 source candidate and remain historical receipts. R1 refreshed only the three named local SQL scenarios; R3 changed only the hosted verification runner. The new current-candidate checks are recorded below and do not convert any hosted gate to PASS.

## Acceptance status

| Gate | Status | Evidence |
|---|---|---|
| Full Flutter suite | PASS | `flutter test --no-pub --concurrency=1 --reporter expanded`: 645/645 passed, 17:38. Full output: `.superpowers/sdd/public-web-intake/t8-full-flutter-test.log`. |
| Changed Dart analysis | PASS | Direct SDK `dart analyze` on the six changed Dart sources/tests: `No issues found!` |
| Full Flutter analyzer | INCOMPLETE | `flutter analyze --no-pub` remained alive for over four minutes with no output and a zero-byte log. Process inspection showed about 7 MiB working set and under 0.02 CPU seconds. Only that analyzer command was interrupted; the scoped direct analyzer completed. |
| Dart format and whitespace | PASS | `dart format --output=none --set-exit-if-changed` on six changed Dart files reported 0 files changed; `git diff --check` passed. |
| Web release build and preflight | PASS | `flutter build web --release --no-pub` built `build/web` in 246.5 seconds; `python scripts/web_preflight.py build/web` passed. Flutter's Wasm dry run succeeded. The build emitted the existing CupertinoIcons font-manifest warning. |
| Python runner/gate contracts | PASS | `python -m unittest discover -s scripts -p 'test_unified_*.py' -v`: 48/48 passed in 290.1 seconds. |
| Verification manifest | PASS | `python scripts/verification_cases.py --validate`: 33 SQL scenarios and 10 concurrency cases validated. |
| Public intake SQL and concurrency | PASS | `python scripts/test_database.py public_intake_test.sql --public-intake-concurrency`: scenario passed, followed by capacity, same-network, receipt, review, registration, and revocation race checks. |
| Pending review SQL and concurrency | PASS | `python scripts/test_database.py pending_review_test.sql --public-intake-concurrency`: scenario passed, followed by the same nine shared intake/review race checks. |
| Catalog archive concurrency | PASS | `python scripts/test_database.py catalog_test.sql --catalog-concurrency`: archive/create and archive/grant wait and revalidate in both commit orders. |
| Deno test handler | PASS | `deno check scripts/public_intake_test_server.ts` passed; `deno test supabase/functions/public-intake` passed 18/18. Deno 2.9.8. |
| Original local browser journey | BLOCKED (historical) | The original T8 run of `python scripts/run_unified_journey.py` reported local Supabase unavailable. This was the pre-amendment local path; Docker is not a prerequisite in the amended hosted plan. No journey was run during this offline-only follow-up. |

## R1 current-candidate SQL reconciliation (2026-10-26)

The previous local SQL `INCOMPLETE` assessment described an earlier environment without an available `psql`/server path. For current candidate `bed4cbe2887b38db98d13e109b8cd033707ee3ae`, the three focused database commands below were freshly executed and exited 0 with their reported PASS lines. The runner selected the existing PostgreSQL 17.11 loopback bundle at `~/.codex/tools/ieadpe-postgresql/pgsql/bin`; it constrains targets to loopback and did not start Docker. `psql` is absent from PATH, but this did not prevent the runner from using the bundle. This is local SQL evidence only; hosted SQL remains unverified.

| Local SQL gate | Status | Current-candidate command and outcome |
|---|---|---|
| Public intake scenario and concurrency | PASS (local) | `python scripts/test_database.py public_intake_test.sql --public-intake-concurrency` — exit 0; `PASS: public_intake_test.sql` and `PASS: public intake serializes the last global capacity slot`. |
| Pending review scenario and concurrency | PASS (local) | `python scripts/test_database.py pending_review_test.sql --public-intake-concurrency` — exit 0; `PASS: pending_review_test.sql` and `PASS: public intake serializes the last global capacity slot`. |
| Registration authority scenario | PASS (local) | `python scripts/test_database.py public_registration_authority_test.sql` — exit 0; focused authority scenario passed. |

These results supersede the earlier local SQL `INCOMPLETE` statements only for the named scenarios and current local candidate. They do not amend historical receipts, establish complete manifest coverage, or establish hosted runtime behavior. The earlier `INCOMPLETE` statements remain historical records of their then-current environment.

### R1 hosted configuration presence update (2026-10-26)

The earlier environment-presence observation that `SUPABASE_URL` was absent is historical. A later presence-only check found `SUPABASE_URL` present and its parsed hostname matched the inventoried project. `PUBLIC_INTAKE_DATABASE_URL` and `PUBLIC_INTAKE_TRUSTED_PROJECT_REF` remain absent. This configuration evidence does not establish backup/TLS runner readiness or hosted SQL acceptance; hosted gates remain BLOCKED/INCOMPLETE. No variable values are included here. Exact safe check and result: `.superpowers/sdd/public-web-intake/task-r1-fix-report.md`.

### R2 hosted verification prerequisites (2026-10-26)

Controller-verified evidence establishes the exact target as the unique active Supabase project `Discipulado IEADPE` (`voqmtnqjrbugpazcimvh`); the process `SUPABASE_URL` host parsed to that same project. Migrations `202610250002`–`004` remain pending and the functions list was empty in the R1 read-only inventory. No hosted write was attempted for R2.

A fresh external full custom-format backup was verified against that project by the external manifest validator. The archive is 857,367 bytes with SHA-256 `56bbe069fb9568d07a193f4197d300bb0f85dd8eccc358f234ca04de3bd4f33b`; the external manifest records its exact UTC backup time. The backup directory/files are owner-only. An AES-256-GCM encrypted copy and DPAPI CurrentUser-wrapped key are also external; decrypt-and-hash matched the plaintext archive. `pg_restore --list` exited 0 with 1,011 TOC entries. An isolated PostgreSQL 17.11 recovery rehearsal restored application data, verified 9 application schemas, 37 migration rows, 24 congregations and 51 converts, and dropped its exact local database. This is a successful local restore rehearsal, not a hosted restore. The restore excluded only 10 `vault`/`supabase_vault` TOC entries unavailable in that local target. Database/Storage dump evidence does not include Storage object bytes; no existing Storage object is targeted by the planned rollback-only SQL smoke.

TLS readiness was verified with client-only PostgreSQL 17.11 tools and `PGSSLMODE=require`: authenticated `SELECT 1 AS safe_probe` returned `1`, and `pg_dump` completed. The database URL was held only in process environment; `PUBLIC_INTAKE_DATABASE_URL` remains absent from persistent process environment and no credential value is recorded here. No Docker was started.

The runner evidence path is external at `C:\Users\Carlos_Neto\.codex\backups\public-intake-hosted-20261026\run-5655bd75-b699-47da-b3db-24d3e046e78a-evidence.json`; R3 later wrote a redacted BLOCKED receipt there after target confirmation and a TLS identity probe. No synthetic fixture or hosted scenario was dispatched. The exact external backup manifest and validation receipt remain outside Git. Project and backup details are recorded in `.superpowers/sdd/public-web-intake/task-r2-report.md` without secrets or dump contents.

These checks satisfy the backup, archive/recovery-path, TLS identity-probe, and external evidence-path prerequisites only. They do not authorize or claim hosted SQL acceptance, migration/deployment, function deployment, or browser verification. The general hosted write gate and service-specific prerequisites remain blocked.

Local versions were Flutter 3.47.2 / Dart 3.13.2, Python 3.12.10, and Deno 2.9.8, versus the repository CI pin Flutter 3.47.7 / Dart 3.13.5. No shared SDK or CI pin was changed.

## Amended hosted acceptance status

### R3 hosted runner evidence (2026-10-26)

The current hosted-runner offline suite passed 27/27. Target validation now accepts only the verified direct endpoint or the project-scoped shared Session Pooler shape, rejects libpq query overrides and inherited `PG*` routing values, and keeps the password out of argv/output. Missing migrations are inventoried through the authenticated CLI; psql does not query the protected `supabase_migrations` schema.

The external run receipt records `status=BLOCKED`, `target_confirmed=true`, `baseline_scope=unavailable`, `blocker_code=baseline_unavailable`, `scenario_dispatched=false`, and `hosted_write_attempted=false`. The authenticated CLI login passed the TLS database identity probe but was denied access to a required application schema during baseline collection. Therefore the runner stopped before migration inventory or scenario dispatch. The separate read-only CLI migration inventory at 2026-10-26 04:00 UTC showed 37 remote migrations: `202610250001` applied and `202610250002`–`004` pending; the function list was empty. No fixture, grant, record, object, migration, or function was changed.

The amended plan makes Docker unnecessary for acceptance and requires backup-first hosted checks. None of the following hosted gates has passed; T8 hosted acceptance remains **INCOMPLETE**.

General hosted write readiness is BLOCKED. R2 established the exact project/ref, fresh external full-backup archive and manifest, checksum/readability/recovery-path evidence, and TLS identity-probe readiness. R3 confirmed the exact target and wrote an external receipt, but the CLI-generated PostgreSQL login could not read the application baseline schema; the receipt is BLOCKED with `baseline_scope=unavailable`. No scenario SQL, fixture, hosted write, migration, or deployment occurred. Before resuming a hosted write, provide a protected TLS database URL/role with required baseline and scenario privileges and create a separate external run-owned evidence manifest containing before/after baseline, fixture/identity/receipt IDs, reconciliation result, and exact guarded cleanup plan. Additive migrations/function activation still need the separately authorized coordinated candidate; publication remains separate.

| Hosted gate | Status | Evidence and resumption prerequisites |
|---|---|---|
| Hosted migration/schema readiness | BLOCKED | Read-only migration list shows `202610250001` applied and `202610250002`–`202610250004` pending. No migration was applied. Resume only after a fresh external full backup and manifest are verified, then review and coordinate the exact migration candidate and deployment. |
| Hosted functions readiness | BLOCKED | Read-only functions list is empty. No function was deployed. T3's production address resolver in `supabase/functions/public-intake/handler.ts` still fails closed because no authoritative managed gateway address source is verified. Resume after reviewed function candidate/deployment and authoritative address-trust evidence. |
| Hosted runner / database journey | BLOCKED | Current hosted-runner offline suite passed 27/27. The real runner confirmed target and TLS identity, then wrote an external BLOCKED receipt because its CLI login lacks the baseline schema privileges. No scenario was dispatched. Provide a protected TLS URL/role with required baseline and scenario privileges before resuming; the reviewed scenario/function candidate and service-specific gates must also be ready. |
| Hosted T2 limits and concurrency | BLOCKED / INCOMPLETE | T2 hosted smoke explicitly refuses the legacy shared-table `TRUNCATE` scenario and `--concurrency`; rate-window/capacity limits, cleanup and concurrency are not hosted-verified. Keep those gates incomplete until a reviewed, non-interfering run-owned fixture/race design supports exact cleanup and reconciliation. |
| Hosted bot verification | BLOCKED | Hosted Turnstile hostname and server configuration were not verified or changed. Resume after confirming the real hostname and matching server-side Turnstile configuration. |
| Hosted reviewer access | BLOCKED | No temporary synthetic reviewer identities or grants were created. Resume only with temporary synthetic reviewer identities/grants, a bounded run-owned fixture, and exact cleanup authorization. |
| Hosted anonymous browser journey | BLOCKED | No hosted browser journey ran, and no hosted PASS or user completion observation is claimed. This is blocked by the insufficient database role, pending schema and absent function, T3's fail-closed address trust, unverified hostname/Turnstile configuration, and absent reviewer identities/grants. Resume only after those prerequisites are independently reviewed and available. |

Read-only hosted evidence and constraints are recorded in `.superpowers/sdd/public-web-intake/progress.md`, `.superpowers/sdd/public-web-intake/task-r1-report.md`, `.superpowers/sdd/public-web-intake/task-r2-report.md`, and `.superpowers/sdd/public-web-intake/task-r3-report.md`. Offline PASS results establish runner contracts only, not hosted behavior. No hosted migration, function deployment, Auth user, grant, record, or Turnstile setting was changed.

## Journey and security design

The added browser journey uses the existing unified runner and the actual Flutter app, repositories, and pending/review contracts. It covers anonymous submission to an active congregation, generic acceptance and same-ID retry after a lost response, exclusion of pending data from official reads/reports, wrong-scope denial, scoped supervisor correction and approval, one canonical official result, payload erasure, rejection of anonymous official RPC/photo-upload bypasses, and sign-out cleanup. The original local journey could not execute because local Supabase was unavailable; this historical result is not amended hosted-journey evidence, and those behaviors are not represented as browser PASS evidence.

`scripts/public_intake_test_server.ts` is a host-side local test adapter. Its bot token and address are deterministic and keyed to the generated journey run. It binds only to loopback, accepts only the configured public-intake path, and talks only to the configured local Supabase API. The runner's endpoint rewrite requires an exact loopback endpoint and exact function path. The service-role credential remains in the Deno host process environment and is never written into Flutter settings or the browser bundle. The adapter is outside `supabase/functions` and is not referenced by deployment configuration. T3's production resolver and trust boundary were not modified.

Runner cleanup uses generated run IDs and the browser-reported submission UUID. It removes only the run-owned pending submission, decision, receipt/event, canonical convert/person dependencies, and exact run-owned unsigned photo object if an unauthorized upload unexpectedly succeeds. The runner remains guarded against remote Supabase URLs and hosted database targets; its Python tests cover cleanup after partial setup and browser failure.

## Test partitions and boundaries

- The public HTTP/Deno checks cover valid acceptance and invalid bot, origin, schema, unknown-key/photo, size, provider/database timeout, and unsafe error/log cases. The handler suite passed 18 tests. Request-size validation retains the 16 KiB boundary and rejects before draft decode.
- SQL scenarios cover active/archived names-only catalog behavior; private queue access; idempotent and conflicting submission retries; exact hourly, daily, and global-pending settings; decision retention; payload erasure; scope checks; and official-record absence/presence across review.
- Concurrency cases exercise the last global slot, 20 same-network acceptances versus the 21st, same-key retry, identical and conflicting review decisions, reject/approve races, normal registration versus approval, and grant revocation versus review. The direct T8 commands passed every reported race.
- Photo usability checks cover 360, 768, and 1440 pixel viewports at 200% text, high-contrast rendering, keyboard alternatives, reduced-motion transitions, cancellation and authority loss. A selected crop combined with EXIF orientation 6 remains 512×512 and keeps the selected region. No native camera hardware was available for a device smoke check.
- The complete unit/widget suite passed 645 tests. The first full run completed with 638 passes and seven failures. Investigation found three distinct test-harness issues: the catalog concurrency fixture lacked scoped authority for its synthetic registrar; the shell gate harness lacked an isolated Deno executable; and four older protected-photo workflow fixtures tried opening the picker before selecting a congregation (the current UI correctly hides it until a scope is selected). The workflow scope-change fixture now transitions from global admin to a scoped registrar for the same synthetic congregation. All repairs are test-only and the full rerun passed.
- The public-intake SQL scenario exposed two older cleanup-seed decision rows missing T5's required `corrected_draft_digest`. They now use the documented SHA-256 digest of the JSON null sentinel for rejection. The SQL scenario and concurrency rerun passed.

## Observations and remaining evidence

No public visitor or reviewer browser completion observation was collected: no hosted journey ran, and the prior local journey result is historical only. No impression, completion time, or error observation is claimed. No disability-user study or native camera/device smoke was performed. Flutter 3.47.2 exposes a high-contrast accessibility flag but no reduced-transparency signal; the crop guide responds to high contrast with opaque shading and a thicker, high-contrast selection ring. Platform-specific reduced-transparency behavior still needs device review.

The production intake remains release-blocked until the complete hosted prerequisites above are satisfied. Docker is not required by the amended plan. No hosted migration, hosted fixture, production change, publication, paid service, or account configuration was performed during this follow-up.
