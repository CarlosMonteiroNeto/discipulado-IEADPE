# Ministry contracts for the Supabase port

> Historical contract baseline. The independent campaign/ministry grant assumptions below were superseded by 202610180003_base44_unified_access.sql and the approved unified-access design. The current local shared-person and Team completion gate is [ministry-completion-contracts.md](ministry-completion-contracts.md); do not implement new completion features from obsolete authority/identity assumptions in this baseline. Existing RPC shapes remain reference evidence until replaced by reviewed forward-compatible contracts.

Status: task 1 contract baseline. Sources: `discipulado-IEADPE` `main@4acb563` (`docs/superpowers/specs/discipulado-ieadpe-spec.md`, `lib/domain/*.dart`, `functions/src/*/service.ts`) and the completed convert app `implementation/supabase-free@642047f` (`supabase/migrations/202610140002_schema.sql`, `202610140003_access.sql`, and `202610140004_convert_commands.sql`). This document resolves the port boundary for plan tasks 2–5. It does not authorize identity cutover or historical import.

## Decisions and authority boundary

- The verified Supabase Auth UID is the actor. Never accept a role, actor UID, email, revision, or timestamp supplied as authority. `auth.uid()` supplies actor identity; every RPC re-reads active grants while holding the existing access-version lock protocol.
- Campaign grants and ministry grants are separate rows/role namespaces. A campaign direction or campaign supervision grant does not imply ministry access. A ministry grant does not reveal converts, campaign events, photos, or campaign reports. Do not reuse `user_access` campaign role rows as ministry grants.
- A person may hold several grants concurrently. Grant scope is explicit. `campaign_direction` and `ministry_staff` require a congregation UUID; `campaign_supervision` and `ministry_supervision` are global and have no congregation UUID. Registrar is the existing authenticated registration capability, not a grant. The trusted admin allowlist is orthogonal, provisioned outside client RPCs.
- “Supervision” is therefore two independent grants. IEADPE `AccessRole.supervisor` authorizes ministry supervision in the source app; it does not establish that a campaign supervisor should receive ministry data in the combined product. Existing IEADPE accounts need an explicit trusted mapping to ministry grants during a separately authorized release.
- Inactive, missing, unbound, or revoked grants have no protected read or mutation rights immediately. Re-check authority before returning an idempotent receipt. A grant revoked during a transaction serializes against that transaction using the same deterministic actor/affected-UID lock order as convert commands. Clear cached scoped views when the verified scope version changes.
- Campaign registration permits an authenticated registrar to create a convert for any active congregation and permits an unassigned convert; it never permits directory/list/detail reads. Ministry student writes always require one active ministry grant for the student’s required congregation. An unassigned convert cannot be promoted by ministry RPCs; the journey promotion RPC owns that separate decision.
- Every ministry business table has RLS; protected reads are scoped and all direct business writes are revoked. RPCs validate scope, revisions, idempotency and invariants. No query takes a client supplied role as a filter that changes authority.

## Role matrix

“Read” means authorized, scoped projections and details appropriate to that module. “Write” means the module’s server commands, subject to invariants. All unauthenticated requests are denied. The trusted admin allowlist is a separate application-wide operator capability, not a campaign or ministry grant.

