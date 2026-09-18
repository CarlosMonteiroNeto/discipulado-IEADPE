# Discipulado IEADPE — Flutter web-first specification

## S01 — Purpose, scope, and provenance

Design a new application for managing the discipleship ministry across congregations: team contacts, students, classes, enrollment, and attendance. The primary product is a responsive browser application in Brazilian Portuguese. Flutter is the presentation technology; Android packaging is a later delivery, not an acceptance requirement for this release.

This document and `plan.json` are the complete planning handoff. They describe proposed behavior, not an implemented or deployed application. The current request authorizes only these two files. Do not start implementation, initialize a repository, contact the legacy backend, migrate data, install dependencies, or deploy as part of this planning session. The future implementation agent reads both files and implements in a separate Flutter project root; paths in the plan are relative to that new root. Copy both artifacts there before execution. Preserve the Android source as reference.

### Category skeleton

- Generic category: internal administration and learning-cohort management.
- Specific category: congregational discipleship administration for IEADPE.
- Original implementations: ministry roles by congregation and supervision, multiple teachers with single-holder administrative roles, student discipleship and baptism information, class attendance, and user-initiated WhatsApp contact.

### Evidence from the supplied project

Paths below are relative to the legacy folder, not the future Flutter root.

| Source | Observed concept or limitation | Design consequence |
| --- | --- | --- |
| `main/java/com/example/discipulado_ieadpe/MainActivity.java` | Congregation selection, locally checked passwords, remembered-login flag | Keep congregation context; replace authentication and authorization |
| `main/java/com/example/discipulado_ieadpe/ListaDeContatosAdapter.java` | Congregational edit controls, supervision privileges, role ordering, WhatsApp | Preserve role-aware workflows; enforce access on the backend |
| `main/java/com/example/discipulado_ieadpe/AddEditMembroActivity.java` | One holder per administrative function, multiple teachers, replacement prompt, name editing blocked | Stable IDs, editable names, atomic assignment replacement |
| `main/java/com/example/discipulado_ieadpe/database/repositorios/RepositorioGeral.java` | Firestore collections, contact document ID derived from name, delete-then-add editing | New schema, stable IDs, revision checks, atomic writes |
| `main/java/com/example/discipulado_ieadpe/database/entities/Aluno.java` | Personal/contact fields, congregation, class, baptism flags, dates, attendance map | Separate student identity, enrollment, session, and attendance records |
| `main/java/com/example/discipulado_ieadpe/AddEditAlunoActivity.java` and `main/res/layout/activity_add_edit_aluno.xml` | Student form is unfinished | Student workflows are a designed completion, not established legacy behavior |
| `main/java/com/example/discipulado_ieadpe/database/AppDatabase.java` | Room persistence alongside Firestore-oriented code | One authoritative remote persistence model |

The legacy code is evidence of intent, not a correctness baseline. Do not copy credentials, personal data, login flags, package namespace, broken validation, or database contents into the new project. No external template or dependency research was performed for this specification.

## S02 — Alternatives and chosen proposal

1. **Flutter + Firebase Authentication + Firestore + callable backend functions — selected proposal.** Retains the legacy backend family while redesigning identity, authorization, data ownership, and operations. Requires maintaining backend functions and database rules alongside Flutter; the old collections are not reused.
2. **Flutter + a custom API and relational database.** Makes relational constraints explicit but adds a separate API and deployment surface. A valid alternative if organizational hosting requirements demand it; not part of this plan.
3. **Flutter with browser-local storage only.** Small deployment footprint, but does not deliver shared records and congregation-level authorization across devices. Rejected for this proposed shared application.

The choice is based on the supplied source and bounded scope, not a claim about current vendor pricing or comparative package quality. Use a new isolated Firebase development project or local emulators. Package versions are resolved and locked by the implementing agent against its installed Flutter/Dart and backend runtimes. Do not insert guessed version numbers into this plan or run template searches.

### Explicit product assumptions

- One IEADPE ministry deployment contains multiple congregations and one supervision team. Multi-organization SaaS is excluded.
- Authenticated staff use individual accounts; there is no student portal or public directory in this release.
- Supervision manages every congregation; local staff manage only their assigned congregation. Staff can consult a minimal authenticated directory across congregations.
- Birth date, address, education, marital status, and religious-status answers are optional. There is no inferred minimum age requirement.
- Classes and attendance complete the concepts sketched in the legacy student model. There is no predefined lesson count, curriculum, graduation threshold, or automatic certification.
- Initial accounts and access assignments are provisioned by a trusted operator; an in-app identity administration console is excluded.

