# Ministry completion contracts

Status: C1 evidence-backed local contract draft, based on HEAD `a1f326b9f049ba7ea0b9fbcb48f7aafdc7136fbd`. Changed paths for C1: this file, `docs/verification/ministry-task-manifest.md`, and a one-paragraph pointer in `docs/integration/ministry-contracts.md`. Hosted schema, functions, grants, data, backups, and migration ledger are **unknown**. Nothing here is evidence of hosted state.

## Evidence labels and gate

- **Confirmed local fact** means present in this checkout or inspected source revision. Main SQL evidence is migrations `202610140011`–`202610140018` and `202610180003_base44_unified_access.sql`; original Firebase source is Git revision `4acb563`; retained Base44 source is under `reference/base44/base44/`.
- **Plan-confirmed requirement** means required by `docs/superpowers/specs/2026-10-18-ministry-production-completion-design.md` and the execution plan, not yet implemented or hosted.
- **Proposed assumption** is a recommended target policy, not an existing fact or user approval.
- **Unresolved decision** must be settled before the affected implementation slice.

The current local RPC envelopes below are preserved as evidence. New canonical-person and contact/access interfaces are not present locally; do not invent a hosted signature or dispatch dependent code until the open decisions below are resolved and a forward contract is reviewed.

## Table and field ownership

| Owner | Confirmed local fields and responsibility | Contract direction |
| --- | --- | --- |
| `auth.users`, `private.admin_allowlist`, `public.user_access` | Auth UID; trusted technical-admin allowlist; normalized email, nullable bound `user_id`, campaign role, optional congregation. `ieadpe_get_scope` binds only a verified Auth email. | Access is server-owned. A title, contact row, caller role, or email string alone never authorizes. Revocation removes the assignment and increments access version. |
| `public.ministry_grants` | Legacy local table from `202610140011`; it remains in schema. Its old helpers are superseded: `202610180003` defines Ministry access through the global-manager and `user_access` helpers. | Do not treat this table or old independent-grant text in the historical contract as current authority. Hosted definitions remain unknown. |
| `public.ministry_contacts`, `public.ministry_role_slots` | Congregation/supervision contact directory, one of 12 `role_code` values, name, normalized name, phone, birth date, archive timestamp; slot binds a role to a contact and scope. | Organizational role is display/assignment data only, never login access. Replacing a slot retains both contact records. |
| `public.converts`, `public.convert_events` | Convert-specific name/contact and required conversion date, worship type, landmark and gender; visit/discipleship flags and event history. Current create validates conversion-specific fields. | Do not use convert creation to store a non-convert student or fabricate conversion/event data. Keep actual visit facts separate from attendance. |
| `public.ministry_students` | Required: `congregation_id`, `name`, `normalized_name`. Nullable: `phone_e164`, `birth_date`, structured `address` (`street`, `district`, `city`, `postal_code`, `state_code`), `education`, `marital_status`, `new_convert`, `water_baptized`, `wants_baptism`, `archived_at`. Null answers mean unknown. | Academic/person extension currently duplicates identity fields. New canonical edits must not leave duplicate editable copies. |
| `public.ministry_classes` | Congregation, name, optional teacher contact, start/end dates, `active/completed/archived`. | Class owns its schedule and teacher reference; same-congregation FK is enforced locally. |
| `public.ministry_enrollments` | Congregation, student/class IDs, start/end dates, `active/completed/withdrawn`; one active enrollment per student; historical class capacity is 100. | Close changes enrollment state and retains its history; it does not mean graduation, deviation, baptism, or archival. |
| `public.ministry_sessions`, `ministry_session_roster`, `ministry_attendance` | Class/date/topic/status, frozen lesson roster and student-name snapshot, marks `present/absent/excused/unmarked`. | Attendance owns lesson participation. Only finalized, non-canceled present marks feed the proposed shared follow-up projection. Historical roster snapshots remain immutable evidence. |

Shared Ministry rows have UUID identity, revision, created/updated timestamps and actor, and nullable `legacy_firebase_id` for source lineage. Source IDs are text; never cast Firebase IDs to UUID. `ministry_students.convert_id` is currently nullable and unique, with paired `promoted_at` and immutable `{name,phone,address}` snapshot. The promotion flow copies fields once; later edits are independent. This is a local compatibility link, not canonical identity or propagation.

### Canonical person identity and legacy mapping