| Verified identity/grant | Campaign records | Ministry contacts and role slots | Students, classes, enrollments, sessions, attendance, progress | Congregation catalog and access grants |
| --- | --- | --- | --- | --- |
| Authenticated, no grants (registrar) | Create only; no list, read, edit, lifecycle or delete. May create with no congregation. | None | None | Active congregation names needed by registration only; no writes |
| `campaign_direction` for congregation C | Read/write campaign records in C; may register to any active congregation as in existing convert contract | None | None | None |
| `campaign_supervision` | Read/write campaign records in all congregations, including unassigned records under existing convert rules | None | None | Manage campaign direction/supervision grants through the existing campaign access RPC; no ministry grant implied |
| `ministry_staff` for congregation C | None; journey may later expose a separately authorized minimal referral projection only | Read/write ministry contacts and local role slots in C | Read/write ministry records in C | Read active congregation name in C; no catalog or grant writes |
| `ministry_supervision` | None unless separately granted campaign role | Read/write supervision contacts/slots and congregation contacts/slots in selected authorized ministry scope | Read/write ministry records in any selected congregation; overview may aggregate authorized ministry scopes | Read active and archived ministry catalog; create/rename/archive/restore congregation subject to dependency rules; cannot grant users |
| Trusted admin allowlist | Read/write campaign through existing server authority | Read/write ministry | Read/write ministry | Manage both grant families and trusted provisioning through protected operator workflow; client cannot edit own allowlist |
| Any listed grant when inactive/revoked | No protected read or write from that grant | No rights from that grant | No rights from that grant | No rights from that grant |

A user with multiple grants receives the union of those rows, evaluated independently per module and scope. A global campaign grant is not the global ministry grant. A grant is not elevated by a contact’s `RoleCode`; team titles are directory/business records, not account authorization claims. Supervision contacts with `ContactScope.supervision` are a ministry contact category and do not themselves confer ministry access.

## Domain model and identity mapping

Use composition-first records: `MinistryRecord` carries `id: UUID`, `congregationId: UUID`, `revision: int`, server `createdAt/updatedAt: timestamptz`, `updatedBy: UUID`, and nullable `legacyFirebaseId: text`; records compose it with typed values. Store `CalendarDate` as PostgreSQL `date` and transport it as strict `yyyy-MM-dd`; never convert through local or UTC midnight. The legacy source document ID is not the UUID primary key and is never cast to UUID. `legacy_firebase_id` is unique within its source entity/table, nullable for newly created records, and immutable after import. Preserve source IDs only as migration lineage; production import is out of scope.

| Type | Typed fields and preserved domain values |
| --- | --- |
| `MinistryContact` | name, normalizedName, `ContactScope(congregation, supervision)`, nullable congregationId consistent with scope, nullable `RoleCode` from IEADPE’s twelve stable wire values, nullable phoneE164 and birthDate, archived |
| `Student` | name, normalizedName, required congregationId, nullable phoneE164/birthDate/address/education/maritalStatus/newConvert/waterBaptized/wantsBaptism, archived, and nullable unique convert UUID reserved for the separate journey migration. `true` waterBaptized cannot coexist with wantsBaptism `true`; null means not informed. |
| `Address` | nullable street, district, city, postalCode, stateCode |
| `ClassGroup` | congregationId, name, normalizedName, nullable teacherContactId, startDate, nullable endDate, `ClassStatus(active, completed, archived)` |
| `Enrollment` | studentId, classId, congregationId, startDate, nullable endDate, `EnrollmentStatus(active, completed, withdrawn)` |
| `Session` | classId, congregationId, date, nullable topic, `SessionStatus(open, finalized, canceled)`, rosterFrozen, nullable zero-based lessonIndex/lessonPart, lessonFinished (default false for legacy sessions) |
| `AttendanceMark` | sessionId, enrollmentId as identity/key, studentId, `AttendanceStatus(present, absent, excused, unmarked)`, frozen student display-name snapshot in the private roster |
| `EnrollmentProgress` | present, absent, excused counts over finalized non-canceled sessions; percentage is null when present+absent is zero, else present/(present+absent). Unmarked never counts. |

Keep class capacity at 100 total historical enrollment rows, not 100 active learners. Only one active enrollment per student in the release. Enrollment history, frozen roster membership and attendance are retained through archival/status changes. No inferred graduation or baptism. Preserve exact source enum wire strings; reject unknown values as controlled data errors.

## Mutation envelope and stable RPC signatures