## S03 — Global constraints

These constraints are inherited by every plan task.

1. Implement in a new Flutter project root; preserve the legacy Android folder and its data.
2. Flutter web is the release target; support keyboard, pointer, touch, browser history, direct links, refresh, and responsive layouts.
3. User-facing copy uses pt-BR; identifiers, code, specifications, and technical documentation use English.
4. Use Firebase Auth, Firestore, and authenticated callable functions with a new schema; never reuse legacy credentials or production data.
5. The backend enforces authorization and validation; hiding controls or filtering fetched data in Flutter is not authorization.
6. Use stable opaque IDs, ISO date-only strings for calendar dates, UTC server timestamps for events, and integer revisions for mutable records.
7. Online writes require server confirmation; no offline write queue, automatic retry of mutations, persistent sensitive browser cache, or false success messages.
8. Resolve compatible dependencies and commit lockfiles during implementation; no template or extension search is required.
9. Keep feature logic separate from widgets and vendor SDKs; use injected repositories and deterministic clocks in tests.
10. Do not deploy, push, import legacy data, or send messages automatically. Build and emulator verification are the release evidence for the implementation handoff.

## S04 — Accounts, authorization, and data visibility

Use email/password Firebase Auth, sign-in, password-reset request, and sign-out. Disable public account registration in the app. A valid Auth session is insufficient without an active `users/{uid}` profile. Profile fields: `accessRole: supervisor | congregationStaff`, `congregationId: string?`, `active: bool`, `revision: int`, `updatedAt: timestamp`. Staff must have exactly one active congregation; supervisors have no mandatory congregation binding.

Session persistence is session-scoped by default. No custom local-storage credential mechanism or fabricated login bypass. Restore the Auth session before resolving a protected deep link. A missing/inactive profile shows `Acesso não autorizado` and a sign-out action; do not render cached protected content. Read the current profile on every callable operation. Listen to the caller's own profile and clear loaded data immediately when it becomes inactive, changes role/scope, or becomes unreadable. Sign-out disposes listeners, clears in-memory records and form drafts, and returns to `/entrar`. Direct backend access remains denied after revocation even if a client is stale.

| Resource/action | Anonymous | Congregation staff | Supervisor |
| --- | --- | --- | --- |
| Own access profile | Denied | Read own only | Read own only |
| Active congregation names and team directory projection | Denied | Read | Read |
| Contact private details and mutation | Denied | Own congregation | All scopes, including supervision |
| Students/classes/enrollments/sessions/attendance | Denied | Own congregation | Any selected congregation |
| Create/rename/archive congregation | Denied | Denied | Allowed subject to dependencies |
| Change account access | Denied | Denied | Not exposed to application clients; trusted provisioning only |
| Dashboard | Denied | Own congregation | Selected congregation or aggregate of authorized congregations |

The directory projection stores only contact ID, display name, normalized name, role, team scope, congregation ID, and optional phone. Resolve the displayed congregation name from the authorized congregation catalog by ID; do not duplicate it in every contact. Birth date and student/religious information never appear in the projection. Full contact records stay scope-protected. Phone is optional and shared with authenticated staff when provided; explain that audience next to the field.

Firestore rules deny client writes to every collection and deny all unspecified reads. Allow only scoped reads matching this matrix and directory projections. Callable functions perform all application mutations through Admin SDK transactions and repeat validation and authorization explicitly because Admin SDK bypasses rules. Never trust caller-supplied role or congregation claims as authority. Cross-congregation reads, forged IDs, and changed document paths must fail in emulator tests.

Provisioning uses a trusted, environment-configured Admin SDK utility accepting an existing Auth UID, access role, and congregation ID. It validates the target congregation, supports deactivation, emits a redacted outcome, and never stores a password. The runbook describes creation of the first supervisor and subsequent individual accounts through the Auth administration interface. No callable endpoint may grant access roles. Fixtures use synthetic people and emulator accounts only.

## S05 — Data model and invariants

