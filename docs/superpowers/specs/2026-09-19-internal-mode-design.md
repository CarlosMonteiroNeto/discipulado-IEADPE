# Discipulado IEADPE — Internal-mode redesign (no Cloud Functions)

## Context

The application was built "functions-first": every mutation and several read
projections run as authenticated callable Cloud Functions (`functions/`,
~6k LOC plus ~7.9k LOC of tests), and `firestore.rules` deliberately denies
every client write (`allow write: if false`).

The deployment destination is the real Firebase project `discipulado-ieadpe`
on the **Spark (free) plan**. Gen2 callable functions (the only kind this
codebase uses) require the **Blaze** plan, which the application owner has
explicitly declined. This redesign keeps the application fully functional on
Spark by moving the mutation and aggregation logic into the Flutter client and
moving the authorization matrix into `firestore.rules` — which runs on the
Google edge and is free on Spark.

`functions/` and its test suite are retained in the repository as the
canonical statement of the original invariants, but functions are **never
deployed**.

## Decisions (resolved with the owner)

1. No Blaze, no billing. The app runs against Spark free quotas (50k
   reads/day, 20k writes/day, 20k deletes/day, 1 GiB storage).
2. Profile/role authorization lives in `firestore.rules` (server-side, free),
   not only in the app. In-app gating is UX only.
3. The Flutter client performs validated, role-scoped writes directly against
   Firestore through a new transport that replaces callable invocation.
4. Revision-based optimistic concurrency is **kept**, implemented with client
   Firestore transactions (`runTransaction`).
5. Heavy transactional invariants that a client cannot enforce atomically are
   relaxed to best-effort checks and documented (see "Relaxed invariants").
6. Supervisor bootstrap: a user may self-create their own `users/{uid}`
   profile; `accessRole: 'supervisor'` is granted only when
   `request.auth.token.email` is in a rules-side allowlist. Staff may
   self-claim `congregationStaff` for their own congregation id. The risk of
   self-claim is accepted for a trusted internal LAN and documented.
7. `functions/` + `functions/test/` stay as reference; security rules tests
   are adapted to the new permission matrix.

## Architecture

### New client transport

`lib/data/firestore_direct_transport.dart` implements the existing
`FirebaseTransport` (glossary: `lib/data/firebase_gateway.dart`):

- `getDocument(path)` — unchanged direct Firestore document read.
- `runQuery(plan)` — unchanged direct Firestore query execution.
- `callFunction(operation, payload)` — **no longer calls Cloud Functions**.
  A dispatch table routes each operation to a Dart handler that validates the
  payload and performs direct Firestore reads/writes, mirroring the behavior
  in `functions/src`.

Handlers are written against a small injected store interface so they are
unit-testable without the emulator:

- `DirectStore` (new, `lib/data/direct_store.dart`): `read(path)`,
  `write(path, data)`, `delete(path)`, `runTransaction(work)`, `query(plan)`
  with a Firestore-backed implementation and an in-memory implementation for
  tests.

Wiring (`lib/app/bootstrap.dart`, `lib/app/dependencies.dart`): construct the
transport from `FirebaseFirestore` + `FirebaseAuth`; remove the
`cloud_functions` dependency from `pubspec.yaml`.

### Operation inventory

Writes (all become direct Firestore transactions/validated writes in Dart;
each validates its payload, bumps `revision` on existing records, writes
`updatedAt`/`updatedBy`):

| Operation | Collections touched | Invariant handling |
| --- | --- | --- |
| `saveCongregation` | congregations | keep revisioned write; keep normalizedName |
| `setCongregationArchived` | congregations | keep |
| `saveContact` | congregations/{id}/contacts + directory (same transaction) | atomic two-doc write kept via transaction |
| `replaceRoleHolder` | contacts + roleSlots (same transaction) | kept as transactional writes |
| `setContactArchived` | contacts + directory (same transaction) | kept |
| `saveStudent` | congregations/{id}/students | keep validation, revisioned write |
| `setStudentArchived` | students | keep |
| `saveClass` | classes | keep revisioned write |
| `setClassStatus` | classes | keep |
| `enrollStudent` | enrollments + class roster subcollection (+ optional student.classId) | roster limit enforced as best-effort length check, not atomic |
| `closeEnrollment` | enrollment | keep status transition + revision |
| `createSession` | sessions/{id} | keep |
| `cancelSession` | session status | receipt/TTL dropped; plain status write |
| `saveAttendance` | sessions/{id}/attendance/{studentId} | keep frozen-name snapshot, revisioned write |