**Plan-confirmed requirement:** one canonical identity/contact source; a student academic extension is created or reused automatically at enrollment; an explicit, unique link is required; never merge by name; unresolved legacy rows remain preserved and reviewable. Enrollment and effective follow-up changes are atomic. The non-new-convert path must not invent conversion fields or a convert event.

**Proposed assumption:** introduce a neutral person record as the canonical name/contact/address owner, with at most one optional convert-specific profile and at most one optional student academic extension per person. Keep student/class/enrollment IDs and academic history stable. Existing records link only by reviewed stable IDs or explicit operator match; unmatched and ambiguous records stay unlinked. Current `convert_id`/snapshot should become a compatibility mapping and cease being an editable source of person fields. New convert registration creates person + convert profile/event; non-new-convert registration creates person without a convert profile; enrollment creates/reuses the academic extension. Shared field edits update the canonical person once; academic and convert-specific answers/events remain with their owners.

**Unresolved decision — blocks P1/P2:** confirm this neutral-person-table ownership and optional-profile cardinality, including the migration treatment of existing `ministry_students` and `converts`. Current constraints cannot safely be treated as a canonical identity model; this decision changes schema, mutation RPCs, and reconciliation.

Legacy source mapping (source structure, not proof of production data):

| Source at Firebase revision `4acb563` | Local owner / handling |
| --- | --- |
| `congregations/{id}` | `public.congregations`; explicit ID crosswalk. |
| `directory/{contactId}`, `supervisionContacts/{contactId}`, `congregations/{cid}/contacts/{contactId}` | `ministry_contacts`; retain source ID in `legacy_firebase_id`. |
| `supervisionRoleSlots/{id}` | `ministry_role_slots`, linked only after contact/scope/role validation. |
| `congregations/{cid}/students/{studentId}`, `congregations/{cid}/classes/{classId}`, `congregations/{cid}/enrollments/{enrollmentId}`, `congregations/{cid}/sessions/{sessionId}` | `ministry_students`, `ministry_classes`, `ministry_enrollments`, `ministry_sessions`; preserve IDs, state and dates. |
| Session records use `congregations/{cid}/sessions/{sessionId}`. The datastore path helper does not define separate roster/attendance paths. | `ministry_session_roster` and `ministry_attendance`; preserve frozen names and marks, and determine their exact source representation from a reviewed export before import. |
| Firebase users/claims | No automatic grant mapping. Reconcile verified identity and explicit scope to `user_access`; never infer access from a role title. |
| Base44 `Convert` and `ConvertEvent` | Convert-specific profile and event history. `last_visit_date`, visit count and manual flags remain actual visit/manual history; attendance is a separate fact. |
| Base44 `UserAccess` | Existing `public.user_access` email/role/congregation assignments; preserve multiple scopes and bind to Auth only by verified email. |

The original Firebase code is an implementation reference, not a production export. The Base44 `Convert` entity requires `landmark`, `gender`, `conversion_date`, and `worship_type`; those required fields are not valid defaults for a student-only person.

## Current RPC contracts (local only)

All current wrappers are authenticated `SECURITY DEFINER` functions; callers supply neither actor nor authority. Mutation JSON is strict-key validated. All `ieadpe_ministry_*` reads take one `request jsonb` and return `jsonb`; all commands take `(operation_id uuid, payload jsonb)` and return `jsonb`.

### Scope, access, and convert handoff

| RPC | Arguments | Result / local behavior |
| --- | --- | --- |
| `ieadpe_get_scope()` | none | `{is_admin:boolean,is_supervision:boolean,congregation_ids:uuid[],ministry_supervision:boolean,ministry_congregation_ids:uuid[]}`. Global Ministry access is technical admin OR `Membro da supervisão das campanhas`; local access is `Membro da direção da campanha` for active congregations. |
| `ieadpe_save_access(op,payload)` | `{user_email,role,congregation_id}`; update may include `id`. Supervision requires null congregation; direction requires an active congregation. | `{id}`. Global manager only. Verified-email binding is deferred until `ieadpe_get_scope`; duplicate role/scope assignments are constrained. |
| `ieadpe_revoke_access(op,payload)` | `{id}` | `{id}`; deletes that assignment. Global manager only. No `active` flag is used in `user_access`. |
| `ieadpe_ministry_list_congregations({limit,cursor})` | limit 1–100; optional cursor | `{items:[{id,name}],next_cursor}`; active authorized congregations; global supervision can choose scope. |
| `ieadpe_ministry_list_convert_referrals({congregation_id,limit,cursor})` | congregation and limit required; cursor nullable | `{items:[{convert_id,congregation_id,name,phone,address,conversion_date}],next_cursor}` for unlinked, undeleted convert rows in scope. |
| `ieadpe_ministry_list_convert_student_candidates({congregation_id,name_prefix,limit,cursor})` | congregation and limit; nullable prefix/cursor | `{items:[{student_id,name,phone,address}],next_cursor}` for unlinked, unarchived academic rows. |
| `ieadpe_promote_convert_to_student(op,payload)` | `{convert_id,congregation_id,student_id}` where `student_id` is UUID or null | `{convert_id,student_id,congregation_id,status:'linked'}`. Null creates a student row; existing ID links that row. It snapshots fields and does not enroll. |
| `ieadpe_create_convert(op,payload)` | current create requires `name,landmark,gender,conversion_date,worship_type`; other convert fields optional | `{id}`. Not suitable for non-convert student registration. `ieadpe_edit_convert(op,payload)` also returns `{id}`. |