Each mutation is a named PostgreSQL function `public.ieadpe_ministry_<command>(operation_id uuid, payload jsonb) returns jsonb`. `operation_id` is the existing convert receipt key equivalent of source `requestId`; the client creates one UUID before first submit and reuses it across retries. Actor UID is not in payload. Payloads are strict allow-lists: unknown fields, malformed UUID/date/enum, empty required text and inconsistent scope fail at the boundary. For creates, `id` is a client-generated UUID fixed for retries; updates require `expected_revision`. The server assigns revisions and all timestamps/actor metadata. Revisions start at 1 and increment once per successful mutation. Every response is the prior exact result on same-actor/same-operation/same-canonical-payload replay; a changed payload under the same operation UUID is rejected. Authorization still runs before replay disclosure.

Notation: `UUID`, `Date` (`yyyy-MM-dd`), `Text`, nullable `T?`, enum wire values as listed above. `congregation_id` is required on local records and omitted/null only for supervision contacts and global scope queries. JSON keys are snake_case to match the convert database wire format. All results below are exact JSON objects; no PII, actor identity, receipt digest, or internal exception text is returned.

| RPC | Required payload; optional payload | Return JSON |
| --- | --- | --- |
| `ieadpe_ministry_save_contact` | `{id: UUID, scope: 'congregation'\|'supervision', congregation_id: UUID|null, name: Text, role_code: RoleCode|null, phone_e164: Text|null, birth_date: Date|null}`; update adds `expected_revision: int` | `{id: UUID, revision: int}` |
| `ieadpe_ministry_replace_role_holder` | `{scope, congregation_id: UUID|null, role_code: RoleCode, previous_contact_id: UUID, previous_expected_revision: int, id: UUID, expected_revision: int}`. New holder `id` already identifies a saved unassigned contact; expected revisions protect both contacts. | `{id: UUID, revision: int, previous_contact_id: UUID, previous_revision: int}` |
| `ieadpe_ministry_set_contact_archived` | `{id: UUID, scope, congregation_id: UUID|null, archived: bool, expected_revision: int}` | `{id: UUID, revision: int}` |
| `ieadpe_ministry_save_student` | `{id: UUID, congregation_id: UUID, name: Text, phone_e164?: Text|null, birth_date?: Date|null, address?: {street?: Text|null, district?: Text|null, city?: Text|null, postal_code?: Text|null, state_code?: Text|null}|null, education?: Text|null, marital_status?: Text|null, new_convert?: bool|null, water_baptized?: bool|null, wants_baptism?: bool|null}`; update adds `expected_revision: int` | `{id: UUID, revision: int}` |
| `ieadpe_ministry_set_student_archived` | `{id: UUID, congregation_id: UUID, archived: bool, expected_revision: int}` | `{id: UUID, revision: int}` |
| `ieadpe_ministry_save_class` | `{id: UUID, congregation_id: UUID, name: Text, teacher_contact_id: UUID|null, start_date: Date, end_date: Date|null}`; update adds `expected_revision: int` | `{id: UUID, revision: int}` |
| `ieadpe_ministry_set_class_status` | `{id: UUID, congregation_id: UUID, status: 'active'\|'completed'\|'archived', expected_revision: int}` | `{id: UUID, revision: int}` |
| `ieadpe_ministry_enroll_student` | `{id: UUID, congregation_id: UUID, class_id: UUID, student_id: UUID, start_date: Date}` | `{id: UUID, revision: int}` |
| `ieadpe_ministry_close_enrollment` | `{id: UUID, congregation_id: UUID, status: 'completed'\|'withdrawn', end_date: Date, expected_revision: int}` | `{id: UUID, revision: int}` |
| `ieadpe_ministry_create_session` | `{id: UUID, congregation_id: UUID, class_id: UUID, date: Date, topic: Text|null}` | `{id: UUID, revision: int, status: 'open'}` |
| `ieadpe_ministry_cancel_session` | `{id: UUID, congregation_id: UUID, expected_revision: int}` | `{id: UUID, revision: int, status: 'canceled'}` |
| `ieadpe_ministry_save_attendance` | `{congregation_id: UUID, session_id: UUID, expected_revision: int, marks: {<enrollment UUID>: 'present'\|'absent'\|'excused'\|'unmarked'}, finalize: bool}`; marks is the complete frozen roster map, not a partial patch | `{id: UUID, revision: int, status: 'open'\|'finalized', roster_frozen: true, attendance_count: int}` |

