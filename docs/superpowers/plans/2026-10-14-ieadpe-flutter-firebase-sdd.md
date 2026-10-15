# IEADPE Flutter + Firebase Implementation Plan

> Historical plan requiring paid Firebase services. Superseded by [the 18-task Spark-only SDD plan](2026-10-14-ieadpe-flutter-spark-sdd.md). The current release excludes Functions and Storage.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. The user's explicit model policy overrides skill recommendations to escalate models or effort.

**Goal:** Recreate the captured IEADPE app as one Flutter web/Android application backed by Firebase.

**Architecture:** Feature-based Flutter with plain Dart policies, Riverpod state and go_router navigation. Firestore provides scoped reads; callable TypeScript Functions enforce commands and atomic history; private Storage holds photos. Emulator-first development, explicit typed contracts, synthetic fixtures, and independent per-task review.

**Tech Stack:** Flutter/Dart, FlutterFire, Firebase Auth/Firestore/Functions/Storage/App Check, TypeScript, Firebase Emulator Suite, Riverpod, go_router, intl/timezone, XLSX and platform file/image adapters.

**Spec:** `docs/superpowers/specs/2026-10-14-ieadpe-flutter-firebase-design.md` (authoritative).

**Execution:** `docs/superpowers/plans/ieadpe-firebase-sdd-runbook.md`. Method already selected: standard Codex SDD, every role `gpt-6.1-sol` / `low`. This is a planning deliverable; do not start product implementation until asked to execute it.

## Global Constraints

- Targets: Flutter web and Android; responsive Material 3 UI.
- Backend: Firebase Auth, Cloud Firestore, Cloud Storage, and callable Cloud Functions.
- All SDD roles: `gpt-6.1-sol`, reasoning effort `low`; no automatic model or effort escalation.
- All communication and artifacts are English; all application UI text is pt-BR.
- Preserve `reference/base44` unchanged and use synthetic fixtures only.
- Enforce access in backend checks and Firebase Rules; client navigation is not authorization.
- Preserve date-only values as `YYYY-MM-DD`; use `America/Sao_Paulo` for business calendar calculations.
- Atomic, idempotent commands must update lifecycle state and event history together.
- Missing congregation and phone remain optional and visibly highlighted.
- Real data migration, production deployment, billing activation, and signing credentials are separate release actions.

## Review Focus

1. Access loading/revocation/sign-out during a paged read must not reveal another congregation or reuse the prior identity's data. Tests: Tasks 5–7.
2. Civil-date boundaries, Sunday 19:59/20:00, and unknown discipleship start dates must behave consistently across clients and Functions. Tests: Tasks 3, 9, 13.
3. Duplicate/concurrent commands and a conversion racing a zero-conversion confirmation must produce one consistent record/history/report state. Tests: Tasks 8–9, 13, 19.
4. A repeated or partly failed backup must preserve stable IDs, age zero, and visit dates; oversized/formula-bearing files must fail before writes. Tests: Tasks 18–19.
5. Registration-only users, attached photo revocation, missing configuration and unavailable emulators must fail safely without a production fallback. Tests: Tasks 1, 6, 10–11.

## Ownership and shared interfaces

`reference/base44` is read-only evidence. Flutter lives at repository root (`lib/`, `test/`, `integration_test/`, `android/`, `web/`). Backend lives in `functions/`; Rules/indexes/emulator config are root Firebase files. Runtime reports/briefs belong to this plan's SDD workspace. Node/Python are tooling only, never UI implementation.

Task 2 owns domain and repository interfaces; downstream tasks implement these contracts. Do not redefine models in UI files. Task 5 owns effective access semantics and the shared command transaction wrapper; Task 3 owns calendar/status semantics; Task 8 owns week-counter and convert-reference updates; Task 17 owns the spreadsheet/file adapter. Contract changes require a recorded coordinator ruling and review of affected consumers.

Shared names:

- `DateOnly`: validated ISO civil date, comparable, no implicit UTC conversion.
- `BusinessClock.now()` and `today()`: injected time in the business timezone.
- `AccessScope`: loading/registrar/direction/supervision/admin plus UID, version and congregation IDs.
- `ConvertRecord`, `ConvertDraft`, `ConvertEvent`, `Congregation`, `AccessGrant`, `WeeklyReport`, `FeedbackEntry`.
- `CommandEnvelope<T> {operationId, payload}`; `CommandResult<T> {operationId, result}`; `CommandFailure {code, fieldErrors?}`.
- `ConvertsRepository.loadAll(AccessScope) -> Future<List<ConvertRecord>>`; `saveDraft`, `updateDraft`, `softDelete`, `recordAction` return command receipts. All read snapshots are complete or explicitly loading/failed.
- `ConvertsRepository.recordAction(id, action, operationId)` uses the five action names in spec §6. Receipt retries reuse their operation ID; a distinct user intent gets a new ID.
- `CatalogRepository.loadCongregations()`, `EventsRepository.loadRange(start?, end?, congregationId?)`, `AccessRepository.watchOwnScope()`.
- `PhotoRepository.prepare(bytes)`, `createDraft(operationId)`, `upload(draft, bytes)`, `loadAuthorizedBytes(photoId)`; UI never stores a public photo URL.
- `WorkbookService` accepts/returns bytes and typed rows; `FileTransferService` picks XLSX and saves bytes on web/Android. No browser screen imports `dart:io`.

## Task dependency order

Execute sequentially: 1→2→3→4→5→6→7→8→9→10→11→12→13→14→15→16→17→18→19→20→21. Do not run concurrent implementation agents in the shared checkout. A later feature may remain unwired until its owning task; do not substitute fake production functionality to satisfy intermediate tests.

## Per-task cycle and checks

Before each implementation, read the task's referenced source and relevant spec sections. Create a small brief carrying this task, binding constraints, exact files and current interfaces. For behavioral changes, add the named meaningful tests, run them and confirm an assertion-level RED after the suite loads, implement, run narrow GREEN and analyzer/typecheck, self-review, commit, and report. Compile/import errors are not proof of missing behavior. Mechanical scaffold/docs need build checks, not artificial tests.

Test commands below are relative to repository root. `D(path)` means `flutter test path`; `B(path)` means `npm --prefix functions run test -- path`; `E` means `firebase emulators:exec --project demo-ieadpe-converts --only auth,firestore,functions,storage "npm --prefix functions run test:emulator"`. Task 1 defines npm scripts; Task 4 creates emulator harness. Reuse an active emulator session for narrow checks when possible. Run relevant backend build (`npm --prefix functions run build`) or Flutter analyzer (`flutter analyze`) before task review. Expected result is exit 0 with all named assertions executed, not skipped.

All tasks close with an implementation report, commit range and one independent spec/correctness review. Reviewers consume existing check evidence and the complete task diff; they do not automatically rerun a passing suite. Use the same model/effort for fixes and final review. Track progress durably as described in the runbook.

---

### Task 1: Establish the Flutter/Firebase workspace

**Files:** create root Flutter platform scaffolds, `pubspec.yaml`, `lib/main.dart`, `lib/app/app.dart`, `lib/core/config/app_environment.dart`, `functions/package.json`, `functions/tsconfig.json`, `functions/src/index.ts`, `README.md`, `.gitignore`, `docs/dependencies.md`.
**Consumes/produces:** empty workspace + immutable source → emulator-selectable app entry point and locked toolchain; Firebase initialization occurs only when configuration is valid.

- [ ] Check Flutter/Android/Node/Java/Firebase compatibility; record versions and supported Node runtime. Initialize local Git if absent, preserve all existing files, baseline source/docs, and use a feature branch/worktree before product edits. Do not add a remote or push.
- [ ] Scaffold Flutter web/Android and Functions; select compatible stable dependency versions from official package docs, record platform/license decisions, commit lockfiles. Define backend `build`, `test`, `test:emulator` scripts. Production deployment remains manual.
- [ ] Add meaningful environment tests at `test/core/config/app_environment_test.dart`: missing config renders a pt-BR setup state; explicit demo mode selects emulators; a dead emulator never selects production. Use configurable host (`localhost` for web, emulator-reachable host for Android), region and ports.
- [ ] Run `D(test/core/config)` and `flutter analyze`; smoke-run web boot and `npm --prefix functions run build`. Report missing SDK/tool prerequisites with their root cause.

### Task 2: Define models and repository/command contracts