### Ministry reads

| RPC | Request keys | Result |
| --- | --- | --- |
| `ieadpe_ministry_list_directory` | `{scope,limit,congregation_id?,role_code?,name_prefix?,cursor?}`; scope `congregation/supervision/all` | `{items:[{id,name,normalized_name,scope,congregation_id,role_code,phone_e164}],next_cursor}`. `all` and supervision require global authority. |
| `ieadpe_ministry_list_students` | `{congregation_id,name_prefix,limit,cursor}`; nullable prefix/cursor | `{items:[{id,name,phone_e164,convert_id,revision}],next_cursor}`. |
| `ieadpe_ministry_list_classes` | `{congregation_id,status,limit,cursor}`; nullable status/cursor | `{items:[{id,name,status,start_date,end_date,revision}],next_cursor}`. |
| `ieadpe_ministry_list_class_students` | `{congregation_id,class_id,limit,cursor}`; nullable cursor | `{items:[{student:{id,congregation_id,name,normalized_name,phone_e164,birth_date,address,education,marital_status,new_convert,water_baptized,wants_baptism,archived_at,revision,created_at,updated_at,updated_by},enrollment:{id,congregation_id,student_id,class_id,start_date,end_date,status,revision,created_at,updated_at,updated_by}}],next_cursor}` for active enrollments. |
| `ieadpe_ministry_get_session_attendance` | `{congregation_id,session_id}` | `{session:{id,congregation_id,revision,date,topic,status,roster_frozen,lesson_index,lesson_part,lesson_finished,...},roster:[{enrollment_id,student_id,student_name,status}]}`. |
| `ieadpe_ministry_get_enrollment_progress` | `{congregation_id,enrollment_id}` | `{enrollment_id,present,absent,excused,denominator,percentage,rounded_percentage}`. Only finalized sessions count; denominator is present + absent; zero denominator yields null percentages. |
| `ieadpe_ministry_get_overview` | `{congregation_id}`; UUID or null | `{students,classes,open_sessions,through_date}`. Null is global supervision only. |
| `ieadpe_ministry_list_pending_sessions` | `{congregation_id,limit,cursor}`; UUID or null, limit 1–100 | `{items:[{id,class_id,class_name,congregation_id,date,topic,status:'open'}],next_cursor}`; open sessions through `America/Recife` business date. |

Cursor handling is RPC-specific. `ieadpe_ministry_list_congregations` uses a raw UUID `id` cursor. `ieadpe_ministry_list_directory` signs its cursor and binds UID plus scope/filter/last-key values. Other paged Ministry reads use the signed Ministry cursor helper, bound to UID, resource and the applicable congregation/class/status/prefix filters plus last key. Non-paged detail reads have no cursor. Invalid or mismatched cursors fail; reads are bounded to 100 rows.

### Ministry commands

`expected_revision` is mandatory for updates/archival/status/close/cancel commands as shown; create commands use a caller-generated UUID `id`. Omitted optional fields on `save_student` update preserve the current field; explicit null clears nullable values.