Use top-level `users`, `congregations`, `directory`, and `supervisionContacts`; congregational resources are under `congregations/{congregationId}/`. Supervision role slots are under `supervisionRoleSlots`; local slots are under `congregations/{id}/roleSlots`. Other local collections are `contacts`, `students`, `classes`, `enrollments`, and `sessions`. Each session owns an `attendance` subcollection and an internal `roster` subcollection. Internal `operations` receipts are not directly readable by clients. Directory IDs equal globally unique contact IDs. Do not put personal information in IDs or URLs.

Every mutable domain document has `id`, `revision` (starts at 1), `createdAt`, `updatedAt`, and `updatedBy`. Creates use a client-generated UUID retained throughout submission/retry; existing-record mutations require `expectedRevision`. Successful updates increment revision once. A mismatch yields `conflict` without overwriting data. Creation timestamps and ID never change. Shared domain values are immutable Dart objects with explicit serialization; unknown enum values produce a controlled data error, not a crash.

| Model | Fields beyond common metadata | Required invariants |
| --- | --- | --- |
| Congregation | `name`, `normalizedName`, `active` | Nonempty unique normalized name; not the supervision role |
| Contact | `name`, `normalizedName`, `scope: congregation | supervision`, `congregationId?`, `roleCode?`, `phoneE164?`, `birthDate?`, `archived` | Scope and congregation agree; archived contact has no active role slot |
| Student | `name`, `normalizedName`, `congregationId`, `phoneE164?`, `birthDate?`, `address?`, `education?`, `maritalStatus?`, `newConvert: bool?`, `waterBaptized: bool?`, `wantsBaptism: bool?`, `archived` | Nullable religious answers mean not informed, not false; if baptized=true, wantsBaptism must be false or null |
| Address | `street?`, `district?`, `city?`, `postalCode?`, `stateCode?` | No geocoding or external address lookup |
| ClassGroup | `congregationId`, `name`, `normalizedName`, `teacherContactId?`, `startDate`, `endDate?`, `status: active | completed | archived` | End >= start; assigned teacher is an active local contact with teacher role |
| Enrollment | `studentId`, `classId`, `congregationId`, `startDate`, `endDate?`, `status: active | completed | withdrawn` | Same congregation; only one active enrollment per student in this release; dates inside class period |
| Session | `classId`, `congregationId`, `date`, `topic?`, `status: open | finalized | canceled`, `rosterFrozen: bool` | Date inside class period; no duplicate noncanceled class/date pair; topic <= 200 characters |
| Attendance | `studentId`, `enrollmentId`, `status: present | absent | excused | unmarked` | ID is enrollment ID under session; no free-text pastoral notes |

Common name length is 2–120 trimmed characters. Store Unicode display text intact; search keys lowercase and remove diacritics with the same deterministic normalization in Dart and backend. Names are not person identifiers: homonyms coexist. Phone input accepts Brazilian 10/11-digit national numbers, optional formatting, or the equivalent `+55` form; normalize to E.164. DDD begins 1–9 and mobile subscriber numbers have 9 digits starting with 9. Empty optional numbers are allowed; reject non-Brazilian numbers for this release. This validates structure, not ownership or WhatsApp availability. Birth dates must be real calendar dates, >= 1900-01-01 and <= today in America/Recife. No rolling ten-year cutoff. UI format is `dd/MM/yyyy`; transport/storage is `yyyy-MM-dd`. Validate the same calendar semantics server-side.

Optional address fields: street <= 200, district/city <= 100, postal code exactly eight digits when present, state code one of Brazil's 27 UF codes. Education and marital status are optional short text <= 80 characters; do not invent theological or academic classifications. A student's current class and course dates come from enrollment, not duplicated student fields.

Use transactions and internal uniqueness documents for congregation names, administrative role slots, active student enrollments, and active class/date sessions. These internal records have no direct client access. Internal indexes include their scope in the key; uniqueness is not inferred from a previously loaded list. Scope IDs are immutable; cross-congregation transfer is excluded. Archive rather than hard-delete records in normal workflows. Archived records remain available to authorized staff through an explicit filter.

## S06 — Team and congregations

