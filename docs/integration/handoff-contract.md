# Convert-to-Student Handoff Contract

Status: implementation contract for Unified Journey Plan, Task 1. This document fixes the authority, lifecycle, ownership, and transaction boundary required before the linking migration is written. It does not claim that the RPC or link schema exists.

## Actors and permissions

| Actor | May discover/review | May promote | Returned information |
|---|---|---|---|
| Authenticated registrar with no campaign or ministry grant | No convert directory/detail and no student directory | No | None |
| `campaign_direction` for congregation C | Full campaign records in C under the convert contract; no ministry/student data by virtue of this grant | No, unless separately granted ministry access | Campaign projection only |
| `campaign_supervision` | Full campaign records under the convert contract; no ministry/student data by virtue of this grant | No, unless separately granted ministry access | Campaign projection only |
| `ministry_staff` for congregation C | Ministry student records in C; may request the minimal referral projection for a convert already assigned to C | Yes, for a non-deleted convert assigned to C, when actor has the active ministry grant for C | Minimal referral plus link/student IDs and status; never campaign history, photo, visit events, worship type, gender, age, or campaign reports |
| `ministry_supervision` | Ministry records in explicitly selected authorized congregation(s); no campaign data by virtue of this grant | Yes, only for an assigned convert in a congregation explicitly selected and authorized by the active ministry-supervision grant | Same minimal referral and result as ministry staff |
| Trusted admin allowlist | Both modules through their respective server authority | Yes for an explicitly selected congregation through the trusted admin capability; no campaign data is added to the result | Same minimal referral and result |

Grants are independent. Campaign supervision never implies ministry supervision, and ministry supervision never implies campaign supervision. An actor with multiple active grants gets the union of their explicitly granted module rights. Account roles, emails, contact titles, and client-supplied claims do not grant access. A referral projection is a separately authorized server read: it must not be obtained through a direct join or a client-side query of `converts`.

## Lifecycle decision

The source convert record has `deleted_at`, `is_discipleship_completed`, and `is_deviated`; there is no separate `completed` or `deviated` status enum. Promotion applies this matrix:

| Convert state at promotion | New link | Policy |
|---|---:|---|
| `deleted_at IS NULL`, discipleship active or not started | Allowed if assigned congregation and actor scope match | Link without changing campaign state |
| `deleted_at IS NULL`, `is_discipleship_completed = true` | Allowed if assigned congregation and actor scope match | Historical continuity; do not reopen or rewrite campaign history |
| `deleted_at IS NULL`, `is_deviated = true` | Allowed if assigned congregation and actor scope match | Historical continuity; do not reopen or rewrite campaign history |
| `deleted_at IS NOT NULL` | Denied for a new link | Return a safe terminal/deleted failure; do not reveal the deleted record to an actor lacking campaign access |
| Already linked to the same student | Idempotent replay or safe “already linked” outcome | Never create a second student or link |
| Already linked to another student | Denied with conflict | Do not disclose the linked student's identity unless the actor has student scope for that congregation |

An existing link is durable if campaign status later changes or the convert is soft-deleted. It remains visible only through each module's separately authorized projection. Deletion does not cascade into the student or ministry history. Promotion does not reopen campaign lifecycle actions, change visit counts, create campaign events, or alter historical reports.

## Field ownership and snapshot provenance

| Data | Canonical owner | Promotion behavior |
|---|---|---|
| Convert name, phone, source address and all campaign fields/events/photos | Convert module | Remain unchanged and are never synchronized from student edits |
| Student education, marital status, baptism answers, enrollment and attendance | Ministry student/module | Remain student-owned; never inferred from conversion or copied from campaign events |
| Name, phone and address on a newly created student | Student snapshot, sourced from convert | Copy the current convert name, phone and address once, recording source convert ID and promotion time as provenance on the link. Convert address is a legacy free-text value and is copied as `address.street`; the remaining structured address members stay null. The UI labels these values as an initial snapshot. |
| Name, phone and address on an explicitly selected existing student | Existing student record | Do not overwrite any student field. The reviewer inspects differences and explicitly confirms the link. Provenance on the link records the source convert and promotion time, not field equality. |

Later edits never silently synchronize in either direction. The linked UI must identify which record owns each editable field and distinguish a source snapshot from current convert details. No enrollment, baptism inference, historical event rewrite, or name-only auto-merge occurs during promotion.

## Server command contract

The only promotion entry point is `public.ieadpe_promote_convert_to_student(operation_id uuid, payload jsonb) returns jsonb`. PostgreSQL owns identity, authorization, assignment checks, lifecycle checks, record creation/linking, provenance, receipt replay, and the atomic transaction. The verified actor is `auth.uid()`; actor UID, role, timestamp, and revision are never accepted from the client.