| RPC | Exact payload keys | Result |
| --- | --- | --- |
| `ieadpe_ministry_save_contact` | Create `{id,scope,congregation_id,name,role_code,phone_e164,birth_date}`; nullable values are explicit. Update adds `expected_revision`. | `{id,revision}` |
| `ieadpe_ministry_set_contact_archived` | `{id,scope,congregation_id,archived,expected_revision}` | `{id,revision}` |
| `ieadpe_ministry_replace_role_holder` | `{id,scope,congregation_id,role_code,previous_contact_id,expected_revision,previous_expected_revision}` | `{id,revision,previous_contact_id,previous_revision}`; updates slot and both contact revisions. |
| `ieadpe_ministry_save_student` | Create `{id,congregation_id,name}` plus optional `phone_e164,birth_date,address,education,marital_status,new_convert,water_baptized,wants_baptism`; update adds `expected_revision`. `address` permits only the five structured keys above. | `{id,revision}` |
| `ieadpe_ministry_set_student_archived` | `{id,congregation_id,archived,expected_revision}` | `{id,revision}` |
| `ieadpe_ministry_save_class` | `{id,congregation_id,name,teacher_contact_id,start_date,end_date}`; nullable teacher/end date; update adds `expected_revision`. | `{id,revision}` |
| `ieadpe_ministry_set_class_status` | `{id,congregation_id,status,expected_revision}` | `{id,revision}` |
| `ieadpe_ministry_enroll_student` | `{id,congregation_id,class_id,student_id,start_date}` | `{id,revision}` |
| `ieadpe_ministry_close_enrollment` | `{id,congregation_id,status,end_date,expected_revision}`; status `completed` or `withdrawn` | `{id,revision}` |
| `ieadpe_ministry_create_session` | `{id,congregation_id,class_id,date,topic}`; nullable topic | `{id,revision,status:'open'}` |
| `ieadpe_ministry_cancel_session` | `{id,congregation_id,expected_revision}` | `{id,revision,status:'canceled'}` |
| `ieadpe_ministry_save_attendance` | `{congregation_id,session_id,expected_revision,marks,finalize}`; marks must exactly cover frozen roster with `present/absent/excused/unmarked` | `{id,revision,status:'open'|'finalized',roster_frozen:true,attendance_count}` |

### Error, revision, and replay contract

Local SQL raises named messages, but outer handlers rewrite some before PostgREST can expose them. These are the **externally emitted local messages** after those handlers:

| Command family | Emitted messages beyond shared `unauthorized` (`42501`), `forbidden` (`42501`), `invalid_payload` (`22023`) and `operation_conflict` (`22023`) |
| --- | --- |
| Contact save/archive | `invalid_scope` (`22023`), `invalid_congregation` (`22023`), `contact_not_found` (`22023`), `stale_revision` (`40001`), `contact_archived` (`22023`), `role_slot_conflict` (`40001`), `registry_conflict` (`23505`), `registry_invalid` (`22023`) |
| Role replacement | `invalid_payload`, `forbidden`, `contact_not_found`, `stale_revision`, `role_slot_conflict`, plus mapped `registry_conflict` / `registry_invalid` |
| Student save/archive | `invalid_congregation` (`22023`), `student_not_found` (`22023`), `stale_revision` (`40001`), `student_archived` (`22023`), `registry_conflict` (`23505`), `registry_invalid` (`22023`) |
| Academic commands | `invalid_congregation` (`22023`), `invalid_teacher` (`22023`), `class_not_found` / `student_not_found` / `enrollment_not_found` / `session_not_found` (`22023`), `stale_revision` (`40001`), `academic_conflict` (`23505`), `academic_invalid` (`22023`) |
| Access save/revoke | `invalid_congregation` (`22023`), `access_not_found` (`22023`) |
| Convert/student promotion | `convert_unavailable` (`22023`), `candidate_unavailable` (`22023`), `convert_already_linked` (`22023`) |
| Read requests | `invalid_request`, `invalid_limit`, `invalid_cursor`; by RPC also `invalid_scope`, `invalid_role`, `invalid_filter`, `invalid_prefix`, `invalid_status`, `class_not_found`, `session_not_found`, `enrollment_not_found` (validation/not-found messages use `22023`) |

**Internal SQL causes, not emitted messages:** `ministry_registry_command` maps unique violations to `registry_conflict` and check/FK violations to `registry_invalid`. Thus internal `record_exists`, `contact_already_assigned`, `role_holder_assigned`, `invalid_role_holder`, `active_enrollment`, and similar 23505/23514/23503 exceptions may be replaced by those wrapper messages. `contact_archived` and `student_archived` use 22023 and escape unchanged. `ministry_academic_command` maps unique violations—including internal `record_exists`—to `academic_conflict` and check/FK violations—including raised `class_not_active`, `class_capacity`, `enrollment_closed`, `session_finalized`, `session_canceled`, `roster_mismatch`, and `attendance_incomplete` messages—to `academic_invalid`. Those internal names do not escape the SQL handler. Raw causes retain their original SQLSTATE only before mapping; emitted mapping SQLSTATEs are shown above. See the final handlers in migrations `202610140013_ministry_registry_commands.sql` and `202610140014_ministry_academic_commands.sql`.

