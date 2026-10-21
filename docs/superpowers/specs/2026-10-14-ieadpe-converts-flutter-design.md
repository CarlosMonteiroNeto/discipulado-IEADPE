# IEADPE Convertidos — Flutter Design

<!-- canonical-document-authority -->
> **Historical planning reference.** The [current spec](2026-10-20-ministry-corrective-release-design.md), [current plan](../plans/2026-10-20-ministry-corrective-release-plan.md) and [JSON mirror](../plans/2026-10-20-ministry-corrective-release-plan.json) govern current requirements, status, task order and authorization. The original body preserves its dated design, checklists and execution provenance; reconcile useful obligations through the current task owners before future work.

> Superseded by [the Flutter + Firebase design](2026-10-14-ieadpe-flutter-firebase-design.md). Retained as historical planning evidence only.

## Status

Revised after inspecting the more complete Base44 profile and independently capturing all 101 files shown in its code tree. The original source is preserved in `reference/base44`; capture checks and SHA-256 hashes are recorded in `reference/base44/manifest.json`. No Flutter application code has been created yet.

## Understanding and evidence

The goal is to recreate the current IEADPE Convertidos app as a Flutter application for web and Android in this workspace. The workspace is empty, is not a Git repository, and has Flutter 3.47.2 installed. The newer Base44 profile is a React/Vite JavaScript app, not React Native or TypeScript; its visible source tree includes `src/pages`, `src/components`, and `base44/entities`.

The read-only source tree exposes these entities: `Congregation`, `Convert`, `ConvertEvent`, `Feedback`, `UserAccess`, and `WeeklyReport`. The supplied `Layout.jsx` shows the current navigation and access rules: signed-in users without access are redirected to Register; any `UserAccess` entry grants Home and Converts; admins and users with the exact role `Membro da supervisão das campanhas` can access Admin. The layout uses a navy-to-blue header, church branding, responsive desktop links, a mobile sheet and bottom navigation, and a feedback button.

The newer preview contains 50 convert records, so the earlier profile’s empty-database assumption was wrong. The preview reveals private convert names, phone numbers, addresses, and reference points. This design excludes copying those personal records until the user confirms the exact fields and destination at migration time. Aggregate evidence from Admin shows 50 total converts, 0 in discipleship, and 3 visited. Do not include copied records or contact details in source files, logs, examples, or verification artifacts.

Observed flows and features:

- Pages: Home, Converts, Register, Admin, plus an OAuth consent route.
- Registration: optional photo; congregation; required name, landmark, gender, conversion date, and worship type; address, phone, and age; cancel and register actions.
- Converts: search and congregation filter; urgency categories `Visita Urgente`, `Atenção`, and `Em Dia`; convert cards expose visit and discipleship checkboxes and a WhatsApp action.
- Admin: tabs for Congregações, Acessos, Relatório, Eventos, and Backup; aggregate counts; congregation management; access management; conversion reporting; event log; backup/import.
- Event log: Base44 chat history states that event types include visit, discipleship started/completed, and diverted, and that the table supports a date range, congregation filter, column sorting, and XLSX export.
- Backup: Base44 chat history states that export downloads converts as XLSX with an `id_interno`, and import merges only unseen IDs.
- The app preview is populated, but preview surface counts and lists can vary by route/environment. Validate aggregate consistency without opening or reproducing personal records.

The complete visible source is now available locally for direct inspection. Base44 chat history includes a historical `handleConfirmReplace is not defined` report; a later Base44 response says the obsolete dialog was removed. Treat that as historical evidence and verify current behavior from the captured source.

### Rules confirmed from captured source

- `UserAccess` supports exactly `Membro da direção da campanha` and `Membro da supervisão das campanhas`. Direction members are associated with congregation IDs; supervision has full congregation visibility. Admin is a separate Auth user role.
- Visit timing falls back to conversion date when the last visit date is absent. The follow-up thresholds are 1 day before the first visit, 7 days after a prior visit outside discipleship, and 30 days during discipleship. Reproduce the exact color mapping from `Converts.jsx` and `ConvertCard.jsx` rather than equating every elapsed threshold with the same status.
- Discipleship completion becomes available after 90 days from its start. The diverted checkbox becomes available after at least three visits and is hidden for completed discipleship.
- Visit actions increment `visit_count`, set the last-visit date, and append a `ConvertEvent`; discipleship started/completed and diverted actions append their respective events. Completed or diverted converts are excluded from the active list.
- Weekly reporting weeks run Monday through Sunday. Registering a conversion resolves the same congregation's matching no-conversions weekly report.
- Before porting write operations, review the source's separately issued updates/events and preserve the intended workflow with an atomic backend operation to avoid partial or duplicate updates.

## Recommended approach

