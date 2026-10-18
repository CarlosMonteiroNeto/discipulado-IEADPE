# Unified App Verification — Final Local Run

**Current result: INCOMPLETE for release.** The integrated Chromium journey and fail-closed gate are now implemented. The latest local attempt returned `UNIFIED_JOURNEY=BLOCKED` (exit 2) because the local Supabase API at `127.0.0.1:54321` was unavailable; no hosted Supabase endpoint was used. Device and human accessibility/visual reviews also remain unperformed.

## Latest focused validation — 2026-10-18

- The shared browser journey runner returned `UNIFIED_JOURNEY=BLOCKED` with exact child exit code 2. Its bounded preflight found the local API port 54321 closed; local PostgreSQL port 54329 was listening. It did not proceed to create fixture users/data or run the browser journey.
- The shell contract suite passed in Bash and PowerShell: remote `SUPABASE_URL` values caused zero curl calls; runner exit 1 mapped to `FAIL`; exit 2 mapped to `BLOCKED` and overall `INCOMPLETE`.
- Gate and CI changes were inspected to ensure local URL validation runs before HTTP probes, probe response bodies are discarded, and CI exports only local `API_URL` plus `ANON_KEY` to the gate process.
- Docker's local Supabase services were unavailable. No Supabase HTTP/SQL request was made to the hosted project, and no real data was read or changed.

The 2026-10-17 full local run below is retained as historical evidence; it predates the integrated Chromium runner and current gate contract tests.

## Run identity

- Date: 2026-10-17 (historical run)
- Branch: `implementation/supabase-free`
- Worktree: `App discipulado`
- Environment: Windows 10.0.19045; Flutter 3.47.2; Dart 3.13.2; PostgreSQL 17.11; Chrome 155.0.8059.80
- Gate: `scripts/verify_unified.ps1`
- Generated report and complete command transcript: `build/verification/unified-report.md` and `build/verification/unified-commands.log`

## Executed results

| Area | Result | Evidence |
|---|---|---|
| Static analysis | PASS | `flutter analyze`; no issues. |
| Flutter tests | PASS | 296 tests passed. |
| Web build and static preflight | PASS | `flutter build web`; routes/assets/size fixture passed. |
| Database migrations and security scenarios | PASS | All 15 named SQL scenarios, including ministry directory authorization, applied the checked-in migrations in disposable local PostgreSQL. |
| Synthetic migration rehearsal | PASS | Four tests; repeatable IDs/counts and review handling. No live data was accessed. |
| Independent-session concurrency | PASS | Eight race suites: catalog, access, convert, convert-student, import, lifecycle, ministry registry and academic attendance. |
| Browser adapter smokes | PASS | Chrome locale and export-protocol fixtures; no real file chooser was exercised. |
| Static route/asset fixture | PASS | Five local host rewrite tests. |

After the full gate above, the new root workflow regression was also verified independently: all 8 tests in `test/workflows_test.dart` pass, including a stateful loopback HTTP journey from the production registration form through scoped referral lookup, repository promotion, separate enrollment, session roster, and finalized attendance. `flutter analyze --no-pub` reports no issues. This synthetic widget/HTTP test proves cross-route identity continuity; it does not execute Chromium or replace the browser journey acceptance below.

No command in this run had state `FAIL`. The generated gate result is `INCOMPLETE` (exit 2), not green.

## Release checks still open

- Local Supabase Auth/Storage HTTP health and the integrated Chromium registrar → convert follow-up → student link → enrollment → finalized attendance journey remain unexecuted because the local API service is unavailable. The runner and test now exist, but this report does not claim the journey passed.
- Earlier `flutter drive` experiments with Chrome 155/ChromeDriver 155 did not complete: the Chrome-device attempt returned `SessionNotCreatedException: chrome not reachable`; the web-server attempt served the test app but never completed the WebDriver journey, and the fixture recorded no requests. These experiments did not use the current runner and are retained only as historical diagnostics.
- Firefox/WebKit, actual OS/browser file chooser behavior, Android install/OAuth/resume/signing, hosted deep-link/OAuth checks, and human accessibility/visual review remain incomplete.
- Production backup/restore, operational capacity review, and any real Firebase/Base44 export/import or cutover were not performed.

The application is locally implemented as one Flutter app and one Supabase authorization/data model. Do not interpret this report as deployment, identity provisioning, real-record migration, or production approval.
