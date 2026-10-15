# IEADPE Flutter + Supabase Free Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use two-model-sdd-pipeline with flutter-app-pipeline task-by-task. The user fixes every model and effort; no escalation. Steps use checkbox syntax.

**Goal:** Recreate the captured IEADPE app in Flutter for web and Android using Supabase Free and Google OAuth.

**Architecture:** Feature repositories call Supabase reads under RLS and authorized PostgreSQL RPC commands for transactional mutations. Private Storage uses a draft/upload/attach protocol. Flutter shares domain logic across both platforms.

**Tech Stack:** Flutter/Dart, Riverpod, go_router, supabase_flutter, PostgreSQL/pgTAP, Supabase CLI/Docker, local XLSX and platform file adapters.

**Spec:** [Design](../specs/2026-10-14-ieadpe-flutter-supabase-free-design.md).
**Executable plan:** [Pipeline JSON](2026-10-14-ieadpe-flutter-supabase-free-plan.json).
**Execution:** [SDD runbook](ieadpe-supabase-sdd-runbook.md). Implementation has not started.

## Global Constraints

- Flutter web and Android; app UI is pt-BR; communication, comments and artifacts are English.
- Supabase Free only; no billing activation, paid add-ons or mandatory Edge Functions.
- Google OAuth is the baseline login; email/password and SMS are deferred.
- Every SDD role uses gpt-6.1-sol with low reasoning effort; no automatic escalation.
- PostgreSQL RLS and authorized transactional RPCs enforce access and business invariants.
- Preserve all 101 captured source files unchanged; use synthetic local development data.
- Production deployment, live access grants and private-record migration are separate release actions.

## Review Focus

1. Revoked/pending/unverified identity must not retain or acquire protected access (Tasks 3, 4, 6).
2. Lost responses and competing commands must not duplicate records/events or leave false zero reports (Tasks 5, 6, 11, 16).
3. Browser timezone, missing historical dates and DST boundaries must not bypass lifecycle/report eligibility (Tasks 2, 6, 11, 15).
4. Malformed/oversized workbooks and legacy IDs must not exhaust memory, resurrect records or corrupt counters (Tasks 15–16).
5. Photo upload/save cancellation, orphan files and revoked access must preserve privacy and honest success states (Tasks 8, 9, 14, 18).

## Ownership and shared contracts

Task files below are exact ownership; migration numbers are append-only. lib/domain holds immutable domain values; lib/data holds backend adapters; lib/features owns screens and feature repositories; lib/platform owns web/Android differences. Tests mirror ownership. A later task may extend an earlier interface only by recording the compatibility change in its brief and ledger, reviewing affected callers and rerunning covering checks.

All SQL commands use (operation_id uuid,payload jsonb) -> jsonb. Dart Gateway.command maps command names to ieadpe_<command>. Payload keys use schema snake_case, Dart models use explicit codecs. MutationResult contains recordId and outcome only; authorized follow-up reads retrieve full state. DateOnly is an immutable year/month/day value with yyyy-MM-dd serialization. AccessScope contains admin/supervision flags and congregation IDs. Source references are task-specific paths under reference/base44, especially src/Layout.jsx, src/pages, src/components and base44/entities; preserve manifest hashes.

## Common task execution

Each task inherits the runbook: investigate first, read only relevant source/contracts, prove a meaningful failing assertion, implement, run covering checks, self-review, commit, then independent review. Test names/assertions below are mandatory scenarios; add narrowly relevant regressions discovered during implementation. SQL concurrency checks must use independent local sessions, not merely sequential pgTAP calls. Commands separated by semicolons below are separate invocations, not a requirement to chain shells. Never deploy as a test.

### Task 1: Bootstrap the local application

**Files:** `pubspec.yaml`, `lib/main.dart`, `lib/app.dart`, `supabase/config.toml`, `scripts/check.ps1`.
**Tests:** `test/app_smoke_test.dart`.
**Interfaces:** App() -> Widget; local-only configuration through --dart-define.

