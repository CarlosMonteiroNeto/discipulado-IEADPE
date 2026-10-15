# IEADPE Convertidos Flutter Port Implementation Plan

> Superseded by [the Flutter + Firebase SDD plan](2026-10-14-ieadpe-flutter-firebase-sdd.md). The user selected Firebase and GPT-6.1 Sol / low for all SDD roles. Do not execute this historical Supabase plan.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Recreate the IEADPE Convertidos app as a responsive Flutter application for web and Android, preserving the confirmed Base44 workflows without migrating personal records.

**Architecture:** A Material 3 Flutter client uses feature modules, domain models, and repositories. Supabase Auth, Postgres with RLS, and private Storage provide shared identity and persistence. Every source-dependent business rule is verified against pasted Base44 files before it is encoded.

**Tech Stack:** Flutter/Dart, Material 3, Supabase Auth/Postgres/Storage, Flutter Router, XLSX import/export packages selected from current official package documentation during implementation.

**Spec:** `docs/superpowers/specs/2026-10-14-ieadpe-converts-flutter-design.md`

**Source available locally:** All 101 files visible in the Base44 code tree have been independently copied to `reference/base44`. `manifest.json` records paths, sizes, and hashes; all 179 internal imports resolve. Source-inspection steps below use these files and do not require user uploads.

## Global Constraints

- Flutter Material 3 app for web and Android.
- Use Supabase Auth, Postgres, and Storage; keep secrets out of source control.
- Keep UI, domain models, and persistence behind feature modules and repositories.
- Enforce verified user and congregation access using backend row-level security.
- Store convert photos in private Storage and use authorization-scoped access.
- Do not migrate, seed, export, upload, or embed any existing Base44 personal records.
- Do not claim exact parity for a behavior that has not been confirmed from source.
- Preserve responsive navigation, branded layout, and loading, empty, validation, permission-denied, and recoverable-error states.

## Review Focus

- A signed-in account with no `UserAccess` record must be sent to Register; an account with access can reach Home and Converts. (Task 3: auth-routing tests.)
- Admin and supervision roles must reach Admin, while ordinary users cannot use its routes or backend data. (Task 3 and Task 5: role-routing and authorization tests.)
- A convert with no previous visit, a recent visit, or a missing `last_visit_date` must be grouped consistently with verified urgency rules. (Task 6: urgency-boundary tests.)
- Concurrent or repeated visit/disciple actions must not silently lose event history or duplicate a state transition. (Task 6: event-write tests.)
- Empty, invalid, duplicate-ID, and malformed XLSX imports must report row-level errors and never replace existing records implicitly. (Task 8: import-validation tests.)

---

## File Map

- `pubspec.yaml`: Flutter app metadata and pinned dependencies.
- `lib/main.dart`: app bootstrap and Supabase initialization.
- `lib/app/app.dart`: theme, router, responsive scaffold, global feedback/error presentation.
- `lib/app/routes.dart`: route definitions and access guards.
- `lib/core/config/app_config.dart`: validated environment configuration.
- `lib/core/theme/app_theme.dart`: IEADPE palette, typography, surfaces, spacing, and controls.
- `lib/core/widgets/`: reusable loading, empty, error, confirmation, and responsive layout widgets.
- `lib/features/auth/`: sign-in, auth state, access resolution, and OAuth return handling.
- `lib/features/home/`: dashboard and weekly report.
- `lib/features/converts/`: model, repository, list/filter/urgency, form, details, photo, and event actions.
- `lib/features/congregations/`: model, repository, and admin management.
- `lib/features/access/`: role/access model, repository, and admin management.
- `lib/features/admin/`: summary, conversion report, event table, and tabs.
- `lib/features/backup/`: XLSX import/export and internal-ID merge.
- `lib/features/feedback/`: user feedback flow and admin review if source confirms it.
- `supabase/migrations/`: tables, indexes, functions, RLS, and Storage policies.
- `test/`: focused model, repository, route, and widget behavior tests.
- `integration_test/`: app-level navigation and form smoke tests.
- `README.md`, `.env.example`: setup and build instructions, with placeholder configuration only.

## Task 1: Create Flutter foundation and configuration

