# IEADPE Flutter — Firebase Spark Design

> Historical: superseded by the accepted [Supabase Free design](../specs/2026-10-14-ieadpe-flutter-supabase-free-design.md) and [implementation plan](../plans/2026-10-14-ieadpe-flutter-supabase-free-sdd.md). Do not execute this baseline.

Status: historical, superseded baseline. This supersedes the Functions/Storage Firebase design and the earlier Supabase design. The user requested Firebase Spark only; free alternatives are being compared, not selected automatically. Implementation has not started.

## Intent and binding constraints

Recreate the captured IEADPE app for Flutter web and Android, delivering the workflows supported by Firebase Spark first. Preserve the 101 source files in `reference/base44` unchanged; use synthetic fixtures. Source facts and business rules below come from those files, not inferred production database policies.

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

## Scope

Include registration/edit, congregation-scoped convert lists/cards, visits/discipleship/history, Home, weekly zero-conversion reporting, congregation and access management, conversion reports, event tables, local XLSX import/export, and feedback. Keep the five source Admin tabs; open feedback management through an Admin action.

Defer shared photo uploads/storage, background/scheduled processing, server-only secret integrations, pre-registration email invitations and managed server-side backups. Use avatar placeholders; do not put photo Base64 or binary blobs into Firestore to work around the Storage restriction. Source image paths remain reference evidence only. All spreadsheet processing happens locally and needs no uploaded file bucket. Binary `.xls` is deferred; support the source's `.xlsx` export format.

Grant recipients must sign in and verify their email once before appearing in the administrator's user directory. Admin can assign source-supported roles by selecting that registered identity. This replaces the original unrestricted email staging with a Spark-compatible identity flow; do not add custom-claim issuance or an Admin SDK server disguised as a client feature.

## Source parity

- Navy `#1e3a5f` → blue `#2563eb`, church branding, desktop navigation, mobile drawer and bottom navigation; breakpoint 768 logical pixels; main width 896, form width 512.
- Required registration fields: name, landmark, gender, conversion date and worship type. Congregation, phone, address and age are optional; highlight missing congregation/phone. Accept age zero through 150; reject future dates. Preserve all 64 exact pt-BR worship labels in `src/utils/worshipTypes.js`.
- No-access signed-in users can register and submit feedback, but cannot browse converts. Direction accesses assigned congregations. Supervision and admin access all congregations. Admin is bootstrapped out of band, never self-selected.
- Needs visit after 1 day before the first visit, 7 days after a previous visit outside discipleship, 30 days in discipleship. Urgent = due and not in discipleship; up to date = not due and in discipleship; otherwise attention. Overdue discipleship is attention.
- Start/restart sets discipleship start to today and adds `discipleship_started`; stop adds no new event type. Visit increments count and adds `visit`, only while due. Completion requires 90 days from a known start and adds `discipleship_completed`. Deviation requires at least three visits and adds `deviated`. Terminal/deleted records reject further lifecycle actions and disappear from the active list.
- Search names case-insensitively; source status/congregation filters; names containing `sede` first, then pt-BR alphabetic ordering; unassigned converts last. Home/Admin totals include terminal records, while the active list excludes them.
- Weekly interval: Monday–Sunday ending at the most recent Sunday; show confirmation after Sunday 20:00. Direction confirms their own eligible zero-conversion week; supervision sees global confirmed/waiting status. A positive conversion count invalidates a zero confirmation.
- Event dates filter inclusively; Apply controls visibility; columns toggle pt-BR sorting; XLSX exports exactly the complete filtered/sorted result. Do not retain the source's silent 1,000-event cap.
- Feedback states: pending/read/resolved; actor fields come from the authenticated identity and Rules validation.
- Soft-delete converts and retain event snapshots. Archive congregations rather than physically deleting them, preserving referenced records and access. This is an explicit safety change from source hard deletion.

## Spark limits and operating model

Current Firestore Standard no-cost allocation: 1 GiB stored, 50,000 document reads/day, 20,000 writes/day, 20,000 deletes/day and 10 GiB outbound/month. Classic Hosting: 10 GB stored and 360 MB transfer/day. These are provider quotas, not an app-specific guaranteed capacity. Rules lookups, paged reads and listeners also consume reads. A free-tier allowance on Blaze does not make a product available on Spark.

