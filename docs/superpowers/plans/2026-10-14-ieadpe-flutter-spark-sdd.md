# IEADPE Flutter + Firebase Spark Implementation Plan

<!-- canonical-document-authority -->
> **Historical planning reference.** The [current spec](../specs/2026-10-20-ministry-corrective-release-design.md), [current plan](2026-10-20-ministry-corrective-release-plan.md) and [JSON mirror](2026-10-20-ministry-corrective-release-plan.json) govern current requirements, status, task order and authorization. The original body preserves its dated design, checklists and execution provenance; reconcile useful obligations through the current task owners before future work.

> Historical: superseded by the accepted [Supabase Free design](../specs/2026-10-14-ieadpe-flutter-supabase-free-design.md) and [implementation plan](../plans/2026-10-14-ieadpe-flutter-supabase-free-sdd.md). Do not execute this baseline.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development task-by-task. The user's fixed-model policy overrides skill escalation recommendations. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Deliver the IEADPE workflows supported by Spark as one Flutter Android/web application.
**Architecture:** Flutter feature modules and injected repositories use Firebase Auth and direct Firestore transactions. Security Rules validate authorization, atomic event/receipt coupling and week counters. Node tooling exists only for local Rules tests. Photos and paid-service dependencies are deferred.
**Tech Stack:** Flutter/Dart, Auth/Firestore, classic Hosting, Riverpod, go_router, intl/timezone, local XLSX/file adapters, Firebase Auth/Firestore emulators and Rules test SDK.
**Spec:** `docs/superpowers/specs/2026-10-14-ieadpe-flutter-spark-design.md`.
**Execution:** `docs/superpowers/plans/ieadpe-firebase-sdd-runbook.md`; standard SDD selected; no execution during planning.

## Global Constraints

- Firebase Spark only: Auth, Firestore Standard and optional classic static Hosting.
- No Cloud Functions, Cloud Storage, App Hosting, Cloud Run, paid extensions, SMS authentication or billing activation.
- Flutter Material 3; Riverpod, go_router and repository boundaries; Google is the primary OAuth provider, with email/password as a secondary option.
- Every SDD role uses `gpt-6.1-sol` with reasoning effort `low`, including final review and fixers.
- Communication, code comments, planning artifacts and reports are English; app UI is pt-BR.
- Preserve ISO date-only strings and use the Sao Paulo business calendar consistently.
- Firestore Security Rules enforce all authorization and mutation invariants; client checks alone are insufficient.
- Record/lifecycle history, receipts and relevant week totals commit atomically and idempotently.
- Development uses Auth/Firestore emulators only; no fallback to production if emulators fail.
- Production setup/deployment, live access grants and real personal-data migration remain separate release actions.

## Review Focus

1. Registration-only users must create/retry without gaining record-read access or forging lifecycle state (Tasks 3–6).
2. Rules must reject unpaired events, reused receipts and fabricated week counts, within the 10/20 document-access limits (Tasks 3, 6–7, 10).
3. Access loading/revocation/sign-out must not reveal stale data from another scope (Tasks 4–5, 9).
4. Sunday 20:00, day/90-day boundaries and unknown legacy start dates must match between Dart and Rules (Tasks 2–3, 7, 10).
5. Reimports, partial/quota failures and malicious XLSX input must preserve IDs and data without paid-service fallback (Tasks 13–15).

## Structure, contracts and check loop

Create Flutter at repository root: `lib/app`, `lib/core`, `lib/features`, `test`, `integration_test`, `android`, `web`. Root Firebase files: `firebase.json`, `firestore.rules`, `firestore.indexes.json`. Put local Node test tooling in `tool/firebase-tests`, not `functions`. Keep the source reference immutable.

Task 2 defines `DateOnly`, `BusinessClock`, `AccessScope`, `ConvertRecord`, `ConvertDraft`, `ConvertEvent`, `Congregation`, `WeeklyReport`, `FeedbackEntry`, mutation/receipt DTOs and repository interfaces. Mutations carry `{operationId, kind, targetId, payloadFingerprint}`; `operationId` and target ID are fixed before the first attempt. Rules bind the actual write, actor and server time to its immutable receipt; a fingerprint alone is not security validation.

`ConvertsRepository.loadAll(scope)` returns a complete authorized snapshot. `create/update/softDelete/recordAction` perform a transaction and return a minimal receipt. `AccessRepository.watchScope` cancels prior reads on change. `WorkbookService` works with typed rows/bytes; `FileTransferService` handles web/Android save/pick without widget-level `dart:io`. UI controllers never call privileged APIs or embed service-account keys.