**Source:** six `reference/base44/base44/entities/*.jsonc`; spec §§5–8.
**Files:** create `lib/core/domain/date_only.dart`, `lib/core/contracts/command.dart`, domain `models.dart` and `repository.dart` under each feature (`auth`, `converts`, `congregations`, `access`, `events`, `weekly_reports`, `feedback`); `functions/src/contracts.ts`, `test/domain/model_contract_test.dart`, `functions/test/contracts.test.ts`.
**Consumes/produces:** spec field map → typed interfaces listed above and canonical JSON fixtures. Contract declarations have no Firebase dependency in Dart domain code.

- [ ] Test absent optionals, false/zero defaults, age zero, strict dates, gender/event enums, every source Convert field and compatible round-trips. Reject malformed payloads instead of coercing truthy strings.
- [ ] Define nullable congregation/photo/start date and explicit server-owned fields. Do not translate XLSX columns into Firebase field names outside the adapter.
- [ ] Implement serializers and command error codes; use a shared fixture in `test/fixtures/contracts.json` for Dart and TypeScript consumers.
- [ ] Run `D(test/domain/model_contract_test.dart)`, `B(test/contracts.test.ts)`, analyzer/typecheck.

### Task 3: Port business date, status and ordering policies

**Source:** `pages/Home.jsx`, `pages/Converts.jsx`, `ConvertCard.jsx`, `WeeklyConversionReport.jsx`, `sortCongregations.jsx`, `worshipTypes.js` under the captured `src` tree.
**Files:** create `lib/core/domain/business_clock.dart`, `lib/features/converts/domain/follow_up_policy.dart`, `lib/features/weekly_reports/domain/reporting_period.dart`, `lib/features/congregations/domain/congregation_order.dart`, `lib/features/converts/domain/worship_types.dart`, `functions/src/domain/business_policy.ts`, `test/fixtures/business_rules.json`, corresponding Dart/backend policy tests.
**Consumes/produces:** DateOnly/models → `classify(record, today)`, `canComplete`, `canMarkDeviated`, `reportingPeriod(now)`, exact worship catalog and pt-BR comparator.

- [ ] Test 0/1, 6/7, 29/30 and 89/90-day boundaries; overdue discipleship is attention; missing start cannot complete; three visits unlock deviation. Test Sunday 19:59/20:00, Monday and year boundaries using fixed Sao Paulo instants.
- [ ] Test `sede` ordering, accent/case comparisons, unassigned records last, and all 64 source worship labels. Select/document a comparator that passes the shared fixture in both runtimes.
- [ ] Implement pure policies in Dart and TypeScript, consuming the same golden cases and injected clock. No Firebase calls or hard-coded system clock in domain tests.
- [ ] Run `D(test/domain)` and `B(test/domain)`; require fixture parity and zero analyzer/typecheck errors.

### Task 4: Establish emulators and deny-by-default Rules

**Files:** create `firebase.json`, `firestore.rules`, `storage.rules`, `firestore.indexes.json`, `functions/test/emulator/setup.ts`, `functions/test/emulator/baseline_rules.test.ts`, `tool/seed_emulators.ts`, `docs/firebase-setup.md`.
**Consumes/produces:** configured toolchain → isolated synthetic Auth/Firestore/Storage fixtures and repeatable emulator suite.

- [ ] Seed distinct registrar, direction-A, direction-B, supervision and admin identities plus fake congregations. Seeder must refuse a non-demo project or missing emulator host.
- [ ] Test signed-out denials, all direct business writes denied, server-only operations/index/admin documents unreadable, and no client privilege escalation.
- [ ] Configure known emulator ports/hosts and internal collection indexes; restrict fixture helpers to emulators. Keep production aliases/configuration examples distinct from active local settings.
- [ ] Run `E`; verify real assertions hit both allowed/denied cases without production network access. Later tasks extend this suite rather than replacing baseline denials.

### Task 5: Implement effective access and grant commands

**Files:** create `functions/src/core/command.ts`, `functions/src/access/access_service.ts`, `functions/src/access/access_commands.ts`, `functions/src/access/bootstrap_admin.ts`, `functions/test/emulator/access.test.ts`; modify `functions/src/index.ts`, Rules and indexes.
**Consumes/produces:** contracts + emulator fixtures → shared `executeCommand` transaction envelope, `resolveMyAccess`, `saveAccessGrant`, `revokeAccessGrant` and server-maintained profiles.