**Files:**
- Create: `pubspec.yaml`, `lib/main.dart`, `lib/app/app.dart`, `lib/app/routes.dart`, `lib/core/config/app_config.dart`, `lib/core/theme/app_theme.dart`, `.env.example`, `README.md`
- Test: `test/core/config/app_config_test.dart`, `test/app/routes_test.dart`

**Interfaces:**
- Produces `AppConfig.fromEnvironment({required String supabaseUrl, required String supabaseAnonKey})` with validation and `hasSupabaseConfig`.
- Produces app routes `/login`, `/register`, `/home`, `/converts`, `/admin`, `/oauth/callback`.

- [ ] **Step 1: Write configuration tests** proving empty or malformed Supabase values are rejected and valid HTTPS URL/key values are accepted.
- [ ] **Step 2: Run the config tests** and confirm they fail because `AppConfig` does not exist.
- [ ] **Step 3: Implement the Flutter shell and config** with responsive navigation, Material 3 theme, and no embedded secrets.
- [ ] **Step 4: Run focused tests and Flutter analysis**; expected: config and route tests pass, analyzer has no errors.
- [ ] **Step 5: Build web and Android targets**; expected: both builds complete with placeholder configuration.

## Task 2: Define domain entities and Supabase schema

**Files:**
- Create: `lib/features/converts/domain/convert.dart`, `lib/features/converts/domain/convert_event.dart`, `lib/features/congregations/domain/congregation.dart`, `lib/features/access/domain/user_access.dart`, `lib/features/feedback/domain/feedback_entry.dart`, `lib/features/home/domain/weekly_report.dart`, `supabase/migrations/0001_initial_schema.sql`
- Test: model serialization tests under each feature's `test/` folder; migration policy tests under `supabase/tests/`

**Interfaces:**
- Models provide `fromJson(Map<String, dynamic>)` and `toJson()` with explicit field mappings.
- Convert maps observed fields including congregation/photo/name/address/landmark/phone/age/gender/conversion date/worship type/visit count and discipleship state; remaining fields come from supplied schemas.
- ConvertEvent represents event type, convert ID, congregation, actor, event time, and source-confirmed metadata.

- [ ] **Step 1: Add model tests** for nullable fields, ISO dates, gender enum validation, event types, and unknown JSON fields.
- [ ] **Step 2: Run model tests** and confirm the new assertions fail before implementation.
- [ ] **Step 3: Implement model mapping and schema** for all six entities, timestamps, foreign keys, indexes, and non-destructive migration defaults.
- [ ] **Step 4: Add RLS policies and policy tests** for verified roles and congregation scope; do not grant broad access to satisfy a client filter.
- [ ] **Step 5: Run model and schema checks**; expected: serialization round-trips and policy cases pass, schema applies to an empty Supabase test project.

## Task 3: Implement sign-in and role-aware app shell

**Files:**
- Create: `lib/features/auth/data/auth_repository.dart`, `lib/features/auth/application/auth_controller.dart`, `lib/features/auth/presentation/login_page.dart`, `lib/features/auth/presentation/oauth_callback_page.dart`, `lib/app/access_guard.dart`
- Modify: `lib/app/app.dart`, `lib/app/routes.dart`
- Test: `test/features/auth/`, `test/app/access_guard_test.dart`

**Interfaces:**
- `AuthRepository.signInWithPassword(email, password)`, `signInWithGoogle()`, `signOut()`, `watchSession()`.
- `AccessSnapshot` contains `isAdmin`, `isSupervision`, `hasApplicationAccess`, and resolved congregation IDs.
- `AuthController` exposes loading/authenticated/unauthorized/error states.

- [ ] **Step 1: Write route and controller tests** for signed out, no access, ordinary access, admin, supervision, and sign-out.
- [ ] **Step 2: Run focused auth tests** and confirm each new route guard assertion fails before implementation.
- [ ] **Step 3: Implement Supabase auth and access resolution** using the exact Layout role strings and redirects; reconcile roles/scoping against pasted `UserAccessManager.jsx` before finalizing policies.
- [ ] **Step 4: Implement login and OAuth callback states** including provider setup errors and missing backend configuration.
- [ ] **Step 5: Run auth tests and analyzer**; expected: no-access users reach Register, authorized users reach allowed routes, and unauthorized Admin navigation is absent.

## Task 4: Build responsive layout and Home dashboard

