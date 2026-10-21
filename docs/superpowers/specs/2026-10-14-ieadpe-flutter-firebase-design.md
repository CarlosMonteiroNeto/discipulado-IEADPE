# IEADPE Converts — Flutter and Firebase Design

<!-- canonical-document-authority -->
> **Historical planning reference.** The [current spec](2026-10-20-ministry-corrective-release-design.md), [current plan](../plans/2026-10-20-ministry-corrective-release-plan.md) and [JSON mirror](../plans/2026-10-20-ministry-corrective-release-plan.json) govern current requirements, status, task order and authorization. The original body preserves its dated design, checklists and execution provenance; reconcile useful obligations through the current task owners before future work.

> Historical design requiring paid Firebase services. Superseded by [the Spark-only design](2026-10-14-ieadpe-flutter-spark-design.md). Do not implement Functions/Storage from this document under the current Spark-only constraint.

Status: proposed implementation baseline, prepared for review. Supersedes the earlier Supabase design. Implementation has not started.

## 1. Intent and evidence

Recreate IEADPE Convertidos as one Flutter application for Android and web, preserving the source app's workflows and visual identity. Firebase replaces Base44. Implementation will use Codex Subagent-Driven Development (SDD); every implementer, reviewer, fixer, and final reviewer uses `gpt-6.1-sol` with `low` effort. Communication, code identifiers/comments, briefs, reports, and documentation are English; visible application text is pt-BR.

The workspace currently contains documentation and the captured React source, not a Flutter project or Git repository. Installed Flutter is 3.47.2 / Dart 3.13.2; Node, npm, Firebase CLI, and Java are discoverable. Compatibility and Android SDK/emulator availability must be checked at implementation preflight, not assumed from command availability.

Source baseline: `reference/base44/manifest.json` records 101 captured files and their hashes. All 179 internal imports resolved during capture. Treat `reference/base44` as immutable evidence. Six business entities exist: Congregation, Convert, ConvertEvent, UserAccess, WeeklyReport, Feedback. The source database contains personal records; use synthetic fixtures for development. Copying product code does not constitute an export of those records.

## 2. Binding constraints

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

## 3. Architecture decisions

Use Flutter/Dart for all product screens; no React WebView or embedded second UI. Riverpod provides injected repositories and state; go_router provides guarded routes; intl and Flutter localization provide pt-BR dates/copy. Domain models and policies are plain Dart. Keep feature folders small; avoid generated model/DI boilerplate initially.

Use Firestore for persistence and authorized reads. Use TypeScript Cloud Functions, with the supported Node LTS runtime selected and locked at preflight, for commands that validate access, modify multiple documents, or generate authoritative actor/date fields. Callable functions integrate Firebase authentication; Admin SDK calls still need explicit authorization because they bypass client Rules. Never accept actor UID/email, effective roles, visit counts, or timestamps from an untrusted caller as authoritative.

Photo reads use authenticated Storage SDK byte access governed by Rules. Persist storage paths, not public download-token URLs. Use private upload drafts with server-owned metadata and link them to a convert during a validated command. Browser code must not import `dart:io`; file selection/saving has a web/Android adapter.

Use Firebase Emulator Suite for Auth, Firestore, Functions, and Storage. Default local project ID: `demo-ieadpe-converts`; no accidental fallback to production when an emulator is unavailable. Production Firebase project IDs, region, Android application ID, signing identity, and OAuth registrations remain deployment inputs. Use `southamerica-east1` as a proposed colocated Functions/Firestore region only after checking project availability/location constraints. Firebase setup configuration is client configuration; service-account credentials must never enter Flutter or the repository.

Keep reads scoped: global access can read all nondeleted converts; direction members query each allowed congregation and merge authorized results. Never fetch all converts and filter unauthorized records afterward. Fetch in pages of 100 until the requested snapshot is complete; expose loading/progress rather than silently showing a partial dashboard/export. Do not copy the source event table's silent 1,000-event limit. Snapshot filtering/search is acceptable for the initial small deployment; isolate it behind repositories for later server search without changing UI contracts.

## 4. Source parity and explicit corrections

| Area | Evidence | Required behavior |
|---|---|---|
| Shell | `src/Layout.jsx` | Navy `#1e3a5f` to blue `#2563eb`; church branding; desktop navigation, mobile menu and bottom navigation; feedback action. |
| Register | `src/pages/Register.jsx`, `components/converts/ConvertForm.jsx` | Required: trimmed name, landmark, gender, conversion date, worship type. Congregation, phone, address, age, photo optional. Age 0–150, future conversion date rejected. Preserve all 64 exact worship labels from `src/utils/worshipTypes.js`. |
| Photos | `components/converts/PhotoUpload.jsx` | Center-crop to 192×192 JPEG. The new client rejects unsupported/oversized input; encoded upload maximum is 5 MiB. No arbitrary external URL fetching. |
| Access | `Layout.jsx`, `pages/Home.jsx`, `UserAccessManager.jsx` | Admin and supervision have global scope; direction members have assigned congregations; a signed-in user with no grants can register but cannot list converts. |
| Home | `pages/Home.jsx` | Authorized total, urgent, and in-discipleship counts; latest five conversions from last seven days; quick actions; weekly no-conversion reports. Counts include completed/deviated records, while the active list excludes them. Deleted records are excluded everywhere except audit history. |
| List | `pages/Converts.jsx`, `ConvertCard.jsx` | Case-insensitive name search; status/congregation filters; congregation ordering with names containing `sede` first, then pt-BR alphabetic order; records without a congregation last. Cards show contact/location/date/worship data, photo zoom, edit/delete and lifecycle actions. |
| Conversion report | `admin/ConversionReport.jsx` | Inclusive optional date boundaries; group by worship type, descending totals; chart and XLSX with `Tipo de Culto`, `Conversões`. |
| Event log | `admin/ConvertEventsLog.jsx` | Empty until filters are applied; inclusive dates; congregation filter; toggled column sorting with pt-BR text comparison; export exactly the complete filtered/sorted table. |
| Backup | `admin/BackupManager.jsx` | XLSX insert-only merge by stable `id_interno`; never overwrite an existing internal ID. |
| Feedback | `FeedbackButton.jsx`, `admin/FeedbackManager.jsx` | Submit trimmed message; pending/read/resolved workflow. Keep five primary Admin tabs; expose the existing but previously unmounted manager through an Admin feedback action. |

The conversion deliberately corrects these source issues:

1. Replace client-only authorization and broad entity fetches with enforced scope.
2. Replace separately issued record/event writes with an atomic command and deduplication key.
3. Preserve imported internal IDs so retrying an import does not create duplicate records.
4. Use civil dates and a fixed business timezone instead of inconsistent browser UTC/local parsing.
5. Serialize conversion creation and weekly no-conversion confirmation against the same week counter.
6. Soft-delete converts (`deletedAt`) while retaining event history; block deletion of a congregation referenced by records or active grants. Do not orphan existing records.
7. Show feedback management through an existing Admin action rather than leaving its component unreachable.

Base44's `OAuthConsent.jsx` is a platform-specific entity/tool consent screen, not a convert workflow. Replace platform auth with Firebase email/password and Google sign-in, verification and password recovery. Do not port Base44 SDK/tool consent. Firebase's hosted OAuth handler must retain its reserved routing.

## 5. Lifecycle and calendar contract

`needsVisit` uses the last visit date, falling back to conversion date:

- Never visited: elapsed civil days >= 1.
- Previously visited, not in discipleship: elapsed days >= 7.
- In discipleship: elapsed days >= 30.

Status is `urgent`/`Visita Urgente` when needsVisit and not in discipleship; `upToDate`/`Em dia` when not needsVisit and in discipleship; otherwise `attention`/`Atenção`. In-discipleship overdue records are attention, not urgent.

Starting discipleship sets start date to today and appends `discipleship_started`; turning it off changes state without inventing a new event type. Starting again resets its start date. A visit increments the counter, sets visited/date, and appends `visit`; it is accepted only while a visit is due. Completion requires active discipleship and at least 90 days since a valid start; it appends `discipleship_completed`. Marking deviated requires at least three visits and neither completed nor deviated; it appends `deviated`. Terminal/deleted converts reject further lifecycle changes. Both terminal states are removed from the active list.

The reporting interval is the Monday–Sunday ending on the most recent Sunday, including today if Sunday. The confirmation becomes available Sunday at 20:00 in the business timezone; before that time on Sunday it is hidden. A direction member can confirm only their own zero-conversion congregations. Admin/supervision see confirmed/waiting summaries for all zero-conversion congregations. Creating/importing/moving a conversion into that week automatically resolves the matching no-conversion report.

## 6. Firestore and Storage contract

Use camelCase in Firebase/Dart/TypeScript; the XLSX adapter owns the legacy Portuguese column mapping. `createdAt`, `updatedAt`, `occurredAt`, `deletedAt`, and expirations are server timestamps. Business dates remain strings; optional booleans/counts have explicit false/zero defaults. All documents carry `schemaVersion: 1` initially.