- [ ] Investigate the owning source and predecessor interfaces; record current checkout and evidence.
- [ ] Add tests asserting: Empty app starts with pt-BR locale; missing backend configuration shows a recoverable setup screen, never a production fallback.
- [ ] Run the narrow test file(s); confirm failure at the new assertion demonstrates missing behavior, not broken tooling.
- [ ] Create Flutter web/Android scaffold, resolve and lock packages, initialize local Supabase and Git after checking parent instructions. Record Flutter, Java, Android SDK, Docker and CLI availability.
- [ ] Run separately: `flutter test test/app_smoke_test.dart`. Expect passing checks; investigate any failure before proceeding. Run platform/Storage integration cases against local services where unit checks cannot prove behavior.
- [ ] Self-review, commit owned changes, and complete the independent review/fix cycle from the runbook.

### Task 2: Domain models and business calendar

**Files:** `lib/domain/models.dart`, `lib/domain/business_calendar.dart`, `lib/domain/convert_policy.dart`, `lib/domain/worship_types.dart`.
**Tests:** `test/domain/convert_policy_test.dart`.
**Interfaces:** BusinessCalendar.today(DateTime instant) -> DateOnly; visitState(ConvertRecord, DateOnly) -> VisitState.

- [ ] Investigate the owning source and predecessor interfaces; record current checkout and evidence.
- [ ] Add tests asserting: Assert due boundaries 1/7/30 days, completion 89/90 days, deviation 2/3 visits, missing start, age zero, all 64 source worship values and Sunday 19:59/20:00 in Sao Paulo.
- [ ] Run the narrow test file(s); confirm failure at the new assertion demonstrates missing behavior, not broken tooling.
- [ ] Define immutable DTO/domain types, date-only codecs, source enum mappings and pure lifecycle predicates. Define Page<T>(items,nextCursor), AccessScope and MutationResult.
- [ ] Run separately: `flutter test test/domain`. Expect passing checks; investigate any failure before proceeding. Run platform/Storage integration cases against local services where unit checks cannot prove behavior.
- [ ] Self-review, commit owned changes, and complete the independent review/fix cycle from the runbook.

### Task 3: Schema, verified identity and RLS

**Files:** `supabase/migrations/202610140001_identity.sql`, `supabase/migrations/202610140002_schema.sql`, `supabase/migrations/202610140003_access.sql`.
**Tests:** `supabase/tests/database/access_test.sql`.
**Interfaces:** ieadpe_save_access(operation_id uuid,payload jsonb) -> jsonb; ieadpe_revoke_access(operation_id uuid,payload jsonb) -> jsonb; private.can_access_congregation(uuid) -> boolean.

- [ ] Investigate the owning source and predecessor interfaces; record current checkout and evidence.
- [ ] Add tests asserting: Anonymous reads denied; registrar cannot enumerate converts; direction cannot cross congregation; supervision global; editable metadata cannot grant admin; unverified email cannot bind a pending grant; revoked access denies the next read.
- [ ] Run the narrow test file(s); confirm failure at the new assertion demonstrates missing behavior, not broken tooling.
- [ ] Create schema, indexes, profiles trigger, private helpers, default-deny policies, fixed search_path and restricted execution. Add access-version locking, trusted pending-email binding and admin bootstrap instructions.
- [ ] Run separately: `supabase test db`. Expect passing checks; investigate any failure before proceeding. Run platform/Storage integration cases against local services where unit checks cannot prove behavior.
- [ ] Self-review, commit owned changes, and complete the independent review/fix cycle from the runbook.

### Task 4: Google session and navigation guards

**Files:** `lib/features/auth/auth_repository.dart`, `lib/features/auth/login_page.dart`, `lib/routing/router.dart`, `android/app/src/main/AndroidManifest.xml`.
**Tests:** `test/features/auth/auth_flow_test.dart`.
**Interfaces:** AuthRepository.signInWithGoogle() -> Future<void>; watchSession() -> Stream<Session?>; loadScope() -> Future<AccessScope>.