**Files:**
- Create: `lib/core/widgets/app_scaffold.dart`, `lib/core/widgets/feedback_button.dart`, `lib/features/home/data/home_repository.dart`, `lib/features/home/application/home_controller.dart`, `lib/features/home/presentation/home_page.dart`, `lib/features/home/presentation/weekly_report_card.dart`
- Modify: `lib/app/app.dart`, `lib/core/theme/app_theme.dart`
- Test: `test/core/widgets/app_scaffold_test.dart`, `test/features/home/`

**Interfaces:**
- `HomeRepository.loadSummary()` returns total, urgent, in-discipleship, visited counts and weekly report values after source verification.
- Navigation items are derived from `AccessSnapshot` and current route.

- [ ] **Step 1: Add widget tests** for desktop navigation, mobile menu/bottom navigation, selected-route state, and role-dependent navigation.
- [ ] **Step 2: Implement shell and Home** using the navy-to-blue brand, church mark, summary cards, register/list/admin actions, and weekly report only as verified from `Home.jsx`/`WeeklyConversionReport.jsx`.
- [ ] **Step 3: Run widget tests** at phone and desktop sizes; expected: no overflow, all authorized links visible, and empty/error states render.

## Task 5: Implement congregation and user-access administration

**Files:**
- Create: `lib/features/congregations/data/congregation_repository.dart`, `lib/features/congregations/application/congregation_controller.dart`, `lib/features/congregations/presentation/congregation_manager.dart`, `lib/features/access/data/user_access_repository.dart`, `lib/features/access/application/user_access_controller.dart`, `lib/features/access/presentation/user_access_manager.dart`
- Test: `test/features/congregations/`, `test/features/access/`

**Interfaces:**
- `CongregationRepository.list/create/update/archive` and `UserAccessRepository.list/grant/update/revoke` are restricted by server policies.
- Access role values and congregation scoping are defined from source files, not guessed.

- [ ] **Step 1: Write repository/controller tests** for validation, duplicate access, role assignment, and inaccessible congregations.
- [ ] **Step 2: Implement congregation and access managers** matching the Admin tabs and source-verified permissions.
- [ ] **Step 3: Run focused feature tests**; expected: invalid or unauthorized changes are rejected and lists expose only permitted records.

## Task 6: Implement convert registration, list, details, and event tracking

**Files:**
- Create: `lib/features/converts/data/convert_repository.dart`, `lib/features/converts/data/convert_event_repository.dart`, `lib/features/converts/data/photo_storage.dart`, `lib/features/converts/application/convert_controller.dart`, `lib/features/converts/application/urgency_policy.dart`, `lib/features/converts/presentation/convert_list_page.dart`, `lib/features/converts/presentation/convert_card.dart`, `lib/features/converts/presentation/convert_form_page.dart`, `lib/features/converts/presentation/convert_detail_page.dart`
- Test: `test/features/converts/`

**Interfaces:**
- `ConvertRepository.search({query, congregationId, urgency})`, `save(Convert)`, `loadById(id)`.
- `UrgencyPolicy.classify({required DateTime? lastVisitDate, required DateTime now})` returns `urgent`, `attention`, or `upToDate` using thresholds verified from source.
- `ConvertEventRepository.record({convertId, type, occurredAt, actorId})` appends auditable events.

- [ ] **Step 1: Inspect the captured `Converts.jsx`, `Register.jsx`, `ConvertCard.jsx`, `ConvertForm.jsx`, `PhotoUpload.jsx`, entity schemas, and event-write code under `reference/base44`**; document exact required fields, card actions, event semantics, and urgency thresholds in the spec.
- [ ] **Step 2: Write tests** for form validation, search/filter, urgency boundaries, duplicate/retry event writes, and photo storage authorization.
- [ ] **Step 3: Implement form, list, detail, and event workflows** including congregation filter, required-field validation, private photo upload, visit/discipleship history, and WhatsApp deep link.
- [ ] **Step 4: Run feature tests and web/Android analysis**; expected: boundaries and event history are deterministic, and no record can be accessed outside verified policy scope.

## Task 7: Implement Admin summary, reports, and event table