Shared signature: `executeCommand<P, R>(request: CallableRequest<CommandEnvelope<P>>, commandName: string, handler: (context: CommandContext, payload: P, tx: Transaction) => Promise<R>): Promise<CommandResult<R>>`. `CommandContext` contains verified UID/email, transactional effective scope, injected server time/business date and operation ID. Handler authorization and all reads occur before transaction writes; the wrapper records the receipt atomically.

- [ ] Test registrar fallback; pre-existing grant binding only after verified matching identity; own profile read; direction A denied B; supervision global; revoked bound profile changes immediately. Test normalized duplicate grants and supervisor-with-congregation rejection.
- [ ] Implement the shared operation-ID/payload-hash transaction wrapper, deterministic grant IDs, bound UID profiles, server-only admin principals and idempotent grant mutation. Updating/revoking/moving a congregation grant changes its server-only congregation `grantRefCount` in the same transaction. Supervision can manage source-supported grants but cannot create an admin principal.
- [ ] Authorize every Admin SDK command; mirror read scope in Rules. A request cannot promote itself by modifying request JSON or direct profile writes. Bootstrap accepts explicit project/UID and is never run against a real project during this task.
- [ ] Run focused access emulator tests and backend build; retain Rules regression results.

### Task 6: Implement Firebase Auth and guarded routes

**Files:** create `lib/features/auth/data/firebase_auth_repository.dart`, `lib/features/access/data/firebase_access_repository.dart`, `lib/features/auth/application/session_controller.dart`, `lib/features/auth/presentation/auth_page.dart`, `lib/app/router.dart`, `lib/l10n/app_pt.arb`, `test/auth/session_routing_test.dart`; modify app bootstrap.
**Consumes/produces:** auth/access contracts + Task 5 callables → `watchOwnScope`, login/signup/Google/verification/recovery/sign-out and guarded routes.

- [ ] Test auth-loading vs access-loading, registrar landing on Register, allowed Home/Admin routes, direction Admin denial, denied profile reads and revocation while a private route is open.
- [ ] Implement providers with emulator Auth support and pt-BR errors. No private UI flashes before effective access resolves. Clear scoped state and photo bytes on sign-out/profile change; missing configuration remains a setup state.
- [ ] Keep Google redirect/popup logic platform-aware and document Android SHA/OAuth setup; do not replace Firebase's hosted OAuth handler with Base44 consent logic.
- [ ] Run `D(test/auth)` and widget checks using fake repositories; separately record provider-dependent real-device validation as a release check.

### Task 7: Implement scoped Firestore read repositories

**Files:** create `lib/features/converts/data/firestore_converts_reader.dart`, `lib/features/congregations/data/firestore_catalog_repository.dart`, `lib/features/events/data/firestore_events_repository.dart`, `test/data/scoped_reads_test.dart`, `functions/test/emulator/scoped_queries.test.ts`; modify Rules/indexes.
**Consumes/produces:** AccessScope → complete authorized snapshots, pagination and cancellation; command methods remain delegated to later command clients.

- [ ] Test 101 and 1,001-row fixtures, multiple assigned congregations, unassigned records, empty scopes, and changing scope during pagination. No unscoped query for direction/registrar; global users alone can read unassigned converts.
- [ ] Implement page-size-100 traversal, per-congregation query merging/deduplication, deterministic tie-breakers, index definitions and epoch cancellation on access changes. Disable persistent sensitive client caching initially.
- [ ] Prove broad forbidden queries fail in Rules; do not catch permission errors and silently display an empty-success snapshot. Exports/dashboard consumers must know when traversal is incomplete.
- [ ] Run `D(test/data/scoped_reads_test.dart)` and scoped query emulator tests; analyzer/backend build.

### Task 8: Implement validated convert CRUD and command infrastructure

**Files:** create `functions/src/converts/convert_commands.ts`, `functions/src/weekly_reports/week_counter.ts`, `lib/features/converts/data/firebase_converts_repository.dart`, `functions/test/emulator/convert_crud.test.ts`.
**Consumes/produces:** models/access and Task 5's `executeCommand` → `createConvert`, `updateConvert`, `softDeleteConvert` and shared week-counter updates.