Build a responsive Flutter Material 3 app for web and Android with Supabase Auth, Postgres, and Storage as the replacement backend, as previously approved. Use feature-based Dart modules and repositories to isolate presentation from persistence. Mirror observable routes, roles, workflows, and visual identity; record unknown behavior rather than inventing parity claims.

The app should include aggregate/schema setup and demo-safe empty states, but it must not seed, export, upload, or otherwise transfer the 50 existing Base44 personal records as part of this implementation. Keep the source and destination systems separate until the user authorizes a specific set of personal fields for a named destination.

## Product scope

### Initial release

- Flutter web and Android app shell with responsive navigation and branded layout.
- Email/password and Google authentication, with provider setup documented as an environment dependency.
- Role/access-aware navigation for admin, supervision, and registered users.
- Home dashboard, including totals and weekly-report presentation where source behavior can be recovered.
- Convert registration, detail/edit, search, congregation filter, urgency grouping, photo upload, visit tracking, discipleship tracking, and WhatsApp action.
- Congregation CRUD and user-access management.
- Admin summary, conversion report, event history with date range/congregation filtering/sorting/XLSX export, and backup import/export with stable internal IDs.
- Feedback flow and OAuth consent route where applicable.
- Loading, empty, validation, permission-denied, and recoverable error states.
- Supabase schema, row-level security, and private photo storage, with no personal records migrated.

### Explicitly unresolved

- Complete parity review of Home/weekly statistics and final color mapping, using the local source.
- Exact edit/delete permissions, event creation semantics, and whether checkboxes append events, update fields, or both.
- Exact feedback submission destination, validation, and admin workflow.
- Exact backup XLSX columns and import conflict behavior beyond the described `id_interno` merge.
- Exact colors, type scale, icons, spacing, and responsive breakpoints from source/theme files.
- OAuth provider configuration and production Supabase project credentials.
- Whether the user wants the existing Base44 convert data copied to a new backend. That requires a separate action-time confirmation naming fields and destination.

## Data and access design

Map the six discovered Base44 entities to Postgres tables with stable IDs and timestamps. Preserve observed business fields and event semantics after source inspection. Use Supabase Auth for identities, a role/access relation for authorization, and RLS for all data access. Store uploaded convert photos in a private Storage bucket and issue authorization-scoped URLs. Never rely on client-only filters for access control.

The Layout code establishes exact role strings for Admin access (`admin`) and supervision (`Membro da supervisão das campanhas`), and defines ordinary app access as admin or at least one `UserAccess` record. The remaining role and congregation-scope rules must be read from the current manager/source files before policy implementation. Avoid hard-coding assumptions about those policies.

## Architecture

- Flutter Material 3; responsive navigation and routes for web and Android.
- Feature modules for auth, home, converts, congregations, user access, reporting/events, backup, and feedback.
- Domain models and repositories between UI and Supabase.
- Environment/build-time Supabase URL and anon key; no secrets committed.
- Private Storage and RLS policies matching verified access rules.
- XLSX import/export isolated behind backup/report services.

## Acceptance criteria

- The project builds for Flutter web and Android.
- The app reproduces the observed routes and responsive branded layout.
- Registration validates required fields and associates a congregation; administrators can manage congregations and user access according to source-verified rules.
- Authorized users can search/filter converts, view detail, log visit/disciple progress, and see urgency categories based on verified business rules.
- Admin users can use summary, report, event history, and backup functions with verified date/filter/sort/export/merge behavior.
- RLS and Storage rules prevent unauthorized data access.
- The app starts in a useful configuration without production credentials and clearly reports that authenticated backend features need Supabase setup.
- No convert personal records are migrated or embedded in the deliverable without separate explicit data-and-destination authorization.
- Web and Android builds are verified; the review records unresolved source-dependent behavior and setup dependencies.

## Risks and dependencies

- Source capture is complete for all 101 files visible in the Base44 code tree. Browser clipboard access was successfully used without modifying the source app. Remaining behavior investigation can use the local files without requesting user uploads.
- The Base44 project currently contains personal convert records. Transferring names, phones, addresses, photos, or other private fields requires specific confirmation for the selected fields and destination.
- Supabase project credentials and Google provider setup are required for production sign-in and shared data; code can be prepared without committing credentials.
- Workspace has no existing app code, repository history, or tests to preserve.

## Review checklist

- Confirm the expanded feature scope from the newer profile.
- Confirm the approved Supabase replacement backend and role assumptions.
- Use the captured source files from `reference/base44/src` and `reference/base44/base44/entities` for exact conversion and track any behavior changes explicitly.
- At migration time, name the personal fields and destination if the 50 existing convert records should be transferred.
- Identify additional follow-up, scheduling, or reporting behavior that source files do not specify.
