# L1 Class Session Management — Design Amendment

Status: the three conversational design sections are user-approved; this written spec awaits user review. Author: Sol 6.1 / low. This additive amendment implements L1 of `2026-10-18-ministry-production-completion-plan.md` and its design, read with `docs/verification/ministry-task-manifest.md` and `docs/integration/ministry-completion-contracts.md`. It preserves reviewed A1/A2/V1/F1 work. Investigation baseline: `acf1ae9` in the ministry-production-completion worktree.

## Outcome and scope

An authorized operator can list, create, open and cancel lessons from a particular class, then return to that same class. Congregation, class and session identity survive navigation and retries. L1 supplies session discovery and navigation; L2 owns new attendance draft/finalize behavior, finalized read-only history presentation, roster/progress details and alert presentation. Hosted activation, import and delivery remain later slices.

The approved approach adds a class-scoped read. Filtering the existing pending queue cannot discover future, finalized or canceled sessions and filters after congregation pagination. Extending that queue would alter its established due-work contract. Keep it unchanged.

## Class session read

Add `public.ieadpe_ministry_list_class_sessions(request jsonb) returns jsonb`, authenticated-only, using existing Ministry access locks, authority and signed cursor helpers. Request is exactly `{congregation_id: UUID, class_id: UUID, limit: integer 1..100, cursor: string|null}`; all keys are required, unknown keys rejected. The Dart method defaults limit to 50 and sends null for the first cursor. Dates are strict date-only `yyyy-MM-dd` strings.

Return exactly `{items: [{id: UUID, class_id: UUID, congregation_id: UUID, date: Date, topic: string|null, status: 'open'|'finalized'|'canceled', revision: integer}], next_cursor: string|null}`. Revisions are positive. Include all dates and statuses, including sessions of completed/archived classes. Empty results have `items: []` and `next_cursor: null`. No roster, student identity or access metadata is returned.

Order by `(session_date ASC, id ASC)` and use keyset pagination, never offset pagination. Fetch at most limit+1 to determine continuation; return at most limit rows. Sign and validate the cursor with resource `class_sessions`, actor UID, congregation ID, class ID and last date/ID. A page-size change is allowed; another actor/class/congregation/resource or tampered cursor is rejected. Pages reflect current authorized records, not a transaction-spanning snapshot; explicit refresh starts at the first page.

Validate envelope/types/UUIDs first; require authenticated identity and current congregation access before checking class existence. A class outside the requested authorized congregation is indistinguishable from a missing class. Apply class/scope filtering before paging. Errors follow existing safe conventions: `unauthorized`/`forbidden` (42501), `invalid_request`, `invalid_limit`, `invalid_cursor`, `class_not_found` (22023). Invalid limits use `invalid_limit` once the value is a well-formed integer; malformed types/fractional values use `invalid_request`. Recheck authority on every page; no global/null congregation mode or client role argument is accepted. Preserve RLS and revoke PUBLIC/anon execution; grant authenticated execution only.

## UI and identity flow

Keep `/ministry/classes` as the parent route and use the existing `Navigator`/`MaterialPageRoute` pattern for class detail, session list, form and selected attendance. Keep `/ministry/attendance` serving the existing pending queue. Pass IDs in memory, never personal data or return context in URLs.

- `ClassDetailPage` opens `SessionListPage` in `session_list.dart` with fixed congregation ID and class summary. Replace its class-context-losing attendance action with this flow; carry changes through `ClassesPage` and `app.dart` as required.
- `SessionListPage` owns scoped loading/pagination/refresh and cancellation. Show class heading, lesson date/topic and text status; preserve list position on return and refresh changed data. Only active classes offer “Nova aula”.
- `SessionForm` receives fixed congregation/class context and collects date and optional topic. It returns the created session ID; the list opens that exact session directly, including a future lesson. The user cannot silently switch class in the form.
- `AttendancePage` accepts an immutable selected-session context containing congregation/class/session IDs. Verify loaded detail matches all three before showing it. Add only direct-open and return handling here; new attendance lifecycle behavior belongs to L2. Back returns to the same session list, then the same class detail.
- Cancellation from a row loads authoritative detail/revision and confirms the lesson before mutation. Permit open/finalized cancellation under migration 008; a canceled row remains labeled “Cancelada” and offers no new cancellation. Retained detail remains readable through existing detail behavior.