- [ ] Test server validation, optional phone/congregation, valid age zero, unknown congregation, future/invalid dates, caller-forged ownership/state, registrar-create-only access and direction edit/delete scope.
- [ ] In transactions read profile, operation and affected data before writes; reuse Task 5's deduplication wrapper. Creation reserves internal ID, establishes defaults and increments week count; moves adjust both weeks; soft delete decrements week count and retains history. Create/move updates congregation `recordRefCount`; soft deletion retains that reference, so a congregation cannot be removed underneath archived records.
- [ ] Resolve target-week no-conversion report in the same transaction. Reject changing server/lifecycle fields through ordinary edit payloads. Receipts do not expose private record payloads to registration-only callers.
- [ ] Run CRUD emulator tests, including same operation after a lost response, conflicting payload reuse, concurrent update/delete and counter rollback; run backend build and Dart repository tests.

### Task 9: Implement atomic lifecycle commands

**Files:** create `functions/src/converts/lifecycle_commands.ts`, `functions/test/emulator/lifecycle.test.ts`, `test/data/lifecycle_client_test.dart`; modify command exports and Firebase convert repository.
**Consumes/produces:** Tasks 3/5/8 → `recordConvertAction` for visit/start/stop/complete/deviated, with immutable events.

- [ ] Test due/not-due visit, start/stop/restart, 90-day completion, missing start, third-visit deviation and terminal/deleted denial. Actor and event time come from server context.
- [ ] Implement one transaction for profile check, state transition, unique operation/event and receipt; stop-discipleship emits no invented event. Concurrent duplicate actions cannot increment twice or create unmatched history.
- [ ] Test retry with same ID, two IDs racing the same due visit, revoked scope, and forced transaction retry. UI retries keep operation IDs stable and map error codes to pt-BR.
- [ ] Run lifecycle emulator/client tests and backend build/analyzer.

### Task 10: Implement private photo drafts and platform-safe image handling

**Files:** create `functions/src/photos/photo_commands.ts`, `lib/features/converts/data/firebase_photo_repository.dart`, `lib/features/converts/presentation/photo_picker.dart`, `functions/test/emulator/photo_rules.test.ts`, `test/photos/photo_processing_test.dart`; modify Storage/Firestore Rules.
**Consumes/produces:** PhotoRepository contract → `createPhotoDraft`, 192×192 center-cropped JPEG bytes, private attachment and authorized reads.

- [ ] Test corrupt/oversized input, landscape/portrait crop, alpha images, upload cancellation, expired draft, foreign draft, registrar own pending draft, attached-photo foreign-scope denial and revoked access.
- [ ] Implement local image preparation, server-owned asset metadata, create-only JPEG uploads <=5 MiB, and linking in validated create/update commands. Verify object metadata before attachment; private reads use authenticated bytes, not public URL tokens.
- [ ] Preserve an existing photo after a failed replacement; keep orphan drafts identifiable and document an admin cleanup procedure. Clear image caches on scope/auth changes.
- [ ] Run image tests and Storage emulator authorization tests; compile web paths to detect accidental `dart:io` use.

### Task 11: Build convert registration and edit forms

**Source:** `Register.jsx`, `ConvertForm.jsx`, `PhotoUpload.jsx`.
**Files:** create `lib/features/converts/application/convert_form_controller.dart`, `lib/features/converts/presentation/convert_form_page.dart`, `test/converts/convert_form_test.dart`; wire routes and repositories.
**Consumes/produces:** models/catalog/commands/photo → validated create/edit UX with pt-BR feedback.

- [ ] Test all five required fields, optional empty congregation/phone with orange highlighting, age zero/150, future date rejection, 64 worship choices, photo draft submission and submit-in-flight double tap.
- [ ] Implement keyboard-safe responsive form, optional image handling, cancel, busy/error/retry states and one command ID per submit intent. A registrar sees success without gaining record-read access.
- [ ] Preserve user input after a failed save; deny tampered edit routes before loading private data. Only explicit reset/success discards a draft.
- [ ] Run `D(test/converts/convert_form_test.dart)` at phone/desktop sizes; analyzer.