Reads (become client queries + Dart aggregation):

| Operation | Replacement |
| --- | --- |
| `listClassStudents` | direct query `students where classId == …` (remove the `callableOperation` route in `query_codec.dart`) |
| `getSessionAttendance` | direct read of `sessions/{id}/attendance/*` |
| `getEnrollmentProgress` | client aggregation over enrollments + sessions |
| `getOverview` | client aggregation (counts per congregation) |
| `listPendingSessions` | direct query `sessions where status == pending` |

### Relaxed invariants (documented)

- Reference counters (`references`) — dropped; counts derive from queries.
- Receipts + TTL (`operations`, `receipts`) — dropped; cancel is a plain status
  write.
- Uniqueness/homonym reservations — dropped; advisory normalized-name check
  only.
- `MAX_ENROLLMENTS_PER_CLASS` — best-effort client length check; races remain
  possible.

### `query_codec.dart`

`QueryPlan.callableOperation` becomes always `null`; the
`students + classId` case uses a plain filtered query. No other plan
behavior changes (cursors, filter fingerprints, name prefixes stay).

## Firestore rules (free, server-side)

`firestore.rules` keeps the existing helpers (`signedIn`, `currentUid`,
`hasProfile`, `activeProfile`, `isSupervisor`, `isStaffOf`,
`mayReadCongregation`) and gains the write grants:

- `users/{userId}` — self read; self create/update of own profile;
  `accessRole == 'supervisor'` on a write only when
  `request.auth.token.email in [<owner-account-email>]` — the owner's email,
  provided at deploy time (the account created in the console during delivery).
- Congregation subtree (contacts, students, classes, enrollments, sessions,
  session attendance, roster, roleSlots) — write allowed to supervisors
  anywhere and to staff within their own `congregationId`.
- `directory` — write scoped the same way (the client maintains this
  projection).
- `supervisionContacts`, `supervisionRoleSlots` — supervisor read/write.
- Everything not explicitly granted stays denied (catch-all).

The allowlist email value is a single constant at the top of the rules file,
documented as the internal bootstrap credential.

## Error handling

The existing `ErrorMapper` stays. The direct transport maps
`FirebaseException` by its code: `permission-denied` → `forbidden`,
`not-found` → `notFound`, `aborted`/`failed-precondition` → `conflict`,
network/offline → `unavailable`, others → `validation`/`unknown`.

## Testing (simple TDD)

1. Dart unit tests for each handler (RED first) using the in-memory
   `DirectStore`: validation failures, revision conflicts, directory
   projection, aggregation results.
2. Dart unit tests for the dispatch table and the relaxed limits.
3. `functions/test/security` (vitest + `@firebase/rules-unit-testing`)
   adapted to the new rules matrix: assert role-scoped writes allowed for the
   right roles/scopes and denied otherwise.
4. Existing Flutter suite must stay green (`flutter analyze`, `flutter test`).
5. `tool/verify.sh` unchanged.

## Documentation

- New README section "Internal mode (no billing)" describing the trust model,
  the self-claim bootstrap, and the relaxed invariants, concluding with the
  note: *before publishing for broader use, move the rule-critical invariants
  back to trusted server-side code (Cloud Functions on a Blaze project) and
  re-tighten `firestore.rules`.*
- `docs/verification.md` updated with the new rules smoke checks.

## Delivery (Tailscale)

1. `firebase deploy --only firestore --project discipulado-ieadpe` (free on
   Spark).
2. `flutter build web --release` with the production dart-defines
   (`FIREBASE_PROJECT_ID=discipulado-ieadpe`,
   `FIREBASE_API_KEY=…`, `FIREBASE_AUTH_DOMAIN=…`, `FIREBASE_APP_ID=…`,
   storage bucket and messaging sender id).
3. Serve `build/web` at `http://100.73.26.79:8088` (Tailscale IP of this PC).
4. Owner enables Email/Password auth in the console and creates the first
   account; its email is added to the rules allowlist; first sign-in
   self-provisions the supervisor profile.

## Out of scope

- Cloud Functions deployment and Blaze upgrade.
- Identity administration console.
- Data migration from the emulator/prototype.
- Multi-organization or public deployments (documented future work).