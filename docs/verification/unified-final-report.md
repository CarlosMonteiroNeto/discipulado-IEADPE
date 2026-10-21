# Unified App Verification — Final Local Run

<!-- canonical-document-authority -->
> **Dated candidate record.** The [current spec](../superpowers/specs/2026-10-20-ministry-corrective-release-design.md), [current plan](../superpowers/plans/2026-10-20-ministry-corrective-release-plan.md) and [JSON mirror](../superpowers/plans/2026-10-20-ministry-corrective-release-plan.json) govern current requirements, status, task order and authorization. The body preserves original candidate observations and scoped outcomes; retained next-step/model/workspace/push instructions belong to that historical context and do not redirect future execution.

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

## 2026-10-21 — Corrective Task 11 attempt (BLOCKED)

**Result: BLOCKED. No test, analyzer, formatter, git, database, HTTP, or browser command executed.**

The operator environment rejected every command-execution attempt with `permission.rejected` / `Permission denied: shell`. The harness exposed only session/worktree helpers and an empty browser namespace, and no MCP runner was available. Consequently this attempt could not:

- capture the working-tree status or HEAD digest;
- author and execute the focused RED for `scripts/test_unified_journey_runner.py` or `test/workflows_test.dart`;
- run `python3 -m unittest discover -s scripts -p 'test_unified_journey_runner.py'`;
- run `flutter test --no-pub --concurrency=1 test/workflows_test.dart`, `flutter analyze`, or the formatter;
- start or probe a local Supabase stack, PostgreSQL, Chrome, or ChromeDriver, or run `python3 scripts/run_unified_journey.py`.

No Chromium journey, hosted request, build, or commit occurred. The partial Task 11 changes observed in the working tree remain unverified; the Sol findings on cleanup lineage, executed dependency proof, and partial-failure coverage are not claimed as corrected. The concrete missing prerequisite is command-execution permission for the operator session, not an application or local-service defect. The blocked evidence is recorded in `build/verification/corrective-release/T11/`.

This section does not change the release result: the unified journey remains INCOMPLETE and unapproved.

## 2026-10-21 — Corrective Task 11 attempt, corrected command evidence (BLOCKED)

**Result: BLOCKED. No focused test, analyzer, formatter, database, HTTP, or browser command executed; no PASS is claimed.**

This supersedes the blanket "every command was rejected" wording above with the
exact behaviour observed in the later operator session. Read-only shell probes
did run; test execution did not:

- `python3 --version` — the interpreter resolves at
  `/opt/codex/runtimes/codex-primary-runtime/dependencies/python/bin/python3`,
  but the operator tool-permission layer rejects `python3` before a process
  starts.
- `flutter --version` — exit 127, `flutter: command not found`; no Flutter/Dart
  SDK is installed on PATH or in the inspected filesystem locations.
- `bash .../flutter-app-pipeline/scripts/rtk-run --ws ... --task 11 test test/workflows_test.dart`
  — exit 126 because the sibling `two-model-sdd-pipeline/scripts/cmd` is mode
  0644, so the sanctioned wrapper cannot launch the test.
- Read-only probes succeeded: `which`, `wc`, `diff -q`, `stat`, and
  `/proc/net/tcp`. They show 127.0.0.1:54329 listening (PostgreSQL-shaped) and
  127.0.0.1:54321 closed (no local Supabase API). `supabase`, `psql`, and
  `chromedriver` are absent; Docker and `/usr/bin/chromium` are present but were
  not started.
- The raw transcript is
  `build/verification/corrective-release/T11/execution-command-attempts.log`.

Static scope finding: only `scripts/run_unified_journey.py` and
`scripts/test_unified_journey_runner.py` differ from the T11 base snapshots.
`integration_test/unified_journey_test.dart` and `test/workflows_test.dart` are
byte-identical to base and still carry the obsolete journey/wiring, so
acceptance A–F are not implemented. The runner changes add run-scoped temp-table
cleanup, recursive child-first replacement-session deletion, canonical-person
deletion, a week-guard deletion that prevents an FK failure when production
`create_convert` has inserted `private.congregation_week_guards`, and sanitized
failure summaries. A remaining static gap is that student `person_id` is not
selected into the owned canonical-person set. None of this is executed proof.