Run tasks sequentially in numbered order with one active implementation writer and one independent reviewer per task. Each brief contains only its task, relevant spec excerpts, source paths, Global Constraints, interfaces and report path. Read referenced source before editing. For behavioral changes: add the named meaningful tests, establish assertion-level RED, implement, run narrow GREEN plus analyzer, self-review and commit. Do not use compile failures as behavioral RED evidence or invent tests for mechanical docs/scaffolding. Investigate any failed check before fixing or labeling an external limitation.

Commands established by Task 1: `flutter test <path>`, `flutter analyze`; `npm --prefix tool/firebase-tests test`; `firebase emulators:exec --project demo-ieadpe-converts --only auth,firestore "npm --prefix tool/firebase-tests test"`. Expected: exit 0, assertions executed, no skipped/production checks disguised as passes. Reviewers use reported check evidence and a complete task commit-range diff rather than routinely rerunning passing suites. Every role stays on the fixed model/effort.

### Task 1: Bootstrap an emulator-only Spark workspace

**Files:** root Flutter scaffolds; `pubspec.yaml`, `lib/main.dart`, `lib/core/config/app_environment.dart`, `tool/firebase-tests/package.json`, `firebase.json`, `.gitignore`, `README.md`, `docs/dependencies.md`.
**Contract:** explicit environment selection, valid config or pt-BR setup screen; no automatic live fallback.

- [ ] Check repository/branch/instructions and tool versions. The current folder is not Git; baseline existing docs/source and create a feature branch/worktree before product edits. Preserve existing files; no remote/push.
- [ ] Scaffold Flutter web/Android and Auth/Firestore emulator tooling; resolve compatible stable packages and lockfiles. Confirm no Functions/Storage/App Hosting deployment targets or product dependencies.
- [ ] Test missing config, demo project ID and inaccessible emulator handling; run environment tests, analyzer and initial web boot. Record Android SDK/emulator availability and tool compatibility.

### Task 2: Port domain models, calendar and source policy fixtures

**Source:** six entity schemas, `ConvertCard.jsx`, `Home.jsx`, `Converts.jsx`, `WeeklyConversionReport.jsx`, `sortCongregations.jsx`, `worshipTypes.js`.
**Files:** `lib/core/domain/{date_only,business_clock}.dart`; feature `domain/models.dart` / `repository.dart`; `lib/features/converts/domain/follow_up_policy.dart`; `lib/features/weekly_reports/domain/reporting_period.dart`; `test/fixtures/business_rules.json`, `test/domain/business_policy_test.dart`.
**Contract:** exact source field mapping and pure injected-clock rules; no Firebase dependencies in domain models.

- [ ] Test optional fields, age zero, enums, 64 worship labels, 0/1, 6/7, 29/30, 89/90 boundaries, missing start, overdue discipleship attention, Sede ordering and Sunday 19:59/20:00.
- [ ] Implement typed contracts, serializers and deterministic fixture cases for Rules tests. Represent ISO dates with a validated timestamp companion where required for Rules arithmetic.
- [ ] Run domain tests and analyzer; document the trusted UTC−03:00 Rules offset versus IANA Dart timezone relationship.

### Task 3: Prove Spark authorization and atomic mutation feasibility first

**Files:** `firestore.rules`, `firestore.indexes.json`, `tool/firebase-tests/{setup,rules_access.test,rules_atomic.test,rules_calendar.test}.ts`, `tool/seed_emulators.ts`, `docs/spark-rule-contract.md`.
**Contract:** the collection/mutation design in the Spark spec is executable within Rules limits before dependent UI work.

- [ ] Seed synthetic registrar, direction A/B, supervision and admin; refuse non-demo targets. Test signed-out denial, own-directory/profile access, unauthorized broad query, forbidden admin markers and strict per-kind field whitelists.
- [ ] Implement prototype Rules for create+receipt+week, lifecycle+event+receipt, date-string/timestamp coupling, server `request.time`, moves touching two weeks and zero-confirmation version checks. Reject mutation/event/counter writes made separately or with mismatched targets/actors.
- [ ] Prove worst-case valid writes fit 10 lookups per operation/20 per transaction, and malicious batches/replays fail. Record concrete SDK transaction fixtures, Rules call evidence and approved payload shapes. Never weaken authorization to pass; decompose/defer an unenforceable operation with an explicit ruling.