### Task 12: Build convert list, cards and lifecycle interactions

**Source:** `Converts.jsx`, `ConvertCard.jsx`, congregation ordering utilities.
**Files:** create `lib/features/converts/application/convert_list_controller.dart`, `lib/features/converts/presentation/convert_list_page.dart`, `lib/features/converts/presentation/convert_card.dart`, `lib/features/converts/presentation/convert_detail_page.dart`, `test/converts/convert_list_test.dart`.
**Consumes/produces:** authorized snapshots + policies/commands → source-faithful search/filter/cards/edit/detail/lifecycle UX.

- [ ] Test case-insensitive name search, status/congregation filters and counts after filtering, Sede ordering, completed/deviated exclusion, missing contact highlights, photo zoom and empty/error/loading states.
- [ ] Implement source confirmation dialogs and eligibility rules, pending command controls and refresh after confirmed receipts. Repeated clicks/retries cannot create extra visits/events.
- [ ] Normalize WhatsApp digits, preserve/prepend country code 55, and disable unusable phone values; use `url_launcher` on Android/web. Soft-delete requires an explicit UI confirmation.
- [ ] Run `D(test/converts/convert_list_test.dart)`, route denial and lifecycle interaction widget tests; analyzer.

### Task 13: Implement weekly zero-conversion reporting

**Source:** `WeeklyConversionReport.jsx`, `weeklyReportUtils.js`.
**Files:** create `functions/src/weekly_reports/weekly_report_commands.ts`, `lib/features/weekly_reports/data/firebase_weekly_repository.dart`, `lib/features/weekly_reports/presentation/weekly_report_section.dart`, `functions/test/emulator/weekly_reports.test.ts`, `test/weekly_reports/weekly_section_test.dart`.
**Consumes/produces:** reporting period/week counters → `confirmNoConversions`, scoped statuses and supervisor overview.

- [ ] Test Sunday threshold and Monday rollover, own-congregation confirmation, deterministic duplicate confirmation, nonzero-week rejection and supervisor confirmed/waiting overview.
- [ ] Implement zero-count check and deterministic report write inside the same counter/profile transaction. Convert creation/move/import removes the matching report atomically; a delete does not invent a confirmation.
- [ ] Race confirmation against create/update/import and prove a final positive count never coexists with a valid zero-conversion confirmation. Use injected server clock in tests.
- [ ] Run weekly emulator/widget tests plus impacted CRUD tests and backend build/analyzer.

### Task 14: Complete Home and responsive app shell

**Source:** `Layout.jsx`, `Home.jsx`; spec §§4–5/9.
**Files:** create `lib/core/theme/app_theme.dart`, `lib/app/app_shell.dart`, `lib/features/home/domain/home_summary.dart`, `lib/features/home/presentation/home_page.dart`, `test/home/home_shell_test.dart`; modify root app/router.
**Consumes/produces:** scope, complete snapshots, weekly section → branded navigation and dashboard.

- [ ] Test navbar/menu/bottom navigation per role; no-access user sees Register only; Home counts include source terminal states but exclude soft-deleted records; recent list is latest five within seven days.
- [ ] Implement exact source palette, desktop max content width 896 and form width 512 logical pixels; breakpoint 768. Use all pt-BR labels, church mark, source quick actions and authorized weekly report section.
- [ ] Test widths 360/768/1280, keyboard focus, text scale 2.0, scrollability and feedback placement above bottom navigation. Register remains accessible without Home privilege.
- [ ] Run `D(test/home/home_shell_test.dart)`, auth route regression tests and analyzer.

### Task 15: Build congregation administration and Admin shell

**Source:** `Admin.jsx`, `CongregationManager.jsx`.
**Files:** create `functions/src/congregations/congregation_commands.ts`, `lib/features/admin/presentation/admin_page.dart`, `lib/features/congregations/presentation/congregation_manager.dart`, `functions/test/emulator/congregations.test.ts`, `test/admin/congregation_manager_test.dart`.
**Consumes/produces:** global access + catalog → `saveCongregation`, `deleteCongregation`, Admin summary and five-tab shell.

