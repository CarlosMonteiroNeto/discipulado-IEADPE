# Trust-Data Hardening — Design Spec

## Category Skeleton
- generic category: internal administration and learning-cohort management
- specific category: congregational discipleship administration for IEADPE
- original implementations: single-holder admin role-slots with multi-teacher roles; enrollment-bound attendance with frozen roster; supervision vs congregation scoped authorization

## Goal
Restore server-enforceable trust before any pilot: authorization, invariants, and cost-bounded reads.

## Context
App runs on Firebase Spark with no Cloud Functions. Authorization lives only in `firestore.rules`. Invariants are relaxed advisory checks (`README.md` relaxed invariants). `firestore.rules` contains a hardcoded owner email. Client-side paging amplifies reads.

## Requirements (requirements skill)
- NFR drivers: security > availability > performance > portability.
- Uniqueness (congregation, contact, student, class) moves from advisory pre-read to reservable or explicitly accepted race with operator resolution runbook.
- Class cap 100 total enrollment records enforced atomically or explicitly accepted as best-effort with alert.
- No reference counters; counts from scoped queries (accepted).
- INVEST stories per invariant with testable denial/allowance.

## Architecture (cloud-deploy + coding-standards)
- Spark stays deploy target: `firebase deploy --only firestore` (rules + indexes). No Functions deploy.
- Blaze migration path designed but not executed: trusted transactions, counters, reservations, role provisioning move to Functions; rules re-tightened to deny current client writes.
- Dart `lib/data/handlers/*`: pure functions, no globals, validation at boundary, explicit `expectedRevision`, UUID `requestId` retained for retry.
- TS `functions/src/core/*` mirrors validation semantics (name normalization, dates America/Recife, E.164 BR phones).

## Data flow
Client handler -> scoped Firestore write -> rules `mayWriteCongregation` / `mayWriteDirectory` -> `error_mapper.dart` to `AppFailure` without PII. Concurrent double-submit yields `conflict`, never silent overwrite.

## Changes
1. Replace hardcoded `allowlistedOwner()` email with deploy-time placeholder + rotation procedure.
2. Grant/audit `activeEnrollmentRefs` and class/session `roster` paths (task-13 regression) with allow/deny matrix.
3. Document accepted races; add operator resolution steps.
4. Measure and bound directory/global prefix reads; add pagination budget note.
5. Mirror Dart/TS validators with shared fixtures.

## Verification (inputs to verification-test)
- Emulator matrix: supervisor/staff-own/staff-other/self-escalation/allowlisted-owner/catch-all, including new roster/ref paths.
- Unit: normalization, calendar edges, baptism nullables, progress 3/1/2 = 75%, zero denominator.
- Cost probe: reads per directory page recorded.

## Non-goals
No Blaze deploy, no Functions activation, no legacy import, no messaging, no legal-compliance claim.