- [ ] Investigate the owning source and predecessor interfaces; record current checkout and evidence.
- [ ] Add tests asserting: Cancelled login remains usable; callback restores intended safe route; registrar sees Register only; sign-out and lost grants clear protected caches; malformed callback cannot bypass guards.
- [ ] Run the narrow test file(s); confirm failure at the new assertion demonstrates missing behavior, not broken tooling.
- [ ] Implement Supabase PKCE flow, web redirect configuration and Android deep link. Define Configuration for URL/publishable key and require external Google secrets only in provider setup.
- [ ] Run separately: `flutter test test/features/auth`. Expect passing checks; investigate any failure before proceeding. Run platform/Storage integration cases against local services where unit checks cannot prove behavior.
- [ ] Self-review, commit owned changes, and complete the independent review/fix cycle from the runbook.

### Task 5: Transactional registration, edits and deletion

**Files:** `supabase/migrations/202610140004_convert_commands.sql`.
**Tests:** `supabase/tests/database/convert_commands_test.sql`.
**Interfaces:** ieadpe_create_convert; ieadpe_edit_convert; ieadpe_delete_convert: (operation_id uuid,payload jsonb) -> jsonb.

- [ ] Investigate the owning source and predecessor interfaces; record current checkout and evidence.
- [ ] Add tests asserting: Retry creates one record; changed payload with same ID fails; scope-changing edit checks both scopes; future date fails; simultaneous create/zero-confirm cannot leave a false zero report; tombstone retains internal ID.
- [ ] Run the narrow test file(s); confirm failure at the new assertion demonstrates missing behavior, not broken tooling.
- [ ] Implement receipts, strict payload validation, sorted locks and congregation-week counters. Expose minimal create result to registrar, soft delete and remove matching zero report atomically. Include confirm-zero SQL now so race is tested here.
- [ ] Run separately: `supabase test db`. Expect passing checks; investigate any failure before proceeding. Run platform/Storage integration cases against local services where unit checks cannot prove behavior.
- [ ] Self-review, commit owned changes, and complete the independent review/fix cycle from the runbook.

### Task 6: Atomic lifecycle commands

**Files:** `supabase/migrations/202610140005_lifecycle.sql`.
**Tests:** `supabase/tests/database/lifecycle_test.sql`.
**Interfaces:** ieadpe_transition_convert(operation_id uuid,payload jsonb) -> jsonb; action in visit/start/stop/complete/deviate.

- [ ] Investigate the owning source and predecessor interfaces; record current checkout and evidence.
- [ ] Add tests asserting: Double visit yields one increment/event; concurrent completion/deviation cannot create conflicting terminal state; actor/time spoof denied; stop creates no event; revoked actor cannot finish a later authorized write.
- [ ] Run the narrow test file(s); confirm failure at the new assertion demonstrates missing behavior, not broken tooling.
- [ ] Lock and re-read current state; enforce server date predicates, immutable event snapshots and receipt coupling in one transaction. Test concurrent sessions as well as sequential calls.
- [ ] Run separately: `supabase test db`. Expect passing checks; investigate any failure before proceeding. Run platform/Storage integration cases against local services where unit checks cannot prove behavior.
- [ ] Self-review, commit owned changes, and complete the independent review/fix cycle from the runbook.

### Task 7: Flutter data gateway and scoped pagination

**Files:** `lib/data/supabase_gateway.dart`, `lib/data/convert_repository.dart`, `lib/data/access_repository.dart`.
**Tests:** `test/data/repositories_test.dart`.
**Interfaces:** Gateway.command(String command,String operationId,Map<String,Object?> payload) -> Future<MutationResult>; ConvertRepository.list(ConvertQuery query,String? cursor) -> Future<Page<ConvertRecord>>.

- [ ] Investigate the owning source and predecessor interfaces; record current checkout and evidence.
- [ ] Add tests asserting: A 1,205-row fixture returns every permitted row exactly once; changed access discards stale response; timeout retries reuse operation ID; permanent permission errors do not retry.
- [ ] Run the narrow test file(s); confirm failure at the new assertion demonstrates missing behavior, not broken tooling.
- [ ] Implement strict DTO decoding, cursor pagination and 3-attempt transient retry policy. Keep backend errors distinct from empty results and inject gateway for widget tests.
- [ ] Run separately: `flutter test test/data`. Expect passing checks; investigate any failure before proceeding. Run platform/Storage integration cases against local services where unit checks cannot prove behavior.
- [ ] Self-review, commit owned changes, and complete the independent review/fix cycle from the runbook.