No RED exists: a permission denial or missing SDK is not a test failure.
Consequently there is no GREEN, no cleanup FK-order/unrelated-survival proof, no
candidate SHA-256 digest (hash tooling is outside the operator allowlist), and
no evidence that scope-loss clears protected data in the browser. Hosted
Supabase, Google OAuth, Android/APK, builds, git, commits, and subagents were not
used.

The release result is unchanged: the unified journey remains INCOMPLETE and
unapproved. Full detail: `build/verification/corrective-release/T11/coder-report.json`
and `implementation-summary.md`.

## 2026-10-21 — T11 native follow-up after environment became executable (BLOCKED)

**Result: BLOCKED.** Focused Python runner coverage is green (24 tests), but the
real journey is not accepted. The runner now passes its generated student/person
IDs through the local browser-settings allowlist, enumerates canonical people
referenced by selected run-owned students for bounded cleanup, and emits the
runner-authored missing-prerequisite reason without exposing opaque external
exception text. The matching Python regressions observed RED before these
corrections and GREEN afterward.

`python3 scripts/run_unified_journey.py` exited 2 before HTTP/SQL/browser work
because the Supabase CLI is unavailable. `flutter test --no-pub --concurrency=1
test/workflows_test.dart` exited 127 because Flutter is unavailable. Read-only
inventory found no local Supabase containers; 127.0.0.1:54321 was closed,
ChromeDriver/psql/Supabase CLI/Flutter were absent, and Chromium/Python/Docker
were present. No services were started or cleaned up. The unrelated listener on
127.0.0.1:54329 was not contacted.

The browser journey and A–F remain incomplete: `integration_test/unified_journey_test.dart`
is still unchanged from the T11 base snapshot and does not exercise non-convert
identity creation or consume the new generated student/person IDs. Cleanup FK
execution order and unrelated-fixture survival also remain unproven without the
owned stack. The T11 status stays incomplete and unapproved. See
`build/verification/corrective-release/T11/native-followup-evidence-2026-10-21.md`
and the current `coder-report.json` for exact commands, outcomes and hashes.

## 2026-10-21 — T11 native continuation, UI-source and Auth-cleanup follow-up (BLOCKED)

**Result: BLOCKED; implementation remains partial and unapproved.** This continuation adds a production-UI source path for selecting the congregation during convert creation and a separate non-convert student registration plus canonical identity edit. The synthetic `test/workflows_test.dart` journey now asserts the registered student RPC envelope carries the chosen scope, canonical person fields and `new_convert=false`, with no conversion fields. The browser observer reports only generated student/person UUIDs so runner cleanup can target an identity created before later journey failure.

The Python runner additionally records only exact run-generated Auth IDs whose create calls were attempted and deletes those IDs in reverse order after scoped SQL cleanup; an Auth 404 is treated as already absent. A focused partial-user-setup regression showed RED because the successful user was not deleted; it now passes with the full 25-test Python runner suite. Python compilation and `git diff --check` pass.

Verification is incomplete: `flutter test --no-pub --concurrency=1 test/workflows_test.dart` cannot start (exit 127, Flutter missing). `python3 scripts/run_unified_journey.py` exits 2 before HTTP, SQL, Auth or browser calls (Supabase CLI missing). No local disposable Auth/PostgREST/Storage stack, psql, or ChromeDriver is available. The new Dart path has source-only evidence and is not compile- or runtime-verified. C–E and the full D/F assertions remain partial/absent; session creation/replacement, exact receipt replay, post-cancel denial, persisted marks/progress, and full foreign/registrar/scope-loss journey are not accepted. Cleanup Auth deletion and FK/sentinel survival have not been exercised against PostgreSQL/Auth. T11 remains incomplete; no plan gate is marked complete.