Navigation label: `Equipe`. List active directory contacts, search by name prefix, and filter by congregation/supervision and role. Default ordering is normalized name then ID; role is a filter, not a hidden priority algorithm. A details route resolves only the directory projection for staff outside the contact's scope and must not fetch private fields. Locally authorized users can open the complete contact editor and archive action. An `Arquivados` filter is available only within a selected scope the caller may manage; it queries scoped private contact records because archived contacts have no directory projection. Archived detail links include the validated scope parameter, allowing authorized direct lookup and restoration without exposing archived people to other staff.

Preserve these stable role codes and pt-BR labels:

| Scope | Code | Label |
| --- | --- | --- |
| supervision | campaignSupervisor | Supervisor das campanhas |
| supervision | campaignDeputy | Vice-supervisor das campanhas |
| supervision | discipleshipCoordinator | Coordenador do discipulado |
| supervision | discipleshipDeputy | Vice-coordenador do discipulado |
| supervision | coordinationSecretary | Secretária da coordenação |
| supervision | coordinationDeputySecretary | Vice-secretária da coordenação |
| congregation | congregationAssistant | Assistente de congregação |
| congregation | campaignLeader | Dirigente de campanha |
| congregation | campaignDeputyLeader | Vice-dirigente de campanha |
| congregation | teacher | Professor(a) do discipulado |
| congregation | discipleshipSecretary | Secretária do discipulado |
| congregation | discipleshipDeputySecretary | Vice-secretária do discipulado |

Each contact has zero or one current role. Administrative roles have one active holder per scope; teacher has multiple holders. Changing a occupied role returns the holder's name and revision to authorized callers. An explicit `Substituir responsável` confirmation submits both current-holder and target revisions. One transaction clears the old assignment, assigns the target, and updates both projections and the role slot. The former contact remains intact and unassigned. Cancel changes nothing. A concurrency conflict changes nothing. Renaming any person retains ID and history. Archiving releases their slot atomically. A teacher referenced by an active class cannot lose teacher status, change scope, or be archived until reassigned.

WhatsApp is a visible, user-initiated link using only normalized digits in `https://wa.me/{digits}`. Do not prefill student or religious information, send messages, probe installation, or claim delivery. With no phone, disable the action with explanatory text. Provide `Copiar telefone` as fallback with an accessible result notification.

Supervisors create, rename, and archive congregations in `Congregações`. Use real congregation names from `main/res/values/strings.xml` only as an optional manually reviewed setup reference, not a hardcoded identity list or production seed. Start with an empty deployment. Prevent archive while active user profiles, unarchived students/contacts, or active classes reference it. Archived congregations can be read by supervisors and restored; they accept no local mutations except restoration by supervision. Name changes do not change IDs or break relations; refresh the congregation catalog so directory display names resolve to the new authoritative name without a cascading update.

## S07 — Students and enrollment

`Alunos` shows scoped, paginated students, name-prefix search, archived filter, and active-class filter. Staff cannot change the scope selector; supervisors select a congregation before creating a student. Name is the only required personal field. Detail groups: `Dados pessoais`, `Contato`, `Discipulado`, and `Histórico de turmas`. List rows do not expose birth date, address, or religious answers.

Create/edit use the same validation and preserve drafts on validation, conflict, or network failure. A possible duplicate name is informational and never overwrites or blocks a different person. Archive requires confirmation with the student's name, is blocked by an active enrollment, and preserves historical attendance. Restore is supported for the same congregation. No hard delete, merge, cross-congregation transfer, file upload, or automatic legacy import.

Enroll an unarchived student into an active class in the same congregation. Record the start date explicitly. A student already actively enrolled cannot be enrolled again; show the current class. Complete or withdraw enrollment explicitly, with end date >= start date and within the class period. Permit a later new enrollment once the old one closes. Past attendance stays linked to the original enrollment. Once included in a frozen roster, startDate cannot change; closing is still allowed, but endDate must not precede the latest noncanceled frozen session containing the enrollment. This preserves historical membership while allowing students to finish their course. A completed/withdrawn enrollment is immutable in this release.

## S08 — Classes, sessions, attendance, and progress

`Turmas` lists scoped classes and active/completed/archived filters. Class detail shows teacher, period, roster, sessions, and counts. Class size is capped at 100 total enrollment records, including completed/withdrawn records; a backend transaction enforces the cap. This is an explicit initial product limit that bounds historical rosters and atomic attendance writes, displayed before adding enrollment 101. Closing enrollment does not free this historical capacity; create another class for a new cohort. Class completion is blocked until every enrollment closes and every session is finalized or canceled. Completed classes are read-only; completed classes may be archived. Archiving an active class requires zero enrollments and zero sessions. No reopening completed classes in this release. Class dates cannot change once any enrollment or session exists; class name and eligible teacher may still change while active.

