# IEADPE Ministry Supabase Port — Design Spec

Status: implemented locally through migration 018 and commit `0c6b969`; production provisioning and legacy migration remain release work. Sources: completed convert Supabase app at `642047f`; `discipulado-IEADPE` `main` at `4acb563`; its trust-data spec and pending JSON plan. The convert app is the final product base.

## Product and data contract

Preserve IEADPE team contacts, congregations, students, classes, enrollment, session/attendance and scoped overview semantics. A student remains a separate record from a convert. Student `congregation_id` is required; a convert may lack one. Keep contact/team role-slot semantics, frozen attendance rosters, class capacity of 100 total historical enrollments, progress as `present/(present+absent)` over finalized non-canceled sessions and no inferred graduation or baptism. Preserve archival history and date-only semantics. Port behavior and tests, not Firebase collection paths or client-trust assumptions.

## Identity, scope and storage

Extend the existing Supabase Auth session and congregation UUIDs. Trusted provisioning creates a discipleship staff grant; campaign registrar/direction grants do not automatically expose student or team data. Supervision access is specified by a role matrix with explicit read/write rights for each module. RLS denies unauthorized direct reads and all direct business writes; RPCs enforce scope, revisions, idempotency and domain invariants. Reuse the convert gateway error semantics. Do not create a second Firebase runtime in the unified app.

Ministry supervisors with no congregation grant must explicitly select a congregation returned by the server-authorized ministry directory before scoped actions. Do not silently choose the first result or convert a campaign-supervision role into ministry scope. The directory RPC returns only active authorized congregation IDs and names in bounded pages; a UI selection is context, not authorization, and each RPC still checks the actor's server grant.

New PostgreSQL tables and migrations follow existing `supabase/migrations/202610140010_feedback.sql` append-only sequence. Reserve legacy Firebase document IDs in separate unique source-key fields for a later authorized migration. `students.convert_id` is nullable/unique but the promotion command belongs to the journey spec. Avoid unbounded global directory reads; use scoped, stable cursor pages and record read budgets.

Use `ministry_grants(user_id,congregation_id,role,active)`, `ministry_contacts`, `ministry_role_slots`, `ministry_students`, `ministry_classes`, `ministry_enrollments`, `ministry_sessions`, `ministry_session_roster` and `ministry_attendance` as the new public business tables; prefix keeps ownership clear beside the completed convert schema. Each business row uses a UUID primary key, `congregation_id`, server revision, timestamps, archive/status fields and nullable unique `legacy_firebase_id` where applicable. Store address and baptism answers in typed student columns/validated JSON with the exact nullability from IEADPE `lib/domain/student.dart`; keep dates as PostgreSQL `date`. Enumerations and curriculum rules come from the existing IEADPE domain files, not new assumptions. `ministry_students.convert_id` is added in the handoff migration after the ministry port.

Expose named `ieadpe_ministry_<command>(operation_id uuid,payload jsonb)` mutations for save/archive contact, role replacement, save/archive student, save/status class, enroll/close enrollment, create/cancel session and save/finalize attendance. Add read RPCs for scoped directory, roster, progress and overview only where RLS-scoped table queries are insufficient. The same verified UID lock order and receipt discipline as convert commands apply. List each payload and return field in the Task 1 contract document before coding; task interfaces must remain stable across SQL and Dart adapters.

## New-skill constraints

`requirements`: explicit INVEST stories, NFR ordering, role matrix and acceptance for each invariant. `design-oo-ux`: composition-first typed model/port sketch and one sequence diagram for enrollment/attendance transaction order. `coding-standards`: pure validation/policy functions, local state and strict boundary inputs. `verification-test`: partitions and boundary 0/1/99/100/101, stale revisions, replay, both concurrency orders and cross-scope denial. `cloud-deploy`: Supabase shared-responsibility and Free-tier capacity budget. `quality-gate`: server authorization, uniqueness, cap, roster and attendance are blocking SQA. `agile-loop`: independently testable slices. `a11y-ethics` applies when ministry UI is composed, with no PII in logs/URLs.

## Verification and limits

Local implementation evidence is recorded in the unified verification matrix/report and migration rehearsal. Exact migrations, SQL/RLS/concurrent-session suites, directory grants and typed Dart repository tests are exercised against synthetic/disposable fixtures. Keep any real Firebase export/import and production cutover outside local implementation. Existing Spark hardening plan is source material; its advisory uniqueness and best-effort capacity are not sufficient acceptance for the unified app.