**Files:**
- Create: `lib/features/admin/data/admin_repository.dart`, `lib/features/admin/application/admin_controller.dart`, `lib/features/admin/presentation/admin_page.dart`, `lib/features/admin/presentation/admin_summary.dart`, `lib/features/admin/presentation/conversion_report.dart`, `lib/features/admin/presentation/convert_events_table.dart`, `lib/features/admin/application/event_exporter.dart`
- Test: `test/features/admin/`

**Interfaces:**
- `AdminRepository.loadSummary()` and `loadEvents({startDate, endDate, congregationId, sortColumn, ascending})`.
- `EventExporter.exportXlsx(rows, columns)` exports exactly the currently filtered and sorted table.

- [ ] **Step 1: Inspect `Admin.jsx`, `ConversionReport.jsx`, and `ConvertEventsLog.jsx`** and record exact columns, sort types, date semantics, filters, and event labels.
- [ ] **Step 2: Write tests** for date inclusivity, congregation filter, stable sorting across text/date/number fields, and export row parity.
- [ ] **Step 3: Implement admin tabs** for Congregações, Acessos, Relatório, Eventos, and Backup entry; implement report and event table.
- [ ] **Step 4: Run admin tests**; expected: exported XLSX rows match visible table filters/order and private columns are excluded unless source-confirmed and authorized.

## Task 8: Implement backup import/export and feedback

**Files:**
- Create: `lib/features/backup/data/backup_repository.dart`, `lib/features/backup/application/backup_controller.dart`, `lib/features/backup/presentation/backup_manager.dart`, `lib/features/feedback/data/feedback_repository.dart`, `lib/features/feedback/presentation/feedback_form.dart`, `lib/features/feedback/presentation/feedback_manager.dart`
- Test: `test/features/backup/`, `test/features/feedback/`

**Interfaces:**
- `BackupRepository.exportConverts()` and `importConverts(file)` use stable `id_interno` and insert only unseen IDs unless source proves another explicit conflict flow.
- `FeedbackRepository.submit(FeedbackEntry)` and admin listing follow source-verified fields and permissions.

- [ ] **Step 1: Inspect `BackupManager.jsx`, `FeedbackManager.jsx`, and `FeedbackButton.jsx`** for columns, import rules, validation, and admin actions.
- [ ] **Step 2: Write tests** for empty file, malformed rows, duplicate internal IDs, partial valid imports, export ID stability, and feedback validation.
- [ ] **Step 3: Implement XLSX import/export and feedback** with preview/row-level errors before insertion and no implicit replace behavior.
- [ ] **Step 4: Run feature tests**; expected: only new IDs insert, invalid rows are reported, and feedback is accessible only per verified role rules.

## Task 9: End-to-end review and delivery setup

**Files:**
- Modify: `README.md`, `.env.example`, `integration_test/app_smoke_test.dart`
- Review: all files created in Tasks 1–8 and Supabase migrations.

- [ ] **Step 1: Run full Flutter analysis and all requested tests**; resolve in-scope failures before proceeding.
- [ ] **Step 2: Build web and Android release targets** using placeholder environment values; confirm both artifacts build without production credentials.
- [ ] **Step 3: Run app smoke flow** for login/register routing, convert registration with fake test data, list filtering, Admin tabs, and sign-out.
- [ ] **Step 4: Review RLS and Storage policies** against admin, supervision, ordinary user, and no-access cases; confirm no personal Base44 records or credentials are in the workspace.
- [ ] **Step 5: Document setup** for Supabase URL/key, Google OAuth redirects, migrations, web hosting, Android build, and the separately confirmed data-migration procedure.

## Plan self-review

- **Spec coverage:** tasks cover responsive shell, auth/roles, all six entities, registration/list/detail/event tracking, congregation/access management, Home/weekly report, Admin report/events/export, backup, feedback, private photos, RLS, and web/Android delivery. Unknown rules explicitly require source inspection before implementation.
- **Step granularity:** feature tasks write focused tests, implement one coherent module, and run its narrow check; end-to-end delivery has separate cross-platform checks.
- **Type consistency:** auth exposes `AccessSnapshot`; repository methods use typed model entities; admin event loader and exporter receive explicit range/filter/sort inputs; backup identity uses `id_interno`.
- **Review focus:** each listed failure mode is assigned to a task with focused tests.
- **Proportion:** nine tasks group independent deliverables while keeping the plan bounded by the app’s major feature modules.