Use explicit refresh/invalidation after successful writes and only necessary identity/access listeners. Fetch a 100-document page at a time and reuse an already loaded authorized snapshot for dashboard, filters and exports. Large exports/imports show progress and complete pagination rather than presenting a truncated success. Resource-exhausted/unavailable errors preserve drafts and offer retry, never silently drop writes or activate billing. Persistent sensitive disk cache is disabled initially; clear in-memory data on sign-out/revocation.

## Data and authorization design

No Functions or deployable backend code exists in this version. TypeScript/Node tooling is used only for local Rules tests and synthetic emulator setup. Flutter repositories issue transactions directly; Rules inspect old state and `getAfter()` to require matching writes. Never ship service-account credentials or use the Admin SDK inside Flutter.

| Location | Contract |
|---|---|
| `users/{uid}` | Minimal self-owned directory profile: Auth-matching verified email, display name, createdAt. Only privileged users can query the directory; users may get their own profile. No role fields here. |
| `administrators/{uid}` | Out-of-band bootstrap marker, client writes always denied. Initial production UID is configured manually through a trusted Firebase console/admin process; never by public sign-up. |
| `access/{uid}` | `isSupervision`, unique `congregationIds`, update actor/time. A user can get their own record; admin/supervision can manage grants, but cannot write administrator markers. Missing record = registration-only access. UI expands this profile into the two source role labels. |
| `congregations/{id}` | Name, `isArchived`, timestamps. Signed-in users read names; global roles create/rename/archive. Physical deletes denied in phase one. |
| `converts/{internalId}` | Source fields mapped to camelCase, explicit false/zero defaults, null photo, Auth-validated createdByUid, timestamps, nullable deletedAt and lastMutation metadata. Document ID is the stable `internalId`; IDs must match `[A-Za-z0-9_-]{1,128}`. New records use a client-generated Firestore ID fixed before retries; source backup IDs are retained. |
| `convertEvents/{convertId_operationId}` | Immutable event snapshot: actor UID/email, convert name/congregation, one of four source event types, civil eventDate and server occurredAt. It must match a permitted same-commit convert transition. No standalone fabricated event writes. |
| `users/{uid}/receipts/{operationId}` | Minimal own-readable immutable receipt: command kind, convert/document ID, optional event ID, payload fingerprint and server time. No personal record payload. Allows a registrar to confirm/retry a submission without reading converts. Rules bind the receipt to the same-commit mutation; replay cannot authorize a different write. |
| `congregations/{id}/weeks/{weekStart}` | Shared conflict/validation document: nondeleted conversion count, version, last referenced mutation and optional zero-confirmation actor/time/version. A confirmation is valid only when count=0 and confirmedVersion=current version. Conversion create/move/import/delete updates affected week counts atomically. Keep zero-count documents; do not depend on a delete trigger. |
| `feedback/{id}` | Message, authenticated actor UID/email/name, pending/read/resolved and timestamps. Authenticated users create pending feedback; global roles read/update status; submitters cannot impersonate another identity or browse global messages. |
| `settings/business` | Trusted calendar offset/configuration and source worship catalog; clients read, cannot write. Bootstrap through emulator fixtures or trusted console. No deployable server required. |

Global roles can read all nondeleted converts including unassigned ones and get tombstones by ID for import deduplication; normal lists exclude tombstones. Direction queries only assigned congregation IDs; unauthorized broad queries must fail in Rules. Registration-only creation never grants subsequent read/edit permission. Access denial while a page is loading cancels that scope's results.

Google OAuth is the primary sign-in path on web and Android. Configure Firebase Google provider, authorized web domains and Android SHA fingerprints; use platform-appropriate popup/redirect/native flows and preserve Firebase Auth handler routes. Treat provider cancellation as a recoverable action, not a generic crash. Email/password remains secondary; this preference does not add Apple, Facebook or other OAuth providers. Do not merge two same-email identities silently; handle linking/account-conflict errors explicitly.

