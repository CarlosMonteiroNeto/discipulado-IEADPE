# Complete Ministry Delivery Design

Status: revised scope for user review; not implemented by this document.

## Outcome

Deliver one usable Android application for convert registration/follow-up and congregation discipleship: students, team, classes, enrollment, lessons and attendance. Use the current Base44-derived registration screen as the single person-registration entry. A normal operator must complete these tasks through the app, without SQL or synthetic fixtures. Portuguese UI retains the current visual language.

## User refinement: shared registration and automatic follow-up

This section supersedes earlier independent-registration and manual-only handoff assumptions in the previous integration specs and this document. The modules represent one person's journey, not independent registries requiring duplicate entry.

- The existing convert registration form is the only person-registration/editing entry. Student lists offer selecting an existing registered person or opening that same form; do not recreate the old Firebase student-registration form. Academic-only fields may be added as a clearly scoped extension without duplicating identity/contact entry.
- Keep one canonical identity and contact source. A separate internal student/academic row is acceptable for compatibility, but must have a unique explicit link to the registered person, be created/reused automatically during enrollment, and never require operators to copy name/phone/address. Audit existing legacy students before enforcing the linkage; unresolved records must remain preserved and reviewable. Never manufacture conversion dates or merge by name.
- Successful enrollment in an active discipleship class automatically sets the linked person's effective "Em discipulado" state. Explicit referral alone does not. Enrollment and follow-up updates must commit atomically on the server; retry must not duplicate academic records, enrollment or history events.
- A present mark in a finalized, non-canceled lesson counts as actual participation on the lesson date and satisfies the follow-up/visit check. Draft, absent, justified and unmarked attendance do not establish presence. Finalization is the proposed reliable publication boundary; communicate this in the attendance UI.
- Attendance is recorded as attendance, not as a fabricated home visit. Keep actual visit dates/counts intact; use a server-derived effective last-follow-up date from actual visits and qualifying attendance for reminders. The first qualifying presence satisfies the initial-contact requirement even without a recorded home visit.
- Reminder recurrence is grounded in the recovered Base44 source: ConvertCard.jsx lines 42–58 and pages/Converts.jsx lines 111–120 use 1 day without initial contact, 7 days after contact outside discipleship, and 30 days in discipleship. In the integrated flow, qualifying attendance satisfies initial contact and the 30-day discipleship check; measure from the latest actual visit/contact or qualifying lesson date. At 30 days without either, show a follow-up/attendance-verification warning. Do not fabricate a presence or require a home visit when actual participation already satisfies the check. Preserve the outside-discipleship 1/7-day rules.
- Recovered terminal controls are manual: Base44 shows "Desviou-se" after visit_count >= 3, with confirmation; it does not classify deviation automatically after 30 days. It enables manual discipleship completion after 90 days from discipleship_start_date. Preserve both safeguards. Attendance must not increment visit_count or become three invented visits that unlock deviation. Any different deviation criterion requires an explicit product decision.
- All surfaces (convert card, filters, summaries, visit alerts, student/class details and reports) consume the same effective state. Preserve manual historical discipleship flags during transition with explicit provenance; define precedence and enrollment-ending behavior before implementation. Proposed rule: active enrollment determines current academic participation; completed/withdrawn enrollment retains history and does not imply graduation, deviation or baptism.
- Recompute effective follow-up when a session is canceled or qualifying attendance is invalidated. Never erase genuine visits or other valid attendance. Backdated lessons use lesson date, not submission time; replay and concurrent finalization/enrollment must produce consistent results.

Acceptance example: register Maria once in the existing form -> enroll Maria in a class -> her convert card immediately shows Em discipulado -> finalize a lesson with Maria present -> her pending-visit warning clears -> reopen the app and both modules show the same persisted state. A canceled lesson removes only its own derived follow-up effect.

## Investigation and confirmed gaps

Repository: discipulado-IEADPE, main at 2ecba87. The supplied global investigation instructions apply. Inspection covered routing/router.dart, widgets/app_shell.dart, features/auth/auth_repository.dart, app.dart, ministry UI/repositories, docs/integration/ministry-contracts.md and existing access/release/migration plans.

The previous Base44 unified-access plan implements four SQL function replacements and local regression tests. It explicitly excludes hosted SQL execution and data import. This is a valid permission slice, not a complete product-delivery plan. The new scope retains that work.

The Flutter shell already exposes Discipulado and its child routes when the server scope authorizes them. StudentsPage lists students and offers convert handoff; ClassesPage lists classes and opens attendance. Neither provides the full create/edit/enrollment/lesson-creation flow. AttendancePage can mark and finalize existing sessions. Backend command contracts already describe student/class/enrollment/session mutations. These are extension points, not evidence of usable end-to-end delivery.

Hosted migration versions, actual account scope and availability of legacy Firebase data remain unverified. Documentation about local-only work is not proof of current hosted state. Diagnose remote state before selecting or applying migrations.

## Functional contract

### Confirmed registration entry points

Keep "Cadastrar novo convertido" as the default landing screen and simplified registration flow. An authenticated registrar without protected read grants may submit a new convert and receive confirmation, but cannot inspect the saved record or protected lists. Do not add academic fields or a person-type question to this quick flow. Authorized staff have Discipulado -> Alunos -> Cadastrar aluno, reusing canonical person fields/components with an explicit non-new-convert path that requires no conversion date or worship type and creates no conversion event or convert visit obligation. Enrollment selects an existing authorized person or opens that shared-component student entry. These are two task-specific entry points into one identity model, not duplicate independent records. This supersedes the earlier wording requiring the convert entry to be the only registration entry.

