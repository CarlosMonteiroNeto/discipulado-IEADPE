# Public Intake Acceptance Evidence

Date: 2026-10-25
Implementation baseline: `origin/main` at `846a320619d3d8240df391a8b218c713bcceedc3`
T8 checkout baseline: T7 reviewed commit `d75ee355a5b197fd09485771608ed7864dac04b9`
Execution checkout: `feat/public-web-intake` in the isolated `public-web-intake` worktree

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

Local versions were Flutter 3.47.2 / Dart 3.13.2, Python 3.12.10, and Deno 2.9.8, versus the repository CI pin Flutter 3.47.7 / Dart 3.13.5. No shared SDK or CI pin was changed.

## Amended hosted acceptance status

The amended plan makes Docker unnecessary for acceptance and requires backup-first hosted checks. None of the following hosted gates has passed; T8 hosted acceptance remains **INCOMPLETE**.

General hosted write readiness is BLOCKED. Before any hosted runner write or synthetic hosted fixture, first confirm the exact project/ref and require typed confirmation of that target; verify a fresh external full-backup archive and manifest with checksum, readability and restore-path evidence; use a secure TLS database connection; and prepare a new external, run-owned evidence manifest that records baseline and after-state for reconciliation, every fixture/identity/receipt ID, and the exact run-owned cleanup plan with authorization. The reviewed migration/function candidate and the remaining service-specific prerequisites below must also be ready. No such hosted action is authorized by this follow-up.

| Hosted gate | Status | Evidence and resumption prerequisites |
|---|---|---|
| Hosted migration/schema readiness | BLOCKED | Read-only migration list shows `202610250001` applied and `202610250002`–`202610250004` pending. No migration was applied. Resume only after a fresh external full backup and manifest are verified, then review and coordinate the exact migration candidate and deployment. |
| Hosted functions readiness | BLOCKED | Read-only functions list is empty. No function was deployed. T3's production address resolver in `supabase/functions/public-intake/handler.ts` still fails closed because no authoritative managed gateway address source is verified. Resume after reviewed function candidate/deployment and authoritative address-trust evidence. |
| Hosted runner / database journey | BLOCKED | T1 offline runner suite passed 11/11 at `69fcb29`; T2 offline suite passed 15/15 at `91e4f71`, using fake subprocesses. No fresh full backup archive/manifest or `PUBLIC_INTAKE_DATABASE_URL` is available, so neither runner was executed against the hosted project. Before resumption, confirm the exact project/ref and typed target confirmation; verify the fresh external full backup, checksum, archive readability and restore path; use a secure TLS DB connection; create a new external run-owned evidence manifest recording fixture IDs and baseline/after reconciliation; and have an exact run-owned cleanup plan and authorization. The reviewed scenario/function candidate and all service-specific prerequisites must also be ready. |
| Hosted T2 limits and concurrency | BLOCKED / INCOMPLETE | T2 hosted smoke explicitly refuses the legacy shared-table `TRUNCATE` scenario and `--concurrency`; rate-window/capacity limits, cleanup and concurrency are not hosted-verified. Keep those gates incomplete until a reviewed, non-interfering run-owned fixture/race design supports exact cleanup and reconciliation. |
| Hosted bot verification | BLOCKED | Hosted Turnstile hostname and server configuration were not verified or changed. Resume after confirming the real hostname and matching server-side Turnstile configuration. |
| Hosted reviewer access | BLOCKED | No temporary synthetic reviewer identities or grants were created. Resume only with temporary synthetic reviewer identities/grants, a bounded run-owned fixture, and exact cleanup authorization. |
| Hosted anonymous browser journey | BLOCKED | No hosted browser journey ran, and no hosted PASS or user completion observation is claimed. This is blocked by missing backup/DB readiness, pending schema and absent functions, T3's fail-closed address trust, unverified Turnstile configuration, and absent reviewer identities/grants. Resume only after all those prerequisites are independently reviewed and available. |

Read-only hosted evidence and constraints are recorded in `.superpowers/sdd/public-web-intake/progress.md`, `.superpowers/sdd/public-web-intake/task-1-hosted-runner-report.md`, and `.superpowers/sdd/public-web-intake/task-2-hosted-safety-report.md`. T1/T2's offline PASS results establish runner contracts only, not hosted behavior. No hosted migration, function deployment, Auth user, grant, record, or Turnstile setting was changed.

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