Create an open session with date and optional topic. A new open session has no attendance records and `rosterFrozen=false`. On the first saved attendance command or finalization, the server freezes the roster from enrollments whose date interval includes the session date (including completed/withdrawn enrollment intervals). Copy enrollment IDs and student display names into internal roster entries so later renaming does not change historical identity labels; keep IDs to resolve the current student separately. Late enrollment after freezing does not silently enter that session. There is no manual roster surgery in this release; correct an unused session by canceling and creating a replacement.

The attendance screen always distinguishes `Presente`, `Ausente`, `Justificado`, and `Não marcado`. All entries initially unmarked; opening a session never implies absence. Provide explicit `Marcar todos presentes` and individual controls, then `Salvar chamada`. The server accepts a complete roster map, validates exact membership and statuses, and atomically writes the roster, marks, and new session revision. No partial attendance success. Disable only duplicate submission, not unrelated navigation. If another operator saved first, return a conflict and offer reload while retaining an on-screen copy of unsaved selections for comparison; never silently merge.

Finalization requires at least one roster member, all members marked, and session date <= today in America/Recife. Save-and-finalize is one atomic operation. Finalized session attendance can be corrected by an authorized staff member using the current session revision; all marks must remain complete. Increment revision and `updatedBy`/`updatedAt`, preserving membership. Cancellation of an open or finalized session requires explicit confirmation and keeps its data, but excludes it from progress. Canceled sessions cannot be edited. Attendance cannot be changed after class completion.

Student progress is enrollment-specific: `present / (present + absent)` from finalized, noncanceled sessions containing that enrollment. Excused sessions are displayed separately and excluded from the denominator; unmarked/open/canceled sessions never affect percentage. Zero denominator displays `Sem aulas contabilizadas`, not 0% or division-by-zero. Round the displayed percentage to the nearest whole percent; show the raw counts too. Example: 3 present, 1 absent, 2 excused means 75%. Do not automatically graduate students or infer baptism readiness.

## S09 — Overview and querying

`Visão geral` displays unarchived students, active classes, and open sessions dated through today, plus links to the relevant filtered lists. The open-session count opens a paginated `Chamadas pendentes` section on the same overview route with `pendentes=true`; each entry links to its class/session detail and includes its congregation ID. The backend `listPendingSessions` operation returns these authorized entries ordered by date and ID, including a cursor and the class display name. Supervision can choose a congregation or `Todas`; staff see only their assigned scope. Counts are calculated on the backend from authoritative records and include scope in every query. There are no financial charts, rankings, invented success metrics, or analytics collection.

All lists use explicit pagination (50 records by default, maximum 100) and stable ordering with ID as tie-breaker. Name search is normalized prefix search and is labeled accordingly; it is not arbitrary substring search. Directory supports role/scope filters; student active-class filter resolves the enrollment membership before listing matching students and must not apply filtering only after fetching a page. Classes use normalized name order, sessions date+ID order, and enrollment history startDate+ID order. Query indexes are declared for every shipped combination; unsupported filter combinations are prevented in the UI and rejected in repository input.

Search/filter changes reset pagination, cancel or disregard older requests, and retain scope. Data and counts refresh on page entry, successful mutation, and a visible `Atualizar` control. Do not promise live synchronization or download whole collections for counts or search. List errors have `Tentar novamente`; loading, empty data, empty search, forbidden, not-found, stale-conflict, and offline states are distinct. Failure to load is never displayed as an empty database.

## S10 — Web routes and interaction design

Routes: `/entrar`, `/recuperar-senha`, `/visao-geral`, `/equipe`, `/equipe/:contactId`, `/alunos`, `/alunos/novo`, `/alunos/:studentId`, `/alunos/:studentId/editar`, `/turmas`, `/turmas/nova`, `/turmas/:classId`, `/turmas/:classId/chamadas/:sessionId`, and `/congregacoes`. Scope is carried in a validated `congregacao` query parameter for scoped routes; supervisors may use `todas` only on overview. Contact detail resolves ID through the directory projection; authorized full detail includes its scope. Entity ownership is verified after route resolution. Creation routes precede parameter routes. Unknown paths show an accessible not-found page. Auth return URLs accept internal allowlisted routes only.

