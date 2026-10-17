# Unified App Verification — Final Local Run

**Result: INCOMPLETE for release; no local gate failures.** The implementation and synthetic local checks passed. Release approval remains blocked by unavailable local Supabase Auth/Storage services and the missing real Chromium browser journey. Device and human accessibility/visual reviews also remain unperformed.

## Run identity

- Date: 2026-10-17
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
| Database migrations and security scenarios | PASS | All 15 named SQL scenarios, including ministry directory authorization, applied all 18 migrations in disposable local PostgreSQL. |
| Synthetic migration rehearsal | PASS | Four tests; repeatable IDs/counts and review handling. No live data was accessed. |
| Independent-session concurrency | PASS | Eight race suites: catalog, access, convert, convert-student, import, lifecycle, ministry registry and academic attendance. |
| Browser adapter smokes | PASS | Chrome locale and export-protocol fixtures; no real file chooser was exercised. |
| Static route/asset fixture | PASS | Five local host rewrite tests. |

After the full gate above, the new root workflow regression was also verified independently: all 8 tests in `test/workflows_test.dart` pass, including a stateful loopback HTTP journey from the production registration form through scoped referral lookup, repository promotion, separate enrollment, session roster, and finalized attendance. `flutter analyze --no-pub` reports no issues. This synthetic widget/HTTP test proves cross-route identity continuity; it does not execute Chromium or replace the browser journey acceptance below.

No command in this run had state `FAIL`. The generated gate result is `INCOMPLETE` (exit 2), not green.

## Release checks still open

- Supabase CLI, Docker and a local Auth/Storage stack were unavailable. Auth and Storage HTTP health are therefore `BLOCKED`; the workflow provisions local Supabase services in CI, but that hosted CI run has not been executed here.
- A runnable integrated Chromium registrar → convert follow-up → student link → enrollment → finalized attendance browser test is absent. A `flutter drive` attempt with Chrome 155/ChromeDriver 155 did not complete: the Chrome-device attempt returned `SessionNotCreatedException: chrome not reachable`; the web-server attempt served the test app but never completed the WebDriver journey, and the fixture recorded no requests. The root workflow widget test uses an in-process synthetic HTTP server and does not prove real browser behavior, hosted service behavior, or the browser-specific authorization path.
- Firefox/WebKit, actual OS/browser file chooser behavior, Android install/OAuth/resume/signing, hosted deep-link/OAuth checks, and human accessibility/visual review remain incomplete.
- Production backup/restore, operational capacity review, and any real Firebase/Base44 export/import or cutover were not performed.

The application is locally implemented as one Flutter app and one Supabase authorization/data model. Do not interpret this report as deployment, identity provisioning, real-record migration, or production approval.