### Task 8: Private photo draft and upload protocol

**Files:** `supabase/migrations/202610140006_photos.sql`, `lib/features/photos/photo_repository.dart`, `lib/features/photos/photo_processor.dart`.
**Tests:** `supabase/tests/database/photos_test.sql`, `test/features/photos/photo_test.dart`.
**Interfaces:** ieadpe_create_photo_draft; ieadpe_detach_photo: standard RPC envelope; PhotoRepository.upload(bytes) -> Future<PhotoAsset>; download(PhotoAsset) -> Future<Uint8List>.

- [ ] Investigate the owning source and predecessor interfaces; record current checkout and evidence.
- [ ] Add tests asserting: Cross-owner attach, expired draft, public read and oversize upload denied; image becomes 192x192 JPEG; upload/attach failure keeps old photo; revoked uploader cannot read attached image through ownership.
- [ ] Run the narrow test file(s); confirm failure at the new assertion demonstrates missing behavior, not broken tooling.
- [ ] Create private bucket/policies and asset protocol; extend create/edit commands for attachment. Use authenticated bytes, no upsert or public URLs. Test Storage API policies against local backend in addition to SQL asset tests.
- [ ] Run separately: `flutter test test/features/photos`, `supabase test db`. Expect passing checks; investigate any failure before proceeding. Run platform/Storage integration cases against local services where unit checks cannot prove behavior.
- [ ] Self-review, commit owned changes, and complete the independent review/fix cycle from the runbook.

### Task 9: Registration and edit forms

**Files:** `lib/features/converts/convert_form.dart`, `lib/features/converts/register_page.dart`, `lib/features/converts/edit_page.dart`.
**Tests:** `test/features/converts/form_test.dart`.
**Interfaces:** ConvertForm(initial: ConvertRecord?,onSubmit: Future<void> Function(ConvertDraft)) -> Widget.

- [ ] Investigate the owning source and predecessor interfaces; record current checkout and evidence.
- [ ] Add tests asserting: Phone/congregation may be empty; required trimmed name/landmark fail when blank; age zero survives; double tap submits once; photo selection cancellation preserves draft; source worship selection round-trips.
- [ ] Run the narrow test file(s); confirm failure at the new assertion demonstrates missing behavior, not broken tooling.
- [ ] Build source form with 512 width, pt-BR validation, optional photo, recoverable save failure and registration success state; inject repositories from Tasks 7–8.
- [ ] Run separately: `flutter test test/features/converts/form_test.dart`. Expect passing checks; investigate any failure before proceeding. Run platform/Storage integration cases against local services where unit checks cannot prove behavior.
- [ ] Self-review, commit owned changes, and complete the independent review/fix cycle from the runbook.

### Task 10: Lists, cards and lifecycle UI

**Files:** `lib/features/converts/converts_page.dart`, `lib/features/converts/convert_card.dart`, `lib/features/converts/convert_actions.dart`.
**Tests:** `test/features/converts/list_test.dart`.
**Interfaces:** ConvertsPage(scope: AccessScope) -> Widget; ConvertActions.execute(ConvertAction action,ConvertRecord record) -> Future<void>.

- [ ] Investigate the owning source and predecessor interfaces; record current checkout and evidence.
- [ ] Add tests asserting: Overdue discipleship is yellow, terminal records are excluded, source name/status/congregation filters work, sede sorts first, unknown congregations last and invalid WhatsApp is disabled.
- [ ] Run the narrow test file(s); confirm failure at the new assertion demonstrates missing behavior, not broken tooling.
- [ ] Connect scoped pagination and policies to source cards/actions with pending controls, confirmations and server-refresh on stale mutation. Normalize Brazilian WhatsApp URLs.
- [ ] Run separately: `flutter test test/features/converts/list_test.dart`. Expect passing checks; investigate any failure before proceeding. Run platform/Storage integration cases against local services where unit checks cannot prove behavior.
- [ ] Self-review, commit owned changes, and complete the independent review/fix cycle from the runbook.

### Task 11: Weekly reports UI and overview