No hosted Supabase, build/APK, commit, or full Flutter suite was used. See `build/verification/corrective-release/T11/coder-report.json` and `implementation-summary.md` for exact source scope, commands, results and remaining gates.

## 2026-10-21 — T11 workflow interaction correction (BLOCKED / partial)

The local Flutter toolchain became available, so the workflow test was reproduced. It failed because the test tapped the `Registrar aluno` heading rather than the submit button; the form's actual button is `Cadastrar aluno` below the viewport. The test now locates the `FilledButton`, ensures it is visible, settles layout, and taps it. No production UI behavior was changed for this fix.

The isolated workflow case passed, then all 8 tests in `test/workflows_test.dart` passed. `flutter analyze --no-pub integration_test/unified_journey_test.dart test/workflows_test.dart` reported no issues; `dart format` check, Python runner tests (25/25), Python compileall, report JSON validation and `git diff --check` passed. Toolchain versions were Flutter 3.47.7, ChromeDriver 154.0.8037.57 and Supabase CLI 2.121.0.

The live runner still exits 2 with `Local Supabase stack is not running.` No service was started. Thus no Chromium journey, Auth/SQL cleanup or unrelated-sentinel survival ran. A–B source and workflow coverage improved; C–F and G live acceptance remain incomplete. T11 remains BLOCKED/partial and pending independent Sol review.

## Task 11 native follow-up — 2026-10-21 (source-only, BLOCKED)

The focused T11 checks now pass locally: `test/workflows_test.dart` 8/8, scoped analyzer for the workflow and browser journey has no issues, and the Python bounded-runner suite passes 25/25. The browser journey source extends A–F with UI registration/canonical identity, scope denial, attendance freeze/replay/immutable rejection, cancel/replacement lineage and effective progress, and revocation/stale-route clearing. These expanded assertions are source-only. The guarded journey runner exits 2 before HTTP, SQL, Auth, browser or cleanup because the local Supabase stack is not running; no stack was started. Thus live A–F and PostgreSQL cleanup/sentinel evidence remain blocked and Task 11 remains incomplete. No hosted Supabase, build/APK, commit, or full Flutter suite was used. Detailed evidence: `build/verification/corrective-release/T11/native-followup-evidence-2026-10-21.md`.


## Task 11 final focused rerun after reviewer findings — 2026-10-21 (BLOCKED)

The initial final rerun exposed an integration-source compile error (`AppShell` was referenced without its widget import). The import was added, then `test/workflows_test.dart` passed **9/9**; the scoped analyzer found no issues, the Python runner suite passed **25/25**, Python compilation/format/scoped diff checks passed. The integration journey explicitly confirms the first finalization modal and reopens the finalized original before cancellation to compare persisted marks. Session lineage reads use the database's physical `replaces_session_id` column.

These are focused source/workflow checks, not live journey acceptance. The guarded runner was invoked with the ambient Supabase access token excluded from the child environment and exited 2 before HTTP/SQL/Auth/browser/cleanup because `Local Supabase stack is not running.` Docker VFS image extraction previously failed for lack of space; no stack was started. A–F remain partial/unverified, G lacks live FK-order and unrelated-sentinel proof, and the integration source does not yet force a delayed protected response after scope swap. T11 remains incomplete and pending independent Sol review.


## Task 11 final focused evidence — delayed stale-list result (2026-10-21, BLOCKED)

Added a controlled test against production `StudentsPage`: an old-congregation list response is delayed until after the page receives a new scope. The current-scope row remains visible and the stale row stays absent. This regression passes (the generation guard was already present), without product changes. Workflows now pass 10/10; scoped analyzer reports no issues; Python runner tests pass 25/25; format, Python compilation and scoped diff checks pass.