### Task 4: Implement Auth, registered-user directory and access UI plumbing

**Files:** `lib/features/auth/{data/firebase_auth_repository,application/session_controller,presentation/auth_page}.dart`, `lib/features/access/data/firebase_access_repository.dart`, `lib/app/router.dart`, `lib/l10n/app_pt.arb`, `test/auth/session_routing_test.dart`.
**Contract:** Google-first OAuth sign-in, secondary email/password, verification/recovery, directory registration and guarded source routes.

- [ ] Test loading vs missing access, registrar→Register, direction→Home, direction denied Admin, global access, verified directory identity and sign-out/revocation while on a private route.
- [ ] Implement a prominent Google sign-in path and secondary email/password, minimal Auth-matching directory profile and `watchScope`; no custom claims or server lookup. Handle cancellation, same-email provider conflicts and explicit linking without silently merging identities. New recipients sign in/verify before role assignment. Clear scoped data and pending user-specific work on session change.
- [ ] Run auth/widget and Rules regressions. Document provider/domain/SHA live setup as a release check; emulator Auth is not proof of real Google sign-in.

### Task 5: Implement scoped paged Firestore reads

**Files:** feature data readers for converts/catalog/events/weekly reports; `test/data/scoped_reads_test.dart`, `tool/firebase-tests/rules_queries.test.ts`.
**Contract:** complete snapshots, pages of 100, no direction/registrar unscoped reads and cancellable scope epochs.

- [ ] Test 101/1,001 records, multiple assigned congregations, unassigned records, archived congregation references, missing access, quota failures and revocation during pagination.
- [ ] Implement per-congregation query merging/deduplication and necessary indexes. Reuse snapshots across Home/list/report rather than repeating full reads. Only narrow Auth/access listeners are continuous initially.
- [ ] Run Dart and query Rules tests; do not turn permission errors or incomplete pagination into empty-success dashboards. Disable persistent sensitive caches.

### Task 6: Implement idempotent registration, edit and soft delete

**Files:** `lib/features/converts/data/firestore_converts_repository.dart`, `lib/core/data/transaction_runner.dart`, `test/data/convert_transactions_test.dart`, Rules and atomic tests.
**Contract:** fixed document/internal ID and operation receipt; writes satisfy Task 3's exact Rules shapes.

- [ ] Test all registration validation, optional congregation/phone, registrar create-only, forged lifecycle/ownership fields, direction edit scope, receipt-only retry after a lost response, conflicting payload reuse and soft-delete retention.
- [ ] Implement transactions with all reads before writes: own receipt, required authorized state and affected week documents. Create/import/edit/move/delete changes the correct week count/version; retain tombstones to prevent backup resurrection.
- [ ] Run Dart and emulator transaction tests, including concurrent edit/delete, rollback and scope revocation. Registration receipts never expose the convert payload to a registrar.

### Task 7: Implement atomic visit and discipleship actions

**Files:** `lib/features/converts/data/lifecycle_transactions.dart`, `test/converts/lifecycle_test.dart`, `tool/firebase-tests/rules_lifecycle.test.ts`; extend Rules and repositories.
**Contract:** validated convert transition + immutable source event + receipt in one commit.

- [ ] Test visit due/not due, start/stop/restart, 90-day completion, missing start, third-visit deviation, terminal/deleted denial, same-ID retry and two distinct visit operations racing.
- [ ] Implement exact source transition semantics, server timestamps, actor matching, allowed field diffs and Rules `getAfter()` event linkage. Stop creates no invented event. Reused receipts cannot fabricate a new transition.
- [ ] Run domain, client transaction and malicious Rules tests; one accepted visit must produce one increment and one event.

### Task 8: Build registration/edit form without photo upload

**Source:** `Register.jsx`, `ConvertForm.jsx`.
**Files:** `lib/features/converts/{application/convert_form_controller,presentation/convert_form_page}.dart`, `test/converts/convert_form_test.dart`.
**Contract:** source form in pt-BR with Spark's explicit deferred photo capability.

- [ ] Test required fields, optional highlighted congregation/phone, age 0/150, no future date, exact worship choices, double submit and failure preserving draft input.
- [ ] Implement keyboard-safe form, save/cancel/busy states and stable operation IDs; use avatar placeholder and omit the nonfunctional Add photo action.
- [ ] Run phone/desktop widget tests, registrar receipt flow and analyzer; no fake successful uploads or local-only photo presented as shared data.