Date-only strings have a canonical timestamp companion where Rules arithmetic requires one; Rules must validate the string/timestamp relationship, not trust a forged elapsed-day count. Rules use `request.time` and a trusted UTC−03:00 business offset (current Sao Paulo civil time), with one centralized configuration for future timezone-policy changes. Dart uses `America/Sao_Paulo`; golden tests ensure equivalent current calendar decisions. Document this offset dependency explicitly rather than claiming Rules execute an IANA timezone library.

For lifecycle commands, Rules require the exact allowed field diff, validated actor, server timestamp, immutable create fields, legal old→new transition, matching event and receipt. For create/update/move/delete, Rules also validate the related week count/version changes. Counter writes must point back to the actual same-commit convert mutation; clients cannot write arbitrary counts. Import is a separate globally authorized initial-state path, not a way for registrars to create pre-completed records.

Transactions must remain below Rules document access limits: 10 per operation and 20 per atomic request. Prove the worst-case congregation/week move, lifecycle transition, receipt and confirmation paths in the emulator before building dependent UI. One import row per transaction, sequentially; do not copy the old 25-row Functions chunk design into Spark. If an invariant cannot be enforced within the limits, narrow/defer that operation and record the limitation; never replace enforcement with a client-only check.

## Spreadsheet and date compatibility

Retain sheet `Convertidos` and the original 14 Portuguese columns from `BackupManager.jsx`. V2 can add `data_ultima_visita`, `data_inicio_discipulado`, `visitado_ao_menos_uma_vez`, plus `_metadata.formatVersion=2`. Old exports remain accepted. Missing visit date falls back to conversion date; unknown discipleship start stays null, so completion cannot bypass the 90-day rule. XLSX contains records, not photos.

Preview before writing; validate dates, required fields, exact worship/gender/boolean labels, age, visit count and internal IDs. Unknown congregation becomes null with a warning; ambiguous names require correction. Missing/invalid IDs are errors. Existing/tombstoned IDs and within-file duplicates are skipped without overwriting. Store stable operation IDs for retry and use a fixed ID for each imported row.

Limit input to 10 MiB compressed, 50 MiB expanded and 10,000 rows; reject formula cells and binary `.xls`. Encode user text as spreadsheet text. File parsing/saving uses local bytes on web/Android; no bucket/Functions is involved.

## Packages, validation and release

Flutter packages: `firebase_core`, `firebase_auth`, `cloud_firestore`, `flutter_riverpod`, `go_router`, `intl`, `timezone`, `excel`, `archive`, `file_picker`, `file_saver`, `url_launcher`, `crypto`. Resolve stable compatible versions once and commit locks. No `cloud_functions`, `firebase_storage`, image-upload pipeline or second backend dependency in Spark phase one.

Node test tooling: Firebase CLI/emulators, Firebase JS SDK and `@firebase/rules-unit-testing` with a selected test runner. No Functions package/deployment target. Unit tests cover civil dates/statuses/backup; emulator tests send malicious writes as well as valid SDK transactions; widgets cover 360/768/1280 widths and 200% text. Verify analyzer, Rules tests, web release, Android build and an actual available Android runtime. Mark any missing device/SDK validation honestly.

After local acceptance, prepare classic Hosting configuration preserving Firebase Auth reserved routes, Google domain/SHA configuration, manual admin/bootstrap checklist and measured quota estimates. Do not create a paid service to satisfy a missing test. Keep photos/background jobs/pre-user invitations and cross-provider integration in a deferred backlog.

## References and alternatives

- [Firebase pricing and Spark product availability](https://firebase.google.com/pricing)
- [Firestore quotas and Rules call limits](https://firebase.google.com/docs/firestore/quotas)
- [Rules getAfter and atomic-write validation](https://firebase.google.com/docs/firestore/security/rules-conditions)
- [Supabase Free limits](https://supabase.com/pricing): an alternative if photos/server logic become required now, not an approved backend change.
- [Supabase Firebase Auth integration](https://supabase.com/docs/guides/auth/third-party/firebase-auth): possible hybrid, but token claims and cross-provider permissions require explicit design; it is not assumed to run Firebase Functions on Spark.