Create requests do not take `expected_revision`; if client-generated `id` already exists, the operation is accepted only through a matching still-valid receipt. Updates do not accept a replacement ID. Role replacement changes only the assigned slot, not either contact identity; the old contact remains saved and unassigned. Role uniqueness and eligibility rules are serialized by slot keys. Archive, status, close, cancel and attendance commands retain their distinct names so retries cannot be reinterpreted as another operation.

## Read contracts

RLS-scoped table reads may serve simple bounded lists and details. Use named read functions only for joins/aggregates where the source spec requires atomic scope filtering or hidden roster projections. Reads are read-only and derive caller identity from `auth.uid()`.

| Read function / query | Typed request | Exact result |
| --- | --- | --- |
| `ieadpe_ministry_list_directory` | `{scope: 'congregation'\|'supervision'\|'all', congregation_id: UUID|null, role_code?: RoleCode|null, name_prefix?: Text|null, limit: int 1..100, cursor: Text|null}`. `all` is ministry supervisor only; ordinary staff is pinned to their congregation. | `{items: [{id: UUID, name: Text, normalized_name: Text, scope: Text, congregation_id: UUID|null, role_code: Text|null, phone_e164: Text|null}], next_cursor: Text|null}`. No birth date or student fields. |
| `ieadpe_ministry_list_class_students` | `{congregation_id: UUID, class_id: UUID, limit: int 1..100, cursor: Text|null}` | `{items: [{student: Student, enrollment: Enrollment}], next_cursor: Text|null}`; membership filter is applied before paging. |
| `ieadpe_ministry_get_session_attendance` | `{congregation_id: UUID, session_id: UUID}` | `{session: Session, roster: [{enrollment_id: UUID, student_id: UUID, student_name: Text, status: AttendanceStatus}]}`; roster rows preserve historical display name. |
| `ieadpe_ministry_get_enrollment_progress` | `{congregation_id: UUID, enrollment_id: UUID}` | `{enrollment_id: UUID, present: int, absent: int, excused: int, denominator: int, percentage: number|null, rounded_percentage: int|null}` |
| `ieadpe_ministry_get_overview` | `{congregation_id: UUID|null}`; null means all ministry scopes and is ministry-supervision-only | `{students: int, classes: int, open_sessions: int, through_date: Date}` |
| `ieadpe_ministry_list_pending_sessions` | `{congregation_id: UUID|null, limit: int 1..100, cursor: Text|null}`; date cutoff is computed by server in America/Recife | `{items: [{id: UUID, class_id: UUID, class_name: Text, congregation_id: UUID, date: Date, topic: Text|null, status: 'open'}], next_cursor: Text|null}` |

All list cursors are opaque, stable and bound to caller-allowed scope, filters, ordering and last key. Default page size is 50, maximum 100. Apply scope before join, count, aggregation, or page limit. Unsupported filter combinations fail validation. Never expose Firebase document paths, private roster tables or internal receipts through generic query resources.

## Invariants and transaction lock order