- [ ] Test nonempty trimmed names, source ordering, unauthorized mutations, and deletion blocked by any referenced record or active grant. Validate references on the server, including concurrent use/deletion.
- [ ] Implement admin/supervision CRUD and summary totals/discipleship/visited counts from complete global snapshots. Delete uses confirmation; protected-reference errors are pt-BR and actionable.
- [ ] Wire Congregações and the task-owned Admin routes; remaining feature tabs connect in their tasks. Denied users must not fetch global stats before the guard resolves.
- [ ] Run congregation emulator/widget tests, route denial regression and backend build/analyzer.

### Task 16: Build access management UI

**Source:** `UserAccessManager.jsx`.
**Files:** create `lib/features/access/data/firebase_grant_repository.dart`, `lib/features/access/application/access_manager_controller.dart`, `lib/features/access/presentation/access_manager.dart`, `test/admin/access_manager_test.dart`; modify Admin wiring.
**Consumes/produces:** Task 5 commands → exact two source grant roles and congregation-aware management.

- [ ] Test direction requires congregation, supervision requires null, normalized duplicate email/role/congregation rejection, staged grants for unknown users, and editing/revoking a bound grant.
- [ ] Implement email normalization, create/edit/revoke confirmations, busy/error states and role labels from the source. Never display admin as an assignable role.
- [ ] Demonstrate that client-modified payloads still fail at Task 5's backend and that revocation removes the affected user's active view on the next profile notification.
- [ ] Run access manager widget tests and focused access emulator regressions; analyzer.

### Task 17: Implement reports, event table and shared XLSX/file adapters

**Source:** `ConversionReport.jsx`, `ConvertEventsLog.jsx`.
**Files:** create `lib/core/files/file_transfer_service.dart`, `lib/core/files/workbook_service.dart`, `lib/features/admin/presentation/conversion_report.dart`, `lib/features/events/presentation/event_log.dart`, `test/reports/report_export_test.dart`; modify Admin wiring.
**Consumes/produces:** complete scoped snapshots, event repositories → report charts/tables and byte-oriented XLSX saving on both platforms.

- [ ] Test inclusive optional date filters, start>end validation, event Apply state, congregation filtering, pt-BR column sort toggle and export matching exactly visible order/rows; include >1,000 events.
- [ ] Implement worship grouping/descending totals, accessible chart + textual totals, empty states and source spreadsheet column labels. Events retain actor/name/congregation snapshots after deletion.
- [ ] Implement byte-based `file_saver`/picker adapters and Excel text-safe values; use a user-accessible Android save location, not a hidden app-private default. Choose/save/download cancellation must not report success. Keep typed bytes/rows independent of widget code.
- [ ] Run `D(test/reports/report_export_test.dart)`; round-trip generated workbooks and smoke-save on web/Android; analyzer.

### Task 18: Implement backup codec and import preview

**Source:** `BackupManager.jsx`; spec §8 is authoritative for deliberate corrections.
**Files:** create `lib/features/backup/domain/backup_row.dart`, `lib/features/backup/data/backup_codec.dart`, `lib/features/backup/presentation/import_preview.dart`, `test/backup/backup_codec_test.dart`.
**Consumes/produces:** WorkbookService → original/v2 XLSX decode/encode and typed valid/invalid/warning/skipped rows.

- [ ] Test original 14 columns and v2 additions, zero age, null congregation, unknown vs ambiguous congregation, exact booleans/gender, invalid dates, missing/duplicate IDs, formula cells and invalid archives.
- [ ] Enforce XLSX-only input, 10 MiB compressed/50 MiB expanded/10,000-row limits before costly processing; explicitly reject `.xls`. Preserve the source sheet/columns and fixed UI vocabulary; metadata version does not masquerade as a full photo backup.
- [ ] Preview row numbers and validation reasons before writes. Mark existing/within-file IDs skipped and preserve stable internal IDs; missing legacy start date is not today.
- [ ] Run `D(test/backup/backup_codec_test.dart)` with synthetic workbook fixtures and decode→encode→decode assertions; analyzer.

### Task 19: Implement resumable idempotent backup merge