**Files:** `lib/features/weekly/weekly_repository.dart`, `lib/features/weekly/weekly_panel.dart`, `supabase/migrations/202610140007_weekly_reads.sql`.
**Tests:** `test/features/weekly/weekly_test.dart`, `supabase/tests/database/weekly_test.sql`.
**Interfaces:** WeeklyRepository.overview() -> Future<WeeklyOverview>; confirmZero(String congregationId,String operationId) -> Future<MutationResult>.

- [ ] Investigate the owning source and predecessor interfaces; record current checkout and evidence.
- [ ] Add tests asserting: Sunday 19:59 hides and 20:00 shows; direction sees own congregation; global overview shows confirmed/waiting; move/delete/import updates affected week counts correctly.
- [ ] Run the narrow test file(s); confirm failure at the new assertion demonstrates missing behavior, not broken tooling.
- [ ] Consume Task 5 confirm command, implement server-authoritative reporting window RPC and scoped overview; avoid browser timezone eligibility.
- [ ] Run separately: `flutter test test/features/weekly`, `supabase test db`. Expect passing checks; investigate any failure before proceeding. Run platform/Storage integration cases against local services where unit checks cannot prove behavior.
- [ ] Self-review, commit owned changes, and complete the independent review/fix cycle from the runbook.

### Task 12: Responsive shell and Home

**Files:** `lib/features/home/home_page.dart`, `lib/features/home/home_repository.dart`, `lib/widgets/app_shell.dart`, `lib/widgets/brand_header.dart`.
**Tests:** `test/features/home/home_test.dart`, `test/widgets/app_shell_test.dart`.
**Interfaces:** HomeRepository.summary() -> Future<HomeSummary>; AppShell(child: Widget) -> Widget.

- [ ] Investigate the owning source and predecessor interfaces; record current checkout and evidence.
- [ ] Add tests asserting: Widths 360/768/1280 have usable navigation; Home totals include terminal but exclude deleted; recent list uses last 7 days/latest 5; registrar redirects private deep link.
- [ ] Run the narrow test file(s); confirm failure at the new assertion demonstrates missing behavior, not broken tooling.
- [ ] Port source gradient, branding and navigation at 768 breakpoint, max width 896, Home metrics, weekly panel and floating feedback placeholder. Aggregate all permitted pages without source 1,000-row truncation.
- [ ] Run separately: `flutter test test/features/home test/widgets`. Expect passing checks; investigate any failure before proceeding. Run platform/Storage integration cases against local services where unit checks cannot prove behavior.
- [ ] Self-review, commit owned changes, and complete the independent review/fix cycle from the runbook.

### Task 13: Congregation and access management

**Files:** `lib/features/admin/admin_page.dart`, `lib/features/admin/congregations_panel.dart`, `lib/features/admin/access_panel.dart`, `supabase/migrations/202610140008_catalog_commands.sql`.
**Tests:** `test/features/admin/catalog_test.dart`, `supabase/tests/database/catalog_test.sql`.
**Interfaces:** ieadpe_save_congregation; ieadpe_archive_congregation: standard RPC envelope; AdminPage(scope: AccessScope) -> Widget.

- [ ] Investigate the owning source and predecessor interfaces; record current checkout and evidence.
- [ ] Add tests asserting: Referenced congregation archives without orphaning records; archived catalog cannot be selected for new record; pending verified-email grant binds once; multiple direction grants work; manager cannot create admin.
- [ ] Run the narrow test file(s); confirm failure at the new assertion demonstrates missing behavior, not broken tooling.
- [ ] Build five-tab Admin shell, source congregation/access controls and live scope refresh. Reuse Task 3 grant RPCs; expose feedback action later.
- [ ] Run separately: `flutter test test/features/admin`, `supabase test db`. Expect passing checks; investigate any failure before proceeding. Run platform/Storage integration cases against local services where unit checks cannot prove behavior.
- [ ] Self-review, commit owned changes, and complete the independent review/fix cycle from the runbook.

### Task 14: Event and conversion reports with file adapters