| Collection | Identity and fields |
|---|---|
| `congregations/{id}` | `name`, timestamps, server-only `recordRefCount` (including soft-deleted converts) and `grantRefCount` (active grants). Every reference change touches these counters in its transaction; deletion requires both zero. Source name retained; no personal source data seeded. |
| `converts/{id}` | UUID document ID; stable `internalId`; `congregationId?`, `photoId?`, `name`, `address?`, `landmark`, `phone?`, `age?`, `gender` male/female, `conversionDate`, `worshipType`, `lastVisitDate`, `wasVisitedOnce`, `visitCount`, `isInDiscipleship`, `discipleshipStartDate?`, `isDiscipleshipCompleted`, `isDeviated`, `createdByUid`, timestamps and `deletedAt?`. |
| `convertEvents/{id}` | Same transaction as transition: convert ID, name/congregation snapshots, one of the four source event types, business `eventDate`, server `occurredAt`, server actor UID/email, `operationId`. Immutable to clients; retained after convert soft deletion. |
| `accessGrants/{id}` | Deterministic hash of normalized email + role + congregation; source role label, `emailNormalized`, `congregationId?`, `boundUid?`. Direction requires a congregation; supervision requires null. Admin is not a grantable role in this form. |
| `accessProfiles/{uid}` | Server-maintained effective access: `globalRole` registrar/direction/supervision/admin, congregation IDs and version. Self-readable; never client-writable. Grants may be staged before a user exists. Bind an unbound email grant only to a matching verified Firebase identity. Grant/revoke immediately rebuilds the bound UID's profile atomically. |
| `adminPrincipals/{uid}` | Server-only allowlist for initial/admin identity; never granted from a client or ordinary access-manager command. Bootstrap tool requires an explicit target project and existing UID; emulator fixtures are separate. |
| `weeklyReports/{congregationId_weekStart}` | Deterministic ID; congregation, Monday string, verified actor UID/email/name and server timestamp. |
| `congregationWeeks/{congregationId_weekStart}` | Internal count of nondeleted conversions in that week. Creation, move, import and deletion update it transactionally. Confirmation reads the same counter, preventing races. |
| `feedback/{id}` | Message, actor UID/email/display name derived from Auth, pending/read/resolved, timestamps. Submitters cannot set status or browse messages. Admin/supervision manage it. |
| `operations/{uid_operationId}` | Server-only command deduplication result and canonical payload hash; reused ID + changed payload is rejected. |
| `internalIds/{hash}` | Server-only unique internal-ID reservation pointing to a convert. Prevents concurrent/repeated backup imports. |
| `photoAssets/{id}` | Server-owned draft owner UID, expiry, storage path, optional linked convert ID and state. Draft owner may upload/read while pending; attached photo is readable only through convert authorization. |

Storage path: `convert-photos/{photoId}.jpg`; create-only draft upload, JPEG MIME and size limits, no client overwrite after attachment. Rules consult asset metadata and linked convert scope. Registration-only users may upload their own draft and submit it, but linking a photo does not grant them record-reading access. `PhotoRepository` reads authenticated bytes; no persistent public URL or Base44 photo URL is fetched.

Commands share `{operationId, payload}` and return typed receipt/results. Fixed names: `resolveMyAccess`, `createConvert`, `updateConvert`, `softDeleteConvert`, `recordConvertAction`, `saveCongregation`, `deleteCongregation`, `saveAccessGrant`, `revokeAccessGrant`, `confirmNoConversions`, `createPhotoDraft`, `submitFeedback`, `setFeedbackStatus`, `importBackupChunk`. Lifecycle actions: `visit`, `startDiscipleship`, `stopDiscipleship`, `completeDiscipleship`, `markDeviated`.

All command authorization uses the effective profile inside the transaction where applicable, so revocation races conflict/retry. Caller-visible errors use stable English codes mapped to pt-BR UI messages. A denied/missing access snapshot fails closed; do not keep another user's cached records after sign-out or access revocation. Sensitive persistent disk caching is disabled initially; writes require connectivity and never claim success while offline.

## 7. Authorization matrix

| Action | Signed out | Signed-in registrar | Direction | Supervision/admin |
|---|---|---|---|---|
| Congregation names, registration | Denied | Read names/create validated convert | Same | Same |
| Convert list/detail/photos/Home | Denied | Denied after submission | Assigned congregations only | Global |
| Edit/lifecycle/soft delete | Denied | Denied | Assigned congregations only | Global |
| Weekly zero confirmation | Denied | Denied | Own congregation, eligible zero week | Overview; backend allows authorized administrative confirmation |
| Congregation/access management, reports/events/backup, feedback management | Denied | Denied | Denied | Allowed |
| Submit feedback | Denied | Allowed | Allowed | Allowed |
| Grant admin or change own privileges directly | Denied | Denied | Denied | Denied through app commands |