The Flutter gateway normalizes backend failures to local categories such as `permission`, `invalid`, `backend`, and `unavailable`; clients must not display raw server text as a trusted interface.

Mutations derive actor from `auth.uid()`, lock access before authorization, then check the receipt. `private.mutation_receipts` keys receipt by actor + operation UUID; exact same command and payload hash returns the stored result; changed command/payload with that operation UUID raises `operation_conflict`. Authorization precedes receipt disclosure. Create IDs are supplied UUIDs; each successful update increments server revision, and stale expected revisions fail instead of overwriting. Current ministry payload hash is SHA-256 over PostgreSQL `jsonb::text`; no receipt TTL is established by these migrations.

## Routes and return context

**Confirmed local routes:** `lib/routing/router.dart` allowlists only `/register`, `/home`, `/converts`, `/admin`, `/ministry`, `/ministry/team`, `/ministry/students`, `/ministry/classes`, `/ministry/attendance`, `/ministry/handoff`. It has no query or return-context contract. `lib/app.dart` keeps selected congregation in app state; current handoff receives congregation and verified `canPromote` scope. Invalid route falls back to `/register`.

**Proposed assumption:** new student/detail/enrollment workflows pass typed in-memory `{congregation_id, class_id?, return_to?, person_id?}` context. `return_to` must be an exact safe allowlisted route; validate UUIDs and re-check access on resume. No person name, phone, email, access token, or other PII in URL/query. Do not ship route parameters until page ownership and a route parser are reviewed.

## Read/write authority matrix

| Actor | Current server authority | Product contract target |
| --- | --- | --- |
| Unauthenticated | Denied by Auth/RPC checks and RLS. | No protected reads or writes. |
| Technical admin allowlist | Global manager; all active congregation scopes; can manage `user_access`. | Global Ministry read/write and access management; allowlist remains outside Team editing. |
| `Membro da supervisão das campanhas` | Global manager; all active Ministry scopes; can manage `user_access`. | Global supervision, explicit congregation selection for scoped work, and access management. |
| `Membro da direção da campanha` | Ministry and campaign access for each assigned active congregation; cannot grant/revoke access. Current Ministry commands do not check organizational title. | Scoped read/write of contact and academic workflow. Whether this role may edit contact details is unresolved below. |
| Registrar without protected scope | Existing convert registration command only; no protected Ministry read. | May create convert records through existing conversion fields; must not fabricate conversion data for a student-only person. |
| Ministry contact / role holder / teacher title | No authority from title or `role_code`. | No authority unless an explicit `user_access` assignment exists. |

Direct business table privileges are revoked; reads go through scoped functions. Current SQL permits scoped direction and global manager writes for ministry records. There is no per-function teacher/organizational-role write gate. The `ministry_grants`-based policy in earlier migrations and `ministry-contracts.md` is superseded locally by `202610180003_base44_unified_access.sql`; hosted state must be inspected before release.

## Lifecycle and policy rows

The first column records local behavior; the second is the **proposed product target** derived from the plan/spec and original Firebase/Base44 evidence. Any conflict is a forward-migration gap, never a claim about hosted behavior.