**Files:** `lib/features/reports/reports_repository.dart`, `lib/features/reports/events_panel.dart`, `lib/features/reports/conversion_panel.dart`, `lib/platform/file_exporter.dart`.
**Tests:** `test/features/reports/reports_test.dart`, `test/platform/file_exporter_test.dart`.
**Interfaces:** ReportsRepository.events(EventQuery) -> Future<List<ConvertEvent>>; conversions(DateRange) -> Future<List<WorshipCount>>; FileExporter.save(String filename,Uint8List bytes) -> Future<SaveOutcome>.

- [ ] Investigate the owning source and predecessor interfaces; record current checkout and evidence.
- [ ] Add tests asserting: Inclusive dates, explicit Aplicar, column sort and congregation filter export exactly displayed rows; >1,000 rows survive; accents preserved; save cancelled differs from saved on both platforms.
- [ ] Run the narrow test file(s); confirm failure at the new assertion demonstrates missing behavior, not broken tooling.
- [ ] Implement source chart/grouping and XLSX headers. Save web download and Android user-selected accessible destination through platform adapter; no false success toast.
- [ ] Run separately: `flutter test test/features/reports test/platform`. Expect passing checks; investigate any failure before proceeding. Run platform/Storage integration cases against local services where unit checks cannot prove behavior.
- [ ] Self-review, commit owned changes, and complete the independent review/fix cycle from the runbook.

### Task 15: Versioned safe XLSX codec

**Files:** `lib/features/backup/backup_codec.dart`, `lib/features/backup/backup_models.dart`.
**Tests:** `test/features/backup/backup_codec_test.dart`.
**Interfaces:** BackupCodec.decode(Uint8List bytes) -> ImportPreview; encode(List<ConvertRecord> records) -> Uint8List.

- [ ] Investigate the owning source and predecessor interfaces; record current checkout and evidence.
- [ ] Add tests asserting: Round-trip age zero, source 14 columns and v2 dates; legacy missing start stays null; reject formula cells, .xls, malformed ZIP and 10,001 rows; reject compressed >10MiB or expanded >50MiB before unbounded allocation.
- [ ] Run the narrow test file(s); confirm failure at the new assertion demonstrates missing behavior, not broken tooling.
- [ ] Implement exact spec headers, typed text exports, version metadata, limits and deterministic row diagnostics; no binary photos in workbook.
- [ ] Run separately: `flutter test test/features/backup/backup_codec_test.dart`. Expect passing checks; investigate any failure before proceeding. Run platform/Storage integration cases against local services where unit checks cannot prove behavior.
- [ ] Self-review, commit owned changes, and complete the independent review/fix cycle from the runbook.

### Task 16: Resumable import and backup UI

**Files:** `supabase/migrations/202610140009_import.sql`, `lib/features/backup/backup_repository.dart`, `lib/features/backup/backup_panel.dart`.
**Tests:** `supabase/tests/database/import_test.sql`, `test/features/backup/import_test.dart`.
**Interfaces:** ieadpe_import_convert(operation_id uuid,payload jsonb) -> jsonb; BackupRepository.importRows(ImportPreview preview) -> Stream<ImportProgress>.

- [ ] Investigate the owning source and predecessor interfaces; record current checkout and evidence.
- [ ] Add tests asserting: Import/reimport creates one stable record per internal ID; tombstones skip; interrupted retry resumes; unknown congregation warns/null and ambiguous errors; historical fields preserve eligibility and week counters.
- [ ] Run the narrow test file(s); confirm failure at the new assertion demonstrates missing behavior, not broken tooling.
- [ ] Add global-only validated row RPC sharing Task 5 invariants and unique keys; import per row, persist operation/progress IDs without raw personal values in logs. Connect preview/confirm/progress/export to Backup tab.
- [ ] Run separately: `flutter test test/features/backup`, `supabase test db`. Expect passing checks; investigate any failure before proceeding. Run platform/Storage integration cases against local services where unit checks cannot prove behavior.
- [ ] Self-review, commit owned changes, and complete the independent review/fix cycle from the runbook.

### Task 17: Feedback submission and management

**Files:** `supabase/migrations/202610140010_feedback.sql`, `lib/features/feedback/feedback_repository.dart`, `lib/features/feedback/feedback_dialog.dart`, `lib/features/feedback/feedback_manager.dart`.
**Tests:** `supabase/tests/database/feedback_test.sql`, `test/features/feedback/feedback_test.dart`.
**Interfaces:** ieadpe_submit_feedback; ieadpe_update_feedback: standard RPC envelope; FeedbackRepository.submit(String message,String operationId) -> Future<MutationResult>.