The minimal referral is a separate bounded read: `public.ieadpe_ministry_list_convert_referrals(request jsonb) returns jsonb`. Its strict request is `{congregation_id: UUID, limit: int 1..100, cursor: Text|null}`. It requires an active ministry grant for the scope or the trusted admin capability with the congregation explicitly selected, and returns `{items: [{convert_id, congregation_id, name, phone, address, conversion_date}], next_cursor}`. The query excludes soft-deleted and unassigned converts and applies congregation scope before ordering/paging. `address` is the source free-text value. It does not return lifecycle flags, campaign history/events, photos, worship type, gender, age, visit counts, or discipleship notes. The query has no direct table-read path and its cursor is opaque and bound to actor/scope/order. Terminal-but-not-deleted records remain eligible for historical promotion; the referral projection does not reveal terminal campaign state.

Strict payload allow-list:

```text
{
  "convert_id": UUID,
  "congregation_id": UUID,
  "student_id": UUID | null
}
```

`student_id: null` requests creation of a new student. A UUID requests linking to the exact student the authorized reviewer selected after searching the same congregation's ministry records. There is no server-side fuzzy match or name-only merge. `operation_id` is created once by the client before submission and reused unchanged after timeout, response loss, or retry. The payload is canonicalized and bound to the durable receipt; the same actor/operation/payload returns the original safe result after current authorization is revalidated, while altered payload under that operation ID fails with a conflict.

Successful response is exactly:

```json
{"convert_id":"UUID","student_id":"UUID","congregation_id":"UUID","status":"linked"}
```

The response contains no name, phone, address, campaign fields, role, actor identity, receipt digest, or exception text. A safe typed failure is returned for invalid payload, unauthenticated/forbidden scope, unassigned convert, soft-deleted convert, stale/ineligible candidate, operation conflict, or unavailable backend. Failed commands leave no student, link, snapshot, or receipt partial write; the client retains its draft and operation UUID.

### Authorization and lock order

1. Require non-null `auth.uid()` and validate operation UUID and the exact payload shape before any protected disclosure.
2. Lock the actor's access-version row using the established `private.lock_access` protocol; read active ministry grants and the trusted admin capability after acquiring the lock. A campaign grant alone is insufficient.
3. Lock the selected congregation row, then the convert row, in that order. Verify that its assigned congregation equals `congregation_id` and that the actor has an active ministry grant covering that scope (including explicit congregation selection under global ministry supervision), or has the trusted admin capability. A campaign grant alone is insufficient.
4. Check for an existing receipt for `(actor_uid, operation_id)`. A matching command and canonical payload replays its result after current authorization and scope checks, even if the linked convert was soft-deleted after the original commit; changed command/payload is rejected. Replay performs no new lifecycle transition.
5. For a new operation only, require `deleted_at IS NULL`. If a candidate `student_id` was supplied, lock that row and require that it exists, is in the selected congregation, and is not already linked to another convert. Never return candidate details or existence across congregation scope. If null, create a student and copy only the declared initial snapshots.
6. Insert the unique convert-to-student link and provenance atomically with any new student and the safe mutation receipt. A unique constraint on `ministry_students.convert_id` is authoritative for competing calls. A loser resolves to the existing matching receipt/link or a safe conflict; it never creates a second student.

The migration owning this contract must align lock details with the existing convert and ministry access-version implementation and add direct read/write denial tests. The RPC is `SECURITY DEFINER` with an empty `search_path`, executable only by `authenticated`; `PUBLIC` and `anon` have no execute. RLS/direct-table grants must not let the client bypass the RPC or join convert rows to students.

## Transfer and congregation assignment

An unassigned convert (`congregation_id IS NULL`) cannot be promoted. An authorized campaign user must assign it through the existing campaign edit contract before promotion. The promotion RPC does not accept a replacement congregation and cannot itself assign one. After linking, congregation transfer is unsupported: do not change either linked record's scope or move the link. A future transfer requires a separately specified, authorized, atomic operation that preserves both histories and repairs scope-bound references.

## Required verification partitions

The implementation must prove: assigned versus unassigned; active/not-started, completed and deviated versus soft-deleted; same-scope existing student explicitly selected versus no candidate; cross-scope/nonexistent/already-linked candidate denied without disclosure; campaign-only or revoked grant denied; exact retry and response-loss replay; altered payload under same operation rejected; two competing requests in both commit orders produce one student/link; failure rolls back all writes; and direct client joins/reads of referral or link internals are denied. No test should assert a name-only auto-merge.