### Confirmed visual standard

The theme and component contract is docs/integration/unified-design-system.md. Establish it before implementing new UI; all module slices must follow it. Extend the existing unified theme rather than creating an independent Apple-style theme. Base44 supplies the approved identity; applicable Apple Design and engineering guidance supply interaction, consistency and verification requirements.

Use the Base44 appearance approved by the user throughout the entire unified application, including all new team, student, class, enrollment, lesson and attendance forms/details/dialogs. Follow docs/superpowers/specs/2026-10-18-base44-visual-restoration-design.md and the retained reference/base44 source. Reuse lib/ui/unified_theme.dart, base44_widgets.dart, AppShell and BrandHeader: navy/blue gradient branding, light page background, white rounded panels, consistent typography/spacing, labeled icons and familiar green WhatsApp actions where a phone is available. Do not restore the legacy Firebase presentation alongside the current app.

Preserve accessible contrast, visible focus, touch targets, loading/error/empty/disabled states and large-text responsiveness. Attendance statuses remain labeled in text, not color alone. New screens must receive visual review at phone and desktop widths using synthetic data; compare their hierarchy and shared tokens against the approved Base44-derived convert screens. Build success is not visual acceptance.

The input comparison and unified Team proposal are specified in docs/integration/unified-input-inventory.md. This supersedes separate Team-directory and access-editor entry points as the intended UX. Preserve the existing shared authority: global administrators/supervision see all; congregational team sees its assigned congregation. Detailed organizational role and login permission are linked in one manager workflow but remain distinct validated fields. Reconcile existing access assignments and contacts before migration; no imported role title may silently grant access.

- Technical administrators and Base44 supervisors can access every congregation; direction assignments authorize their active congregations. public.user_access and the technical admin allowlist are authoritative, as specified by the existing unified-access design. RPC/RLS enforcement remains mandatory.
- Authorized users see Discipulado in Android navigation and can select their authorized congregation using server-provided names. The current selection stays consistent across students, classes, lessons and handoff. Supervisors explicitly select a congregation before scoped writes.
- Users can inspect academic records, enrollment history and progress; person creation/editing uses the shared registration form. Existing archive constraints remain enforced. Enrollment creates/reuses the academic extension idempotently; legacy linkage requires an explicit reviewed identity match.
- Users can maintain the team/teacher records needed by class forms, create/edit classes, change supported class states, inspect class details, enroll eligible students and close enrollment using existing domain rules. No active duplicate enrollment; retain historical capacity and archive constraints from the server contract.
- From a specific class, users can create a dated lesson/session, open its frozen roster, mark attendance, save a draft and finalize it. Class/session identity must survive navigation. Finalized attendance remains readable and cannot be edited; cancellation and enrollment changes preserve history. Progress uses the existing finalized-session policy.
- Display meaningful empty, loading, retry, forbidden, stale-revision and finalized states. Retain drafts safely on retry; never repeat a mutation with a new operation ID after an ambiguous network result. Clear protected state on logout, identity/scope change.

## Architecture and data

Extend existing Flutter pages with focused forms/detail pages and typed repository methods over existing RPC contracts. Reuse current SupabaseGateway, server validation, date-only types, operation IDs and revisions. Add forward migrations only for demonstrated missing backend capability; do not rewrite migration history or bypass RLS.

First inventory the old Firebase implementation from Git history/retained source, recording each original workflow and its Supabase equivalent. Inventory actual legacy records separately: a source application does not imply production data exists. If records exist, export privately, map stable source IDs, reconcile congregation mappings and ambiguous identities explicitly, rehearse import and rollback, then import transactionally and compare counts/links/history. Never merge people by name. If no legacy records exist, record evidence and enable empty-state onboarding.

Before hosted changes, identify the exact project, migration ledger/function definitions, backup/recovery mechanism and current account scope using trusted credentials. Apply only missing reviewed migrations in order after local verification. Verify scope through an authenticated app request and real HTTP allow/deny checks. Never expose privileged credentials in Flutter or logs.

## Completion criteria

The same release artifact must support: login -> Discipulado -> congregation -> student -> class -> enrollment -> lesson -> attendance draft -> finalize -> reopen -> persisted progress. Separately verify convert -> explicit student handoff -> enrollment. Test technical admin, supervision, congregation direction and unauthorized identity, including cross-congregation denial and revocation.

Use local synthetic fixtures for automated coverage and isolated authorized records for hosted checks; track and clean only those records. Record hosted migration versions, scope booleans/counts, exact artifact hash/version/certificate, executed checks and limitations without personal data. Verify Android UI/navigation and persisted data against the hosted project. Building an APK, pushing Git or passing mocked tests alone cannot complete delivery. Device validation requiring the user's device is explicitly pending until observed or confirmed.

## Scope and ordering

One completion plan coordinates independently reviewable slices: evidence/inventory; student/team management; class/enrollment management; lessons/attendance; hosted activation and optional legacy migration; full-path verification and Android delivery. Backend activation follows compatible client/security verification; real-data import requires a reconciled source and reviewed mapping. No new paid backend or Firebase runtime.