Create retains a stable record UUID, operation UUID and exact submitted payload across ambiguous failures. Cancel similarly retains operation/payload/revision. Disable duplicate submission. Keep form values on error; resolve an ambiguous operation before submitting changed values under a new operation ID. Stale revision requires refresh and a renewed explicit decision, never an automatic overwrite.

`app.dart` owns invalidation of protected navigation context: logout, identity change, lost authority or congregation change clears nested class/session screens, loaded records, drafts and pending operation state. Ignore late responses from an obsolete context; recheck current authorization on protected return/resume. Invalid context returns to a currently authorized entry, never another congregation's class.

Use existing Base44 theme/widgets, Portuguese copy, class-identifying headings, labeled statuses/actions, visible focus and loading/empty/error/retry states. Review synthetic phone/desktop layouts and 200% text with accessible touch targets; introduce no competing theme.

## Forward migration and preserved behavior

Reserve `supabase/migrations/202610190009_ministry_session_management.sql` for the read and creation guard: 008 is currently the last migration and 009 is unused. Reconfirm numbering before implementation. Do not rewrite prior migrations.

Enforce new session dates inclusively within class start/end under existing class locking: date >= start and, when present, date <= end. Creation still requires active class. Client validation provides feedback; server enforcement is authoritative. Future dates inside the period are valid. Out-of-period creation emits existing `academic_invalid` (22023), retaining command failure mapping. Preserve operation receipt replay before applying new-operation validation.

The guard applies to new session creation only. Preserve existing out-of-period records and allow their authorized read/cancel; do not rewrite dates or perform historical cleanup. Preserve the existing partial unique live `(class_id, session_date)` index, its `academic_conflict` mapping and cancellation releasing a date. No new uniqueness scheme is needed.

Migration 008 remains authoritative for cancellation of open/finalized sessions: retain roster/attendance, lock class/session, check revision, increment once and preserve exact receipt replay. Remove only the canceled session's derived follow-up contribution; retain real visits and other qualifying presence. Do not replace F1 projection logic. Preserve the existing `America/Recife` business-date finalization restriction without adding attendance behavior in L1. Existing mutation payloads and server grant boundaries remain unchanged; clients gain no direct business writes.

## Acceptance and engineering gates

Before code dispatch, amend completion contracts and L1 manifest with the exact read above, typed `MinistrySessionSummary`, repository/decoder/gateway ownership, navigation context, migration and test files, predecessor SHA and commands. This spec does not itself edit those contracts. Obtain Sol/low contract review with zero critical/important findings.

The implementation plan must name focused tests and assertions for:

1. Class-bound create/open/back/reload, including class A versus B, future rediscovery and pagination beyond 100 records; all three IDs match throughout.
2. All session statuses, completed/archived class history, empty/loading/retry states; only active classes create.
3. Before-start/after-end rejection, inclusive boundaries, absent end date and valid future creation; duplicate live-date rejection without partial writes.
4. Open/finalized cancellation, exact replay, stale revision, retained roster/marks, historical out-of-period read/cancel and replacement on a canceled date.
5. Anonymous/revoked/foreign access, mismatched class/scope, malformed/tampered/mismatched cursors, bounded pages and valid changed page size.
6. Ambiguous retry preserving payload/IDs, changed-input resolution, scope invalidation and obsolete response rejection; phone/desktop/200% text visual evidence.

Follow TDD: write each new assertion, observe its intended missing-behavior RED (not fixture/import errors), implement minimally and observe GREEN. Investigate unexpected failures systematically before fixing or accepting a baseline. Run focused UI/data tests, the new SQL scenario, academic SQL regressions and affected F1 checks, then required broader Flutter analysis/tests. Preserve business-date finalization and F1 cancellation regression coverage; this is verification of existing behavior, not L2 implementation.

User review of this written spec precedes Sol 6.1 authoring the written implementation plan with `writing-plans`. User review of that plan precedes implementation; the selected method remains fresh subagent execution, Luna/medium implementer and Sol/low reviewers. Follow the overall plan's contract gate, ledger, exact base/head review package, critical/important fix/re-review loop and final whole-product review. Do not silently substitute models. Record actual commands, outcomes and limitations; claim no implementation completion without fresh evidence. No product policy remains unresolved by the approved three sections.