1. Lock `access_versions` for actor and any affected bound user UIDs in sorted UID order; re-read and validate active ministry grants and requested scope. Grant mutation follows this same order.
2. Lock parent domain rows in deterministic type/UUID order: congregation, class, student, enrollment, session. Reject cross-congregation references even if a caller supplies valid UUIDs.
3. Lock uniqueness rows/keys in stable order: normalized contact/student/class key, role slot, active enrollment per student, class historical enrollment count, class/date session key. Unique constraints remain authoritative.
4. For attendance, lock class then session, validate expected session revision and session/class status, then read eligible enrollments in enrollment UUID order. If roster is not frozen, snapshot exactly date-eligible enrollment IDs and names. Require submitted marks keys to equal that roster exactly. Write roster, marks, session revision and receipt atomically.
5. Finalization requires nonempty roster, all entries marked present/absent/excused (unmarked prohibited), and session date <= server business date in `America/Recife`. Correcting finalized attendance keeps identical roster membership and all marks complete. Canceled sessions cannot be edited. Cancellation preserves rows and excludes session from progress.

Replay results use the convert receipt protocol. A stale revision, revoked grant, over-capacity attempt, duplicate active enrollment/date, altered frozen roster or invalid status rolls back every write. No PII or raw payload is placed in error text or receipt output.

## Composition-first Flutter ports

Keep pure `CalendarDate`, `CommonMetadata`, `Address` and enum validation separate from transport. A `MinistryRepository` composes `ContactRepository`, `StudentRepository`, `AcademicRepository` and `AttendanceRepository` adapters over the existing Supabase gateway; widgets do not call RPC directly. A command DTO carries `operationId`, stable record ID, expected revision where applicable, and a typed entity draft. A typed `MinistryResult<T>` exposes data or the existing safe `AppFailure` code (`validation`, `unauthenticated`, `forbidden`, `notFound`, `conflict`, `unavailable`, `unknown`). Existing convert repository and response semantics stay unchanged. There is no Firebase runtime, SDK type, path, or mutable JSON map in the domain layer.

## INVEST stories and readiness

| Story | INVEST evidence and acceptance | Definition of Ready / Done |
| --- | --- | --- |
| As ministry staff assigned to C, I can maintain a student in C so the congregation record is accurate. | Independent; valuable; estimate small; scoped to one record; accepted by `save_student` and archive RPCs. Create needs only name and C; malformed answer/date/address, wrong scope, stale revision, archived-with-active-enrollment, and baptism contradiction are rejected; archive/restore keeps history. | DoR: model/nullability and scope rules above, synthetic fixture, request/return schema. DoD: boundary validation and transaction defined, focused valid/invalid partition checks, no PII in logs. |
| As a teacher/staff member, I can enroll and record attendance so progress reflects verified lessons. | Independent of UI redesign; valuable; estimateable; constrained by class/enrollment/session; accepted by enrollment + attendance transactions. Only one active enrollment/student; 100 historical rows; roster frozen once; exact complete roster; finalized progress excludes excused/unmarked/open/canceled. | DoR: role/scope and date rules fixed; transaction sequence and return shape agreed. DoD: race orders, cap boundaries 99/100/101, replay/stale revision and rollback partitions defined. |
| As ministry supervision, I can review and manage ministry records across congregations so ministry work is coordinated. | Independent from campaign supervision; valuable; estimateable; globally scoped only with `ministry_supervision`; accepted by denied campaign-only access and scoped/global read partitions. | DoR: explicit grant is provisioned and separate from campaign role; scope queries and safe projection defined. DoD: global/local/campaign-only/inactive assertions defined and budgeted. |
| As a campaign registrar, I can register an unassigned convert without exposing ministry data so intake remains open and private. | Independent from ministry enrollment; valuable; small; assignment absent; accepted by convert contract: create allowed, all ministry/student reads and commands denied. | DoR: journey promotion remains separate. DoD: contract verified against existing convert RPC and boundary documented for task 4/5 consumers. |

## Unresolved product choices

No blocking field or lifecycle choice remains for the ministry port based on captured source behavior and the accepted combined-app design. The one consequential decision is resolved conservatively: campaign supervision grants do not imply ministry supervision; a trusted operator must grant both separately when both are intended. Any later decision to merge these authorities requires an explicit spec and access-test change before schema implementation.