Rules deny all direct client business writes. Callable functions validate the same matrix independently. Read queries must fit Rules; Rules do not filter unsafe query results. Admin SDK access is not evidence of authorization.

## 8. Backup contract

Retain the original sheet `Convertidos` and columns: `id_interno`, `nome`, `congregacao`, `endereco`, `ponto_referencia`, `telefone`, `idade`, `genero`, `data_conversao`, `tipo_culto`, `visitas`, `em_discipulado`, `discipulado_concluido`, `se_desviou`. Preserve pt-BR values (`Masculino`, `Feminino`, `Sim`, `Não`).

New exports add `data_ultima_visita`, `data_inicio_discipulado`, `visitado_ao_menos_uma_vez` and a `_metadata` sheet with `formatVersion: 2`. Accept original and v2 XLSX. Missing original visit date falls back to conversion date; missing discipleship start remains unknown and cannot bypass the 90-day completion rule. Preserve age zero. Photos are not embedded in XLSX, matching the original scope. UI/help must identify this limit.

Preview parsed rows before submitting; validate required fields, exact worship values, date formats, boolean values, gender, age, nonnegative visit count, unique internal ID, and ambiguous congregation names. Unknown congregation names map to null with a visible warning, matching the optional congregation field. Missing internal IDs are invalid rather than silently generating new identities. Duplicate IDs within a file and already-reserved IDs are skipped without overwriting.

New implementation supports `.xlsx`. Explicitly reject legacy binary `.xls` with a pt-BR conversion instruction; this is a documented compatibility reduction from the original file picker's extensions. Cap compressed input at 10 MiB, decoded rows at 10,000 and archive expansion at 50 MiB before processing. Reject formula cells/oversized archives, treat exported user text as text rather than formulas, and report row errors without exposing personal values in logs.

Submit validated rows in chunks of at most 25. Each row is an atomic create/reservation/week-counter operation; the entire workbook is not one transaction. Return created/skipped/invalid counts and row numbers, persist resumable progress, and reuse operation IDs after retries. A lost response followed by retry must not duplicate data. Large exports traverse every authorized page.

## 9. UI, packages and completion

Routes: `/login`, `/verify-email`, `/register`, `/home`, `/converts`, `/converts/:id`, `/admin`. No-access sign-in lands on Register; authorized sign-in lands on Home. Loading identity/access never briefly renders private routes. Admin keeps five tabs: Congregações, Acessos, Relatório, Eventos, Backup. Feedback management opens from an Admin action.

Proposed dependencies: official FlutterFire plugins (`firebase_core`, `firebase_auth`, `cloud_firestore`, `cloud_functions`, `firebase_storage`, `firebase_app_check`), `flutter_riverpod`, `go_router`, `intl`, `timezone`, `image`, `image_picker`, `file_picker`, `excel`, `archive`, `url_launcher`, and `file_saver` behind the web/Android save adapter. Resolve compatible stable versions once, commit Dart/npm lockfiles, document licenses and tested platform support. Use byte-based `file_saver` APIs; default Android app-private saves are not a user-accessible export, so use a user-selected save location. Do not install product dependencies during this planning phase.

Use App Check with platform providers in production; debug providers are emulator/development only. Stage production enforcement after provider validation. Cloud Storage requires the Blaze plan; Functions deployment also has billing prerequisites. Development remains local and uses no real source data. Budget alerts are notifications, not spending caps. Publishing requires project configuration, OAuth/SHA settings and signing choices; an emulator success is not a production auth validation.

Completion requires meaningful domain tests, command and Rules emulator tests, responsive widget tests (360, 768, 1280 logical pixels and 200% text), critical end-to-end flows, clean analyzer/typecheck, web release build and Android APK debug/release-build verification. Produce an unsigned/unpublished build if signing is not supplied; never claim production deployment or migration happened.

## 10. Official references

- [Firebase Flutter setup](https://firebase.google.com/docs/flutter/setup)
- [Callable Functions](https://firebase.google.com/docs/functions/callable)
- [Firestore transactions](https://firebase.google.com/docs/firestore/manage-data/transactions)
- [Queries must fit Security Rules](https://firebase.google.com/docs/firestore/security/rules-query)
- [Storage setup and Blaze requirement](https://firebase.google.com/docs/storage/flutter/start)
- [Codex subagent model and effort configuration](https://learn.chatgpt.com/docs/agent-configuration/subagents)
- [FileSaver platform and save-location APIs](https://pub.dev/packages/file_saver)
- [Dart XLSX codec](https://pub.dev/packages/excel)