| Topic | Current local fact | Proposed target and status |
| --- | --- | --- |
| Contact archive / role | Contact archive is blocked while assigned a live role slot; internal `role_holder_assigned` is wrapped as externally emitted `registry_invalid` (`22023`). Unarchive is supported. Replacement keeps old contact and changes slot. | Archive directory record, retain history; changing login access is a separate explicit revoke. **Plan-confirmed requirement.** |
| Access revoke / contact link | `user_access` delete revokes authority; no contact FK exists. | One Team workflow links validated contact and access assignment but keeps distinct role and access fields. Revoke access without archiving a historical teacher. Use one transaction or explicit recoverable pending state. **Open:** choose transactional boundary and duplicate-email conflict UX. |
| Person field propagation | Student/conversion identity is duplicated; convert link snapshot is immutable and edits do not propagate. | Canonical person owns shared fields; profile/academic extension reads join it. No name merge or silently copied editable snapshot. **Proposed; P1 blocker.** |
| Student archive | Blocked while any active enrollment exists; internal `active_enrollment` is wrapped as externally emitted `registry_invalid` (`22023`). Can restore. | Preserve academic history and require closing enrollment first; do not delete person or convert events. **Plan-confirmed requirement.** |
| Class lifecycle | Local status command accepts `active/completed/archived` without transition guards. | Preserve Firebase rules: active→completed requires zero active enrollments and no open sessions; active→archived requires empty enrollment/session history; completed→archived is allowed and retains history; completed never reopens; archived may reactivate. Class start/end dates freeze after any enrollment or session exists; active classes still allow name/teacher edits. Completed/archived classes are read-only except these status transitions. **Forward-migration gap.** |
| Teacher | Local class save requires an active same-congregation contact, but does not verify `role_code='teacher'`. | Require active same-scope teacher-role contact; title still grants no login. **Forward-migration gap.** |
| Enrollment | Local enrollment requires active class/unarchived student, one active enrollment per student, historical class cap 100. Local SQL does not check class date bounds. Close accepts `completed/withdrawn`, end ≥ start. | Keep one active enrollment; preserve completed/withdrawn history. Start/end stay within class period; close end cannot precede the latest frozen roster date for that enrollment. Closure affects only enrollment contribution; never infer completion, deviation, baptism, or conversion. **Forward-migration gap.** |
| Discipleship/manual state | Current Base44 flags and event history are on convert; Ministry enrollment has no atomic shared-person projection. | Active enrollment contributes effective in-discipleship atomically; referral alone does not. Preserve manual history/provenance. Closing/withdrawal removes only enrollment contribution; keep any independent manual active state. Do not invent completion/deviation/baptism. **Plan-confirmed requirement; precedence of legacy manual state needs decision.** |
| Attendance/cancel | Local roster freezes on first attendance save; finalization requires full nonempty roster and date ≤ `America/Recife` today. Current SQL allows a finalized same-roster correction only with `finalize=true`; cancel rejects finalized sessions. Progress counts finalized present + absent; excused separate. | Finalized non-canceled present satisfies follow-up on lesson date, not a home visit or visit count. Finalized marks are read-only; explicit cancellation of open/finalized session retains history and removes only that session's projection. Replaying the same operation returns its receipt. **Plan-confirmed requirement; local code gap.** |
| Backdating / session period | Local session creation and enrollment do not enforce full class-period constraints; finalization rejects future date. | Session date must be inside class period; live (not canceled) class/date pair is unique; canceled session is retained and releases that date. A backdated valid lesson uses lesson date for follow-up. Future session may be drafted but cannot finalize before `America/Recife` business date. **Forward-migration gap.** |
| Reassignment / transfer | Local FKs scope rows to congregation; no transfer operation exists. | Never silently move historical enrollments/classes. Require explicit reviewed transfer preserving snapshots/history, or reject cross-congregation action. **Proposed assumption.** |
| Reminder policy | Base44 source uses 1 day before first contact, 7 days after contact outside discipleship, 30 days in discipleship; manual deviation after ≥3 actual visits and manual completion after 90 days from start. | Keep reminders and manual thresholds. Qualifying attendance clears initial-contact/30-day follow-up but does not increment visits or unlock deviation. Completion guard uses the earliest evidenced qualifying discipleship start; never manufacture a missing start date. If no verified start exists, completion remains unavailable until one is verified. **Plan-confirmed requirement.** |

## Decisions required before affected implementation

1. **Canonical identity (P1/P2):** approve or replace the proposed neutral person owner and 0/1 profile cardinalities. This cannot be decided by local schema because current tables duplicate fields and only support immutable snapshots.
2. **Team (E1/E2):** confirm optional email for directory-only contacts and required verified email when login access is enabled; confirm whether local direction users may edit contact fields. Proposed defaults: optional directory email, verified-email binding for access, local contact maintenance allowed, global-manager-only access changes.
3. **Access/contact atomicity (E1):** choose atomic contact+grant write versus an explicit recoverable pending state, and approve duplicate/conflicting verified-email reassignment handling. Existing `user_access` has no contact link or pending state.
4. **Legacy discipleship precedence (F1):** confirm whether any retained manual active flag remains effective after the last enrollment closes. Proposed rule is yes only when a separate, provenance-preserving manual state exists; enrollment itself never manufactures manual completion/deviation.

Until these decisions are settled, C1 is complete as a source-backed local interface/policy record, but the affected P1/P2/E1/F1 code slices remain gated. No hosted contract is asserted.