The acceptance map is intentionally per scenario, not a blanket A–F pass. A–F source paths and this controlled stale-result regression remain partial/unverified because no live local Supabase/Auth/PostgREST/Chromium journey ran. G lacks live PostgreSQL FK-order and unrelated-sentinel proof. Guarded runner exit 2: `Local Supabase stack is not running.` No service was started; Docker VFS pull exhaustion remains the prerequisite.


## 2026-10-21 — T11 authorized-read, draft and timeout follow-up (BLOCKED)

The T11 browser journey no longer reads Ministry base tables directly. It uses the bounded authorized class-session, attendance, class-student, student and enrollment RPCs; convert follow-up is read through the approved convert projection. The UI source now saves attendance as a draft, waits for the production acknowledgement, confirms the persisted open/frozen draft through `get_session_attendance`, then confirms finalization. Its observer skips drafts and captures only a successful `finalize=true` receipt. Canonical phone begins as a known non-null value, is edited to null and checked through the authorized candidate projection; first freeze checks the current canonical name, with a later rename compared against the stored roster snapshot. Follow-up projection assertions compare active enrollment, finalized lesson, canceled lesson and replacement, while manual visit history remains unchanged.

A launched browser timeout now yields FAIL, with control/driver teardown covered by a focused RED/GREEN Python regression. Flutter workflow tests pass 11/11, scoped analyzer is clean, Python runner tests pass 26/26, and formatting, Python compilation and `git diff --check` pass. Live acceptance remains blocked: the guarded runner exits 2 before HTTP/SQL/Auth/browser because the disposable local Supabase stack is not running. Consequently these UI/RPC assertions and cleanup FK-order/unrelated-sentinel checks are not live acceptance; T11 remains incomplete pending stack and independent Sol review.

## 2026-10-21 — T11 reconciled with approved S16/T04-P first-save preview (BLOCKED)

The T11 integration source now treats first attendance read as the S16 SQL-backed preview. On the production UI-created replacement target, it waits for `Lista prevista` and the first-save notice, then uses the authenticated `ieadpe_ministry_get_session_attendance` RPC to require `status='open'`, `roster_frozen=false`, the exact UI-created enrollment/student, current pre-freeze canonical name and `unmarked` status before saving. The existing runner seeds only a run-owned empty placeholder session for the production cancel/replace flow; it does not seed `ministry_session_roster` or `ministry_attendance`, now guarded by a Python regression. After draft acknowledgement, the journey still rereads the frozen persisted roster before confirming finalization.

Focused verification in this continuation: `test/workflows_test.dart` 11/11, scoped analyzer clean, Python runner tests 26/26, Python compilation, Dart format check and scoped `git diff --check` all pass. Raw outputs and candidate hashes are recorded under `build/verification/corrective-release/T11/`.

This is source-level expectation, not live preview evidence. T04-P SQL execution/first-save proof remains a prerequisite; the local Supabase stack was previously BLOCKED before HTTP/SQL/Auth/browser and was not accessed in this continuation. A–G remain partial/unverified until the T04 disposable-database gate passes, an owned loopback Auth/PostgREST/Storage stack is available, and the actual Chromium journey plus FK-safe cleanup/unrelated-sentinel proof runs. No hosted service, secret, database, build/APK, commit or full Flutter suite was used. T11 remains BLOCKED and pending independent Sol review.


## 2026-10-21 — T11 second replacement preview reconciliation (BLOCKED)

The second replacement path was aligned to the T04-P first-save preview contract. Before saving, it waits for `Lista prevista` and checks via the authorized attendance RPC that the session is open/unfrozen and exposes the current eligible student/enrollment under the latest canonical name with `unmarked` status. It no longer expects an empty frozen roster. No roster or attendance data is privileged-seeded. Focused checks passed: workflows 11/11, scoped analyzer clean, Python runner 26/26, Python compile, Dart format and scoped diff checks. This source was not exercised against SQL or a live stack; T04-P SQL verification and the owned loopback stack remain required. A–G remain partial/unverified.
