# Discipulado IEADPE

Flutter web-first application for managing the discipleship ministry across
IEADPE congregations: team contacts, students, classes, enrollment and
attendance. User-facing copy is pt-BR; code, specs and technical documentation
are English.

This repository is a locally runnable implementation, **not** a released
product. It does **not deploy**, push, import legacy data or send messages.

## Requirements

- Flutter stable on `PATH` with web support enabled (`flutter doctor`).
- Node.js 20 and npm.
- `firebase-tools` with the Java runtime installed for the Firestore emulator.
- A Chromium-based browser for end-to-end runs; Firefox and WebKit for smoke
  checks.

Runtimes are locked by `pubspec.lock` and `functions/package-lock.json`.

## Dependency setup

```bash
flutter pub get
( cd functions && npm ci )
```

## Synthetic fixtures and emulators

All data is synthetic. Start the local emulators explicitly:

```bash
firebase emulators:start --only auth,firestore,functions --project demo-discipulado
```

Seed the synthetic fixtures (one supervisor, two local staff in different
congregations, one inactive profile, homonymous contacts and students, two
teachers, a conflicting administrative role, one class per congregation and
sessions covering every attendance state) with the trusted seeder
`functions/tools/seed-emulators.ts`, invoked by the local/CI emulator harness.
The seeder refuses to run unless the emulator environment variables are
present; it never loads the legacy credential file. Seed UIDs are
`emulator-supervisor`, `emulator-staff-central` and `emulator-staff-norte`.

The Emulator UI at <http://localhost:4000> is used for dev login/reset:
create or reset an Auth user, then bind it with the trusted provisioning
utility.

### First supervisor and subsequent accounts

The first supervisor is provisioned once by a trusted operator: create the Auth
identity in the Auth administration interface, then run the trusted provisioning
utility `functions/tools/provision-access.ts` (accepting the existing UID, role,
active flag and congregation binding). Provisioning is never a callable
endpoint, so no application client can grant an access role. Subsequent
accounts use the same utility with `congregationStaff` and their congregation
ID.

## Running locally

```bash
bash tool/run-local.sh          # macOS/Linux
pwsh tool/run-local.ps1         # Windows
```

The script compiles the backend, starts the emulators and serves the web app
with explicit emulator configuration (`FIREBASE_USE_EMULATOR=true`). A missing
configuration shows a setup error; it never falls back to a production project.

## Internal mode (no billing)

The app runs on the Firebase **Spark (free)** plan. There are no Cloud
Functions: every mutation and projection is a direct client write handled by
the direct transport (`lib/data/handlers/`) over Firestore, and **authorization
lives in `firestore.rules`**. In-app role gating is user-experience only; it is
not a security boundary, and the rules are the only thing that actually
enforces the write matrix.

### Trust model and bootstrap

- Access profiles live in `users/{uid}` and are provisioned **out-of-band**: the
  owner/supervisor profile is created in the Firebase (or Firestore) console with
  `accessRole: supervisor`, and staff profiles with `accessRole:
  congregationStaff` plus their `congregationId` (see `docs/verification.md`
  "Allowlist bootstrap flow"). The shipped app has no screen that writes
  `users/{uid}`.
- The rules additionally let a signed-in user **self-create and self-update
  their own** `users/{uid}` profile; the supervisor self-claim is granted only
  when the authenticated token email equals the single allowlist credential in
  `firestore.rules` (`allowlistedOwner()`). That allowance is defense-in-depth
  for future tooling — keep the placeholder
  `owner@discipulado-ieadpe.example` replaced with the real owner address before
  deploying.
- Writes of the congregation subtree (`contacts`, `students`, `classes`,
  `enrollments`, class `roster`, `activeEnrollmentRefs`, `sessions`, session
  `attendance`, session `roster`, `roleSlots`), the `directory` projection and
  the parent `congregations` document are allowed for **supervisors anywhere**
  and for **staff within their own `congregationId`**. `supervisionContacts`
  and `supervisionRoleSlots` stay supervisor-only. Every other path is denied by
  the catch-all.

### Relaxed invariants

Because there is no trusted server-side transaction layer, some invariants are
deliberately relaxed and enforced as best-effort client checks:

- **No reference counters.** Archive/restore no longer maintains scope
  counters; counts are computed from scoped queries.
- **No receipts or TTL documents.** Operations are plain, revisioned writes.
- **Advisory uniqueness.** Name uniqueness (congregation, contact, student,
  class) is a pre-write read, not a reservation; a concurrent double-submit is
  possible and must be resolved by the operator.
- **Best-effort enrollment cap.** The class capacity check runs before the
  write but is not atomic; a simultaneous enroll can exceed it by a race.
- **Client-side paging amplification.** Name-prefix and cursor pages read the
  whole matching collection once per page (the direct transport pages in Dart),
  so directory and global name searches multiply Firestore reads on Spark;
  budget quota accordingly.

### Re-tightening before broader use

Before publishing the app for broader or untrusted use, the rule-critical
invariants (uniqueness reservations, atomic enrollment cap, reference counters,
and trusted role provisioning) must move back into **trusted server-side code**
(Cloud Functions on a Blaze project) and `firestore.rules` must be re-tightened
to deny the client writes it now allows.

## Web build and hosting rewrite

```bash
flutter build web --release
```

The hosting configuration in `firebase.json` performs the SPA rewrite to
`index.html`, so deep links and hard refreshes resolve through the router.
`web/index.html` ships `noindex` metadata.

## Domain semantics

- **Archive and history.** Normal workflows archive instead of deleting.
  Archived records stay available to authorized staff through an explicit
  filter; historical attendance and enrollment records are never rewritten.
- **Class capacity.** A class is capped at 100 total enrollment records,
  including completed and withdrawn ones. Closing an enrollment does not free
  this historical capacity; a new cohort needs a new class.
- **Progress.** Progress is enrollment-specific: `present / (present + absent)`
  over finalized, non-canceled sessions. Excused sessions are shown separately
  and excluded from the denominator; a zero denominator displays
  `Sem aulas contabilizadas`. Example: 3 present and 1 absent is 75%. Student
  progress is authoritative backend data; there is no automatic graduation or
  baptism inference.

## Verification

Run the same entry point locally and in CI:

```bash
bash tool/verify.sh            # macOS/Linux
pwsh tool/verify.ps1           # Windows
```

It fails on Flutter analysis, tests or web build, and on backend compilation,
unit tests or the emulator authorization suite. The executed commands, exit
codes and environment-blocked checks are recorded in
[`docs/verification.md`](docs/verification.md).

## Non-goals

No deployment, push, legacy import, automated messaging, Android packaging,
public directory, user administration UI or legal-compliance claim. Completion
of this implementation does not imply production readiness.