Use URL query parameters for scope, search text, and list filters; pagination cursor stays session-local and resets on reload. Back/forward restores filters. Hard refresh and pasted detail URLs must render the same authorized record. Configure hosting rewrites to `index.html`; route guards must preserve destination while the session loads. Warn before losing a dirty form through in-app navigation or browser history; use the browser's supported unload confirmation for refresh/close without promising custom text.

At widths >= 1024 logical pixels, use a persistent left navigation area and a bounded content pane, tables for comparable records, and two-column grouped forms. At 600–1023, use compact navigation and reduce columns. Below 600, use a drawer, record cards, and single-column forms. Verify at 360, 768, and 1440 widths, including 200% text scaling. No page-wide horizontal scrolling; a clearly labeled table region may scroll horizontally only when its information cannot reflow.

Apply the apple-design principles as usability requirements, not a dependency on Cupertino widgets or Apple assets. Use calm neutral surfaces with a restrained blue accent, clear heading/body hierarchy, body text at least 16 logical pixels, default platform font, and a consistent 4/8 spacing scale. Prefer opaque content surfaces. A translucent navigation layer is optional only with an opaque accessibility fallback and sufficient contrast. Controls provide immediate press and focus feedback; commit on activation, not pointer-down. Transitions never block input or reset fields; reversible panels start from their current presentation state and use consistent entry/exit direction. Reduced-motion settings remove positional animation and overshoot. Avoid custom drag gestures and decorative animation in this release.

Every action must work by keyboard with visible focus and descriptive semantics. Touch targets are at least 44x44 logical pixels. Dialogs trap focus, Escape cancels noncommitted actions, and dismissal restores focus to the trigger. Errors associate with fields and focus moves to the first invalid field on submit. Screen readers receive submission outcomes. Text contrast >= 4.5:1 and meaningful control boundaries/focus >= 3:1; do not encode attendance states by color alone. Loading buttons expose their state. Long names wrap; localized dates, accented names, and empty optional fields have explicit rendering.

## S11 — Architecture and implementation contracts

Use feature folders under `lib/features/` with pages, controllers, and repositories. Shared pure Dart domain types and validation live under `lib/domain/`; Firebase adapters under `lib/data/`; reusable presentation primitives under `lib/ui/`. Use `ChangeNotifier`/`Listenable` controllers and constructor injection for this release. Use a routing package capable of typed route resolution and browser URLs (planned dependency: `go_router`). Planned vendor adapters use `firebase_core`, `firebase_auth`, `cloud_firestore`, and `cloud_functions`; external links use `url_launcher`; locale formatting uses `intl`. Do not introduce a second state-management framework, ORM, code generation, or template framework without a concrete unmet requirement.

Backend functions use TypeScript, Firebase Admin SDK, and a validation boundary shared by all handlers. Core handlers are plain functions receiving an authorized context and an injected datastore/clock; callable wrappers are thin. `functions/src/index.ts` owns the sole export/registration point and is created during final composition. Rules and indexes are owned by the backend foundation task and cover the full model from the outset. Feature modules must not edit shared manifests or registrations; declare new test files outside the exclusive production-file `touches` set according to the pipeline's brief-scaffold contract.

### Shared Dart ports

- `AuthRepository`: `Stream<AuthSession?> watchSession()`, `Future<void> signIn(String email, String password)`, `Future<void> requestPasswordReset(String email)`, `Future<void> signOut()`; `AuthSession` carries UID and the current validated `AccessProfile`.
- `BackendGateway`: `Future<JsonMap> invoke(String operation, JsonMap payload)`, `Future<PageResult> query(QueryRequest request)`, `Future<JsonMap?> get(RecordLocator locator)`; `JsonMap = Map<String, Object?>`.
- `QueryRequest`: `resource` enum (directory, congregations, contacts, students, classes, enrollments, sessions), optional `congregationId`, explicit equality filters, optional normalized `namePrefix`, `limit`, and opaque `cursor`. Repositories validate supported combinations from S09. `RecordLocator` contains resource, ID, optional congregation ID and parent class/session ID as required. Internal collections are not valid resource enum values.
- `PageResult`: `List<JsonMap> items`, nullable opaque `nextCursor`. Cursor includes scope/filter/order identity and last sort value plus ID; reject reuse after a filter/scope change. Never put it in public URLs.
- `AppFailure`: code enum `validation`, `unauthenticated`, `forbidden`, `notFound`, `conflict`, `unavailable`, `unknown`; optional field errors; safe user message. Translate SDK errors at the adapter boundary; do not display stack traces, tokens, or raw backend responses.