**Files:** create `functions/src/backup/import_commands.ts`, `lib/features/backup/application/backup_controller.dart`, `lib/features/backup/presentation/backup_manager.dart`, `functions/test/emulator/backup_import.test.ts`, `test/backup/backup_controller_test.dart`; wire Backup tab.
**Consumes/produces:** validated rows + shared command/internal-ID/week-counter logic → `importBackupChunk`, progress receipts and complete exports.

- [ ] Test reimport of original IDs, duplicate IDs across concurrent clients, lost-response retry, one malformed row, unauthorized caller, more than 25 rows, and continuation after partial completion.
- [ ] Implement max-25-row chunks with server revalidation and per-row atomic reservation/create/week update. Preserve inserted IDs and never overwrite an existing mapping; import must share CRUD invariants rather than duplicating them.
- [ ] Persist resumable import progress/operation IDs for the current user/session; clear it on sign-out. Export every nondeleted authorized record, including terminal states, and disclose that photos are not embedded.
- [ ] Run import emulator/client tests and weekly-race regression; verify second import creates zero records; backend build/analyzer.

### Task 20: Implement feedback submission and management

**Source:** `FeedbackButton.jsx`, `FeedbackManager.jsx` (manager previously unmounted).
**Files:** create `functions/src/feedback/feedback_commands.ts`, `lib/features/feedback/data/firebase_feedback_repository.dart`, `lib/features/feedback/presentation/feedback_dialog.dart`, `lib/features/feedback/presentation/feedback_manager.dart`, `functions/test/emulator/feedback.test.ts`, `test/feedback/feedback_flow_test.dart`.
**Consumes/produces:** authenticated identity + global access → `submitFeedback`, `setFeedbackStatus`, floating action and Admin manager action.

- [ ] Test trimmed nonempty message, server-derived actor, default pending, submitter denied global reads/status writes, supervisor/admin pending→read→resolved management and retry behavior.
- [ ] Implement pt-BR dialog and manager; keep the five main tabs and open management from an Admin action. Map backend errors without discarding an unsent message.
- [ ] Enforce a documented 5,000-character limit client/server and disable duplicate submit while pending. No external email/message integration is implied.
- [ ] Run feedback emulator/widget tests and responsive shell regression; backend build/analyzer.

### Task 21: Verify the complete application and prepare release handoff

**Files:** create `integration_test/critical_flows_test.dart`, `docs/release-checklist.md`, `docs/verification-report.md`; update `README.md`, Firebase setup docs and dependency ledger. Application fixes are delegated and reviewed, not silently made by the controller.
**Consumes/produces:** Tasks 1–20 approved → reviewed local Flutter app, reproducible emulators and build artifacts with honest release status.

- [ ] Run analyzer, meaningful Flutter suite, TypeScript build/tests and complete emulator Rules/command suite once against the final candidate; investigate any failure before deciding it is external or out of scope.
- [ ] Exercise synthetic end-to-end paths: registrar create/photo, direction list/visit/start, 90-day completion fixture, revoked access, weekly confirmation race, Admin CRUD/report/export/reimport and feedback workflow. Check 360/768/1280 widths, 200% text, keyboard and offline/error states.
- [ ] Build `flutter build web --release` and `flutter build apk --debug`; perform an unsigned release-build check or signed release build only when signing is supplied. Smoke-run on an available Android emulator/device; missing device is a documented validation gap, not a pass.
- [ ] Verify the 101-file reference manifest remains unchanged. Record versioned dependencies, test/build commands and outputs, unresolved release prerequisites and deviations. Run one fresh whole-branch review with `gpt-6.1-sol`/`low`, including deferred findings; repair important findings and perform a scoped re-review.
- [ ] Document Firebase project/region selection, FlutterFire configuration, Google OAuth/domain/SHA setup, bootstrap-admin action, App Check rollout, Rules/index deployment, Hosting and Android signing. Keep production deployment, billing changes and real data migration pending explicit release instructions.

## Self-review

Coverage: source shell, authentication, all six entities, optional registration fields, access scoping, all lifecycle transitions, weekly reporting, photos, congregation/access management, reports/events/export, backup, feedback and web/Android delivery each have an owning task. Base44-only OAuth tool consent is explicitly excluded in the spec. Review Focus items map to named tests; shared interfaces are defined once; every dependent backend write reuses command/access/week logic. Task 21 is verification, not a second implementation pass. No live backend or product files were created by this plan.