### Task 9: Build list/cards, detail and lifecycle interactions

**Source:** `Converts.jsx`, `ConvertCard.jsx`, ordering utilities.
**Files:** `lib/features/converts/application/convert_list_controller.dart`, presentation list/card/detail files, `test/converts/convert_list_test.dart`.
**Contract:** authorized source-like cards and actions backed by Tasks 5–7.

- [ ] Test name/status/congregation filters, post-filter counts, Sede ordering, missing contact highlights, terminal exclusion, empty/error/loading and scope changes.
- [ ] Implement source confirmation dialogs and action availability, edit and soft delete. Normalize WhatsApp numbers and disable unusable phone values; use `url_launcher`.
- [ ] Run interaction tests including retry/double taps and unauthorized detail routes; no stale private content after revocation.

### Task 10: Implement weekly reports and race-safe confirmation

**Source:** `WeeklyConversionReport.jsx`, `weeklyReportUtils.js`.
**Files:** `lib/features/weekly_reports/{data/firestore_weekly_repository,presentation/weekly_report_section}.dart`, `tool/firebase-tests/rules_weekly.test.ts`, `test/weekly_reports/weekly_section_test.dart`.
**Contract:** eligible Monday–Sunday zero confirmation and supervisor overview, using the shared week document.

- [ ] Test Sunday threshold/Monday rollover, own-congregation-only confirmation, positive-count rejection and confirmation version validity.
- [ ] Implement a transaction that reads count/version before setting confirmation. A later positive conversion changes version/count, invalidating the confirmation without a background trigger. Rules independently enforce these relationships.
- [ ] Race confirmation with create/move/import/delete and verify that a positive-count week never appears confirmed empty. Run client/Rules tests and worst-case access-limit regression.

### Task 11: Build responsive shell and Home

**Source:** `Layout.jsx`, `Home.jsx`.
**Files:** `lib/app/app_shell.dart`, `lib/core/theme/app_theme.dart`, Home domain/presentation, `test/home/home_shell_test.dart`.
**Contract:** source branding/navigation, authorized counts/recent five and weekly section.

- [ ] Test role-dependent links, no-access Register-only state, complete counts including terminal states, recent seven-day selection and no deleted records.
- [ ] Implement navy/blue theme, 768 breakpoint, 896 content/512 form widths, mobile bottom navigation/menu and desktop links.
- [ ] Run 360/768/1280-width and 200%-text widget checks, keyboard focus and feedback-action placement.

### Task 12: Implement congregation/access administration

**Source:** `Admin.jsx`, `CongregationManager.jsx`, `UserAccessManager.jsx`.
**Files:** Admin shell, congregation/access data repositories and managers; `test/admin/admin_access_test.dart`, `tool/firebase-tests/rules_admin.test.ts`.
**Contract:** five Admin tabs; global-only create/rename/archive, registered-identity direction/supervision grants, no admin self-promotion.

- [ ] Test malformed names, archived congregations, scope changes, directory lookup by verified email, duplicate roles, grant/revoke and denial of direct administrator-marker writes.
- [ ] Implement UID-backed role documents exposed with exact source role labels; missing recipients receive a pt-BR sign-in/verification instruction. Archive preserves old records; physical delete is unavailable.
- [ ] Run manager widgets and malicious Rules tests. Access-management state must not allow a caller to grant an out-of-band admin role.

### Task 13: Implement local reports, event table and file export

**Source:** `ConversionReport.jsx`, `ConvertEventsLog.jsx`.
**Files:** `lib/core/files/{file_transfer_service,workbook_service}.dart`, report/event presentation files, `test/reports/report_export_test.dart`.
**Contract:** local byte-based XLSX generation/saving on Android/web; no remote file storage.

- [ ] Test inclusive ranges, start>end errors, event Apply state, pt-BR sorting and exports matching all visible filtered/sorted rows beyond 1,000 events.
- [ ] Implement worship totals/chart plus accessible text; exact source column labels and safe text cells. Use `file_saver` with a user-accessible Android destination, not an app-private hidden file.
- [ ] Run workbook round-trips, widget checks and platform save/cancel smoke checks. Reuse complete authorized snapshots and show progress/quota errors.

### Task 14: Implement validated XLSX backup preview