Each feature repository exposes typed models over these ports. Controllers implement immutable view state with loading/data/error/submitting and discard stale asynchronous responses by request generation. No widget directly accesses Firebase. BackendGateway routes complex queries (student-by-class, aggregate overview, and attendance/progress) to callable read handlers; direct Firestore reads remain constrained by the same scope and rules. Both transport paths return the same explicit error semantics.

### Backend operation contract

Expose named callables: `saveCongregation`, `setCongregationArchived`, `saveContact`, `replaceRoleHolder`, `setContactArchived`, `saveStudent`, `setStudentArchived`, `saveClass`, `setClassStatus`, `enrollStudent`, `closeEnrollment`, `createSession`, `saveAttendance`, `cancelSession`, `listClassStudents`, `getSessionAttendance`, `getEnrollmentProgress`, `getOverview`, and `listPendingSessions`.

Create/update payloads carry the applicable model fields and scope, record ID, `expectedRevision` for updates, and `requestId`. Archive/status operations carry ID, scope, target state, revision, and requestId. Role replacement additionally carries expected previous-holder ID and revision. Enrollment close carries status and endDate. Attendance carries session ID, expected session revision, complete map keyed by enrollment ID, and `finalize: bool`; no client-supplied roster may be trusted. Read endpoints take scope and resource IDs or a validated QueryRequest and never mutate records.

Mutation responses return `{id, revision}` plus updated affected IDs when multiple records change. An internal operation receipt keyed by UID and requestId stores a canonical payload digest and original result within the same transaction. Repeating the same operation returns the same result; reusing the requestId with another payload fails validation. Receipts expire after seven days; deletes/expiry do not affect domain records. After a transport timeout, the UI retains the requestId and offers explicit retry of that same command; it does not create another record. Enforce UUID record creation with create-if-absent to retain duplicate safety even after receipt expiry. Existing revisions protect old update retries.

Authorization is evaluated even when returning an existing receipt. Mutations that must be atomic include contact/role/directory changes, student-enrollment locks and class counts, session/date locks, attendance plus roster, and receipts. The cap of 100 roster members bounds attendance transactions. Do not chunk a logical attendance submission into partial commits. Server times, scope ownership, enum validation, and cross-record invariants are authoritative.

## S12 — Reliability, privacy boundaries, and non-goals

Application data is remote-authoritative. Disable persistent Firestore browser caching for this release; maintain only disposable in-memory data. Network loss shows an offline/unavailable message and prevents unconfirmed writes; users may keep editing their current in-memory draft. Do not persist forms in localStorage. Reconnection requires a refresh or an explicit save/retry. Reset dependent selections when congregation changes; never show a previous congregation's list during a new scope load.

No student details, religious status, or phone numbers in logs, route query parameters, analytics events, or error reports. Authenticated directory availability does not authorize public indexing. Set noindex metadata and keep all data behind authorization. Static code/config served to browsers contains no Admin SDK keys or privileged credentials. Use environment-specific Firebase client configuration; fail clearly if production configuration is absent instead of silently connecting to the legacy project. Emulator mode must be explicit and unmistakable.

Excluded: public contact access, attendance offline sync, native Android release, push notifications, bulk WhatsApp, finance, certificates, curriculum/content hosting, photo uploads, PDFs/spreadsheets/exports, AI features, multi-organization tenancy, cross-congregation transfer, arbitrary full-text search, a user administration UI, legacy migration, and production deployment. Backup operations and organization-specific retention policies belong to deployment administration; this implementation must not invent deletion schedules or claim legal compliance.

## S13 — Verification and definition of done

Use synthetic fixtures: one supervisor, two local staff accounts in different congregations, one inactive profile, homonymous contacts/students, at least two teachers, a conflicting administrative role, one class in each congregation, and sessions spanning each attendance status.