- [ ] Investigate the owning source and predecessor interfaces; record current checkout and evidence.
- [ ] Add tests asserting: Registrar submits but cannot list; blank or >5,000-character message rejected; server actor cannot be spoofed; global manager transitions pending/read/resolved; retry creates one feedback.
- [ ] Run the narrow test file(s); confirm failure at the new assertion demonstrates missing behavior, not broken tooling.
- [ ] Complete floating action and Admin management action; preserve five tabs, strict status enum and recoverable pending UI.
- [ ] Run separately: `flutter test test/features/feedback`, `supabase test db`. Expect passing checks; investigate any failure before proceeding. Run platform/Storage integration cases against local services where unit checks cannot prove behavior.
- [ ] Self-review, commit owned changes, and complete the independent review/fix cycle from the runbook.

### Task 18: Free operations and release preparation

**Files:** `docs/operations/supabase-free.md`, `docs/operations/google-oauth.md`, `docs/operations/release.md`, `scripts/maintenance_photos.ps1`, `web/_redirects`.
**Tests:** `test/operations/configuration_test.dart`.
**Interfaces:** Maintenance dry-run outputs IDs/counts; explicit apply uses Storage API before metadata cleanup.

- [ ] Investigate the owning source and predecessor interfaces; record current checkout and evidence.
- [ ] Add tests asserting: Missing configuration cannot contact production; maintenance skips attached photos and handles partial failure; deep-link refresh works under static hosting configuration; oversized hosting artifact is reported.
- [ ] Run the narrow test file(s); confirm failure at the new assertion demonstrates missing behavior, not broken tooling.
- [ ] Document quotas, inactivity/manual resume, manual DB+Storage backups, Google console/PKCE setup, static web hosting and Android signing. Prepare dry-run cleanup and deployment instructions without provisioning remote resources or activating billing.
- [ ] Run separately: `flutter test test/operations/configuration_test.dart`. Expect passing checks; investigate any failure before proceeding. Run platform/Storage integration cases against local services where unit checks cannot prove behavior.
- [ ] Self-review, commit owned changes, and complete the independent review/fix cycle from the runbook.

### Task 19: Complete verification and independent review

**Files:** `integration_test/app_workflows_test.dart`, `docs/verification/final-report.md`.
**Tests:** `integration_test/app_workflows_test.dart`.
**Interfaces:** Final report contains actual commands/results, screenshots, manifest hashes, review rulings and release dependencies.

- [ ] Investigate the owning source and predecessor interfaces; record current checkout and evidence.
- [ ] Add tests asserting: Synthetic end-to-end registrar/direction/supervision/admin journeys cover photo, visit, weekly race, import retry, access revocation and web/Android file retrieval.
- [ ] Run the narrow test file(s); confirm failure at the new assertion demonstrates missing behavior, not broken tooling.
- [ ] Run local SQL/security/concurrency suites, Dart/widget/integration tests, analyzer and web/Android debug builds. Independently review whole branch using the fixed model; investigate every failure and fix in-scope causes before final handoff.
- [ ] Run separately: `flutter analyze`, `flutter test`, `supabase test db`, `flutter build web`, `flutter build apk --debug`. Expect passing checks; investigate any failure before proceeding. Run platform/Storage integration cases against local services where unit checks cannot prove behavior.
- [ ] Self-review, commit owned changes, and complete the independent review/fix cycle from the runbook.

## Completion and implementation boundary

All 19 tasks must be checked in the plan-owned ledger with actual evidence. A successful unit suite does not prove Storage policy, OAuth console setup, Android file retrieval or SQL concurrency: report which local/device/manual scenarios ran and which release-only inputs remain. Missing toolchains are environmental blockers to resolve or report honestly, never a reason to claim build success. Production setup requires the user's accounts and release inputs after local deliverables are ready.

Self-review: all design sections map to Tasks 1–19; five review focus classes have assigned regression scenarios; interface names and SQL envelopes align. This document specifies the work and does not claim it has been implemented or tested.