**Source:** `BackupManager.jsx`.
**Files:** `lib/features/backup/{domain/backup_row,data/backup_codec,presentation/import_preview}.dart`, `test/backup/backup_codec_test.dart`.
**Contract:** original 14-column/v2 XLSX formats, stable document IDs and typed row validation.

- [ ] Test age zero, optional fields, unknown/ambiguous congregations, dates/booleans/gender/worship values, unknown start, missing/invalid/duplicate IDs, formula cells and invalid/oversized archives.
- [ ] Enforce 10 MiB compressed/50 MiB expanded/10,000-row limits; reject `.xls`. Keep photo references/binaries out of Spark exports; explain this limit in pt-BR help.
- [ ] Run decode/encode/decode tests and preview widgets; no database writes occur during preview.

### Task 15: Implement sequential resumable backup merge

**Files:** backup application controller/manager and transaction adapter; `test/backup/backup_controller_test.dart`, `tool/firebase-tests/rules_import.test.ts`.
**Contract:** global-only per-row import transaction preserving `id_interno` as document ID.

- [ ] Test second import creates zero, concurrent imports of same ID, existing tombstones, lost response, partial failure, quota exhaustion and server-side Rules rejection of malformed/unauthorized initial state.
- [ ] Apply one row per transaction, sequentially, reusing operation IDs and Task 6's week invariants; no large multi-row batch that exceeds Rules limits. Existing IDs are skipped, never overwritten.
- [ ] Persist current-user progress without logging personal row values; retry safely and clear on sign-out. Verify complete export traversal, meaningful counts and no automatic billing/service fallback.

### Task 16: Implement feedback flow and management

**Source:** `FeedbackButton.jsx`, `FeedbackManager.jsx`.
**Files:** feedback repository/dialog/manager, `test/feedback/feedback_flow_test.dart`, `tool/firebase-tests/rules_feedback.test.ts`.
**Contract:** trimmed authenticated feedback, pending/read/resolved and global-only management action within Admin.

- [ ] Test nonempty/5,000-character limit, actor impersonation, forged status, submitter denied global browsing, valid manager transitions and duplicate submit prevention.
- [ ] Implement direct Firestore writes satisfying Rules, pt-BR errors and unsent-message retention. The manager opens from an Admin action; retain five primary tabs.
- [ ] Run UI and Rules tests plus responsive-shell regression.

### Task 17: Measure Spark usage and prepare static Hosting configuration

**Files:** `docs/spark-operations.md`, `docs/firebase-setup.md`, Hosting portion of `firebase.json`, environment examples.
**Contract:** documented Spark-safe setup and measured read/write estimates, not promises of unlimited capacity.

- [ ] Measure representative synthetic register/visit/edit/import and list flows, including Rules lookup reads. Document the official quotas and actual per-flow operation counts; avoid a remote telemetry write for every read.
- [ ] Configure classic static Hosting only, preserve reserved Firebase Auth routes, and document OAuth/SHA/verified-user/admin/settings bootstrap and free-tier exhaustion handling.
- [ ] Verify there are no Functions/Storage/App Hosting targets, hidden paid dependencies or automatic plan upgrades. Deployment itself remains a separate release action.

### Task 18: Final application verification and SDD branch review

**Files:** `integration_test/critical_flows_test.dart`, `docs/verification-report.md`, `docs/release-checklist.md`, updated README.
**Contract:** reviewed local Spark app with honest web/Android build and runtime evidence.

- [ ] Run analyzer, meaningful Flutter suite and complete Auth/Firestore Rules suite. Exercise registrar create/retry, direction visit/start, completion fixture, revocation, weekly race, Admin report/export/reimport and feedback with synthetic data.
- [ ] Build web release and Android debug APK; verify unsigned release build when possible and smoke-run an available Android emulator/device. Record unavailable device/SDK validation as a gap, not a pass.
- [ ] Check all 101 source hashes, UI text language, 360/768/1280 layouts and 200% text. Run one fresh whole-branch review at `gpt-6.1-sol`/`low`; repair important findings and scoped re-review. Record deferred photos/background jobs/pre-registration invites and any Rules-proven scope limits.

## Self-review and deferred scope

Every Spark workflow has an owning task; Security Rules feasibility precedes dependent product UI. Client logic does not substitute for authorization. The paid Firebase plan is historical and must not be executed accidentally. Shared photos, Functions, Storage, App Hosting, SMS, background jobs, managed backups and additional-provider integration are explicitly outside this release. No product code, remote project or billing configuration was created while preparing this plan.