Required evidence during implementation:

- Pure Dart tests: calendar edge cases (including leap years), phone normalization, nullable baptism fields, serialization, name normalization, progress 3/4=75%, and zero denominator.
- Backend/emulator tests: anonymous denial, cross-scope reads and every mutation family denied, profile tampering denied, inactive caller denied, directory projection excludes private fields, stale revisions, concurrent administrative role claims, active-enrollment uniqueness, class capacity 100/101, exact roster validation, attendance rollback, request replay, and altered-payload replay rejection.
- Widget tests: invalid form preserves values, editing an ID preserves identity, confirmation cancel has no effect, server failure never announces success, stale query result cannot replace new scope, role-based actions, all four attendance states, loading/empty/error/not-found views, and focus/keyboard behavior.
- Browser integration using local Auth/Firestore/Functions emulators: individual sign-in, create contact with a homonym, rename it, replace a role, create student and class, enroll, save and finalize attendance, verify progress, reload a direct detail URL, back/forward filters, sign-out, then attempt access as the other congregation. Include a denied forged backend request, not only disabled controls.
- Responsive and accessibility inspection: 360/768/1440 widths, 200% text, keyboard-only flow, screen-reader names/outcomes, reduced motion, and contrast. Browser smoke on Chromium, Firefox, and WebKit; primary end-to-end automation runs in Chromium. Record actual browser versions in the resulting verification report rather than assuming them here.
- Green `flutter analyze`, `flutter test`, `flutter build web --release`; backend TypeScript compilation and emulator suites; no runtime SDK exceptions on the critical flow. Emulator/security suites are required in addition to the Flutter gate, because Flutter unit tests cannot prove backend authorization.

The final implementation task owns a reproducible local verification entry point and CI configuration. Keep Flutter at the new repository root for toolchain detection; backend package files live under `functions/`. If the two-model runner is used, configure it to include the backend/emulator command as a required gate and use its command wrapper. Do not mark the release verified when a backend or browser check was skipped. Missing local credentials/toolchains are reported as environment blockers, not replaced with production access.

Completion means every plan acceptance criterion is met with recorded evidence and the emulator-backed application can be run from documented commands. Creating a Flutter shell, using fake repositories in production composition, or providing screens without backend enforcement is incomplete. The planning session itself only validates these artifacts; it does not claim any application tests passed.

## S14 — Handoff sequence and task coverage

The plan follows the pipeline's complete-task schema: numeric ID, title, summary, spec_refs, touches, depends_on, acceptance. No expected_red field. Test files are created by the implementation worker and are described in acceptance rather than declared in touches, because the installed brief-scaffold rejects test-like touches. Every production file has one task owner; final composition waits for all features and owns app entry points and function exports. Shared dependencies and contracts land first.

| Tasks | Deliverable | Specification coverage |
| --- | --- | --- |
| 1 | Flutter configuration, domain models, shared ports, validation | S01–S03, S05, S11 |
| 2 | Backend foundation, rules, authorization, provisioning, emulator config | S03–S05, S09, S11–S13 |
| 3 | Congregation and contact operations | S05–S06, S11–S13 |
| 4 | Student operations and scoped query | S05, S07, S09, S11–S13 |
| 5 | Class and enrollment lifecycle | S05, S07–S08, S11–S13 |
| 6 | Sessions, atomic attendance, and progress | S05, S07–S08, S11–S13 |
| 7 | Flutter authentication and Firebase gateway | S04, S09–S12 |
| 8 | Shared responsive and accessible presentation | S10, S12–S13 |
| 9 | Team and congregation workflows | S04, S06, S09–S10 |
| 10 | Student workflows | S05, S07, S09–S10 |
| 11 | Class and attendance workflows | S07–S10 |
| 12 | Scoped overview backend and frontend | S04, S09–S11 |
| 13 | Composition, browser verification, CI, runbook | S01–S04, S10–S14 |

Before execution in another session, use a clean Flutter-target repository, carry `spec.md` and `plan.json`, resolve its toolchain, and have the implementation scope/design reviewed. This planning handoff does not authorize executing a pipeline command that pushes or deploys; the pipeline supports a no-push execution mode. No separate CONTEXT, ADR, template, scaffold, or implementation file is created by this planning request; its relevant vocabulary and decisions are included here.
