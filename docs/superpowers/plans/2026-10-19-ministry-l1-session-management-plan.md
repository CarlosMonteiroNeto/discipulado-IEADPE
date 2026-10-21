# L1 Class Session Management Implementation Plan

<!-- canonical-document-authority -->
> **Historical planning reference.** The [current spec](../specs/2026-10-20-ministry-corrective-release-design.md), [current plan](2026-10-20-ministry-corrective-release-plan.md) and [JSON mirror](2026-10-20-ministry-corrective-release-plan.json) govern current requirements, status, task order and authorization. The original body preserves its dated design, checklists and execution provenance; reconcile useful obligations through the current task owners before future work.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make class-bound lessons discoverable, creatable, openable and cancellable with correct identity, history and retry behavior.

**Architecture:** Add a bounded class-session read and a new-session period guard, then typed Flutter adapters and focused session widgets. Carry immutable congregation/class/session context through the existing Navigator stack; preserve the pending queue and F1 commands.

**Tech Stack:** Flutter/Dart, Supabase PostgreSQL RPCs, existing Flutter tests and disposable local SQL runner.

**Spec:** `docs/superpowers/specs/2026-10-19-ministry-l1-session-management-design.md`, approved spec commit `90b7110c743c00e697836f58050277f6055e1ebd`.

## Global Constraints

- “L1 supplies session discovery and navigation; L2 owns new attendance draft/finalize behavior, finalized read-only history presentation, roster/progress details and alert presentation.”
- “Keep `/ministry/attendance` serving the existing pending queue.”
- “Pass IDs in memory, never personal data or return context in URLs.”
- “Future dates inside the period are valid.”
- “The guard applies to new session creation only.”
- “Existing mutation payloads and server grant boundaries remain unchanged; clients gain no direct business writes.”
- “Use existing Base44 theme/widgets, Portuguese copy, class-identifying headings, labeled statuses/actions, visible focus and loading/empty/error/retry states.”
- Selected execution: fresh subagent-driven tasks; Luna/medium implementer, fresh Sol 6.1/low task and final reviewers. Do not substitute silently. Sol authored this plan; user review of this written plan is required before executing even Task 1.
- Local synthetic work only: no hosted operations, import, APK or delivery. Leave the four pre-existing user-owned untracked design/input/overall-plan/spec documents untouched.

## Review Focus

1. A future lesson created before leaving the class must remain discoverable after return/reload (Tasks 2, 4, 5).
2. An ambiguous mutation followed by changed input must replay the original operation before accepting a different one (Tasks 4, 5).
3. Scope/identity changes while nested routes and requests are active must clear protected content and reject late results (Task 5).
4. Historical out-of-period sessions must remain readable/cancellable while new invalid dates fail (Task 2).
5. Long class/topic text and confirmation actions must remain readable at phone width and 200% text (Task 5).

---

## Execution setup and file map

Continue from current spec head `90b7110`; preserve reviewed F1 head `aa03c84` and subsequent documentation. Verify current branch/worktree/status and instructions before dispatch. Resume `docs/verification/ministry-execution-ledger.md`, appending L1 subtask base/head, actual requested/runtime model evidence, commands/exit codes, review findings/fixes and local-only limitations. Use this plan's own SDD workspace/ledger in addition to that product ledger; never reset completed A1/A2/F1 work. One writer at a time, dependent tasks sequential.

| Task | Exclusive deliverable / ownership |
| --- | --- |
| 1 contract gate | Amend `docs/integration/ministry-completion-contracts.md`, L1 entry in `docs/verification/ministry-task-manifest.md`, append execution ledger |
| 2 server | New reserved `supabase/migrations/202610190009_ministry_session_management.sql`; new `supabase/tests/database/ministry_session_management_test.sql` and `ministry_session_management_legacy_seed.sql` |
| 3 adapter | `lib/features/ministry/data/ministry_codec.dart`, `ministry_repository.dart`; `lib/data/supabase_gateway.dart`; existing repository/gateway tests |
| 4 widgets | New `lib/features/ministry/ui/session_form.dart`, `session_list.dart`; new `test/features/ministry/ui/lesson_session_test.dart` |
| 5 integration | `lib/features/ministry/ui/classes_page.dart`, `class_detail_page.dart`, `attendance_page.dart`, `lib/app.dart`; new `lib/features/ministry/domain/session_navigation_context.dart`; extend lesson tests; new `test/features/ministry/ui/session_navigation_test.dart`, `session_visual_test.dart`; synthetic captures under `docs/verification/l1/` |

Every task records predecessor as the prior reviewed task's exact head, not a guessed SHA. Generate review package from recorded BASE through HEAD, never HEAD~1. Give each reviewer the brief, implementation report, diff package and binding spec/constraints. Critical/Important findings go to Luna/medium fixes and scoped Sol/low re-review until resolved, as required by the overall ministry plan. Record disposition of minors. Do not use generic skill parking rules to waive this project's stricter gate.

### Task 1: Amend and review contracts before code dispatch

**Files:** file-map Task 1 only.

**Interfaces:** consume the approved spec; produce the exact contract and downstream manifest below. Documentation review replaces artificial TDD.

- [ ] Reconfirm migration 008 remains last and 009 unused. Reserve 009 only if still available; if another migration exists, record the next append-only filename consistently in contract/manifest/brief before review.
- [ ] Add `ieadpe_ministry_list_class_sessions(request jsonb)->jsonb` with the spec's exact four required keys, exact item keys/statuses, ASC date/ID ordering, signed resource `class_sessions`, actor/class/congregation binding, changed page size allowed, and exact error/SQLSTATE rules. Preserve the pending read. Correct stale cancellation policy-table wording to migration 008's implemented behavior.
- [ ] Record adapter signatures from Task 3 and widget/context signatures from Tasks 4–5; add all owned files/test names/commands and forward period guard to L1 manifest. Keep L2 attendance lifecycle/progress deferred.
- [ ] Self-review request/result/type/cursor/error consistency against every spec section. Expected: no unresolved payload, status, field, ownership or scope choice.
- [ ] Commit only the three owned documents: `git add -- docs/integration/ministry-completion-contracts.md docs/verification/ministry-task-manifest.md docs/verification/ministry-execution-ledger.md`, then `git commit -m "docs: amend L1 session contracts and manifest"`.
- [ ] Dispatch fresh Sol/low contract review; fix/re-review until zero Critical/Important. Record clean review/head in ledger and commit that record before dispatching Task 2. No backend/UI implementer receives unresolved interfaces.

### Task 2: Add server class-session read and creation guard

**Files:** file-map Task 2; append ledger/manifest evidence only after review.

**Interfaces:** consume reviewed Task 1; produce `ieadpe_ministry_list_class_sessions(request jsonb)->jsonb` exactly as specified. Existing create/cancel envelopes remain unchanged. Use existing authority/lock/cursor helpers and a creation-only guard in the new migration; do not copy/replace F1 cancellation/projection code or rewrite old migrations.

- [ ] Write `ministry_session_management_test.sql` using existing academic/access fixture conventions, synthetic actors with own/foreign congregations, class A/B, finite/open-ended periods and 101 sessions. Name assertions: `class session page is scoped and bounded`, `future and all statuses remain discoverable`, `cursor binds caller class and congregation`, `page size may change`, `class period bounds are inclusive`, `historical out-of-period session remains cancellable`, `cancel releases live date and retains marks`, `create replay survives historical class state`. The date assertions must include:

Use `pg_temp.assert_true(boolean,text)` from existing SQL scenarios. The fixture creates authorized congregation `97000000-0000-0000-0000-000000000001`, active class `...002` with period 2026-01-10 through 2026-12-20, completed class `...003` and archived class `...004`, each historical class containing a finalized session (seed class status directly before inserting its session). The following blocks are executable assertions after that setup and JWT actor selection:

```sql
DO $$ DECLARE response jsonb; class_uuid uuid; BEGIN
 FOR class_uuid IN SELECT unnest(ARRAY[
  '97000000-0000-0000-0000-000000000003'::uuid,
  '97000000-0000-0000-0000-000000000004'::uuid]) LOOP
  response:=public.ieadpe_ministry_list_class_sessions(jsonb_build_object(
   'congregation_id','97000000-0000-0000-0000-000000000001',
   'class_id',class_uuid,'limit',100,'cursor',NULL));
  PERFORM pg_temp.assert_true(jsonb_array_length(response->'items')=1,
   'completed and archived class sessions remain discoverable');
  PERFORM pg_temp.assert_true(response#>>'{items,0,status}'='finalized',
   'historical finalized status is preserved');
 END LOOP;
END $$;
DO $$ DECLARE day_value text; response jsonb; BEGIN
 FOREACH day_value IN ARRAY ARRAY['2026-01-09','2026-12-21'] LOOP
  BEGIN
   PERFORM public.ieadpe_ministry_create_session(gen_random_uuid(),jsonb_build_object(
    'id',gen_random_uuid(),'congregation_id','97000000-0000-0000-0000-000000000001',
    'class_id','97000000-0000-0000-0000-000000000002','date',day_value,'topic',NULL));
   RAISE EXCEPTION 'ASSERTION: out-of-period creation accepted';
  EXCEPTION WHEN SQLSTATE '22023' THEN
   PERFORM pg_temp.assert_true(SQLERRM='academic_invalid','period error is safe');
  END;
 END LOOP;
 FOREACH day_value IN ARRAY ARRAY['2026-01-10','2026-12-20'] LOOP
  response:=public.ieadpe_ministry_create_session(gen_random_uuid(),jsonb_build_object(
   'id',gen_random_uuid(),'congregation_id','97000000-0000-0000-0000-000000000001',
   'class_id','97000000-0000-0000-0000-000000000002','date',day_value,'topic',NULL));
  PERFORM pg_temp.assert_true(response->>'status'='open' AND
   (response->>'revision')::integer=1,'inclusive boundary creates open revision 1');
 END LOOP;
END $$;
```

For the no-end fixture, call creation with `(now() AT TIME ZONE 'America/Recife')::date+1` and assert open/revision 1. Duplicate one successful boundary request with new operation/record UUIDs; catch SQLSTATE 23505 and assert `SQLERRM='academic_conflict'`, unchanged row count and no new receipt. Use distinct dates for these assertions and the 101-row pagination fixture.

Also assert exact result keys/revisions/order, page sizes 1/100/0/101/fractional, empty tail/null cursor, unknown/missing keys, anonymous EXECUTE denial, revoked/foreign denial, foreign class as `class_not_found`, cursor tampering/other user/resource, immutable history, stale revision and exact replay. Create the dedicated seed file with a synthetic actor, authorized congregation/class and out-of-period historical session using IDs separate from scenario fixtures. Seed before existing migration 008 (which already exists during RED), so the future creation guard never needs to be disabled. Commit fixture setup; the scenario reads/cancels that historical row after all migrations. Keep migration 008 unchanged.
- [ ] Run `python scripts/test_database.py ministry_session_management_test.sql --seed-before-migration 202610190008_ministry_derived_follow_up.sql --seed-scenario ministry_session_management_legacy_seed.sql`. Expected RED: first new read assertion fails because the function is absent (after successful fixture setup); record the exact error. Introduce read first, then observe period assertions fail on accepting the invalid date before adding the guard. Do not mistake fixture failures for RED.
- [ ] Implement the new migration: authenticate/access-lock/validate; authorize before class lookup; signed keyset page; PUBLIC/anon revoke/authenticated grant; creation-only inclusive period enforcement under class locking. Preserve receipt replay before new-operation mutable validation, live index and finalization business date. Guard must not fire on cancellation/status updates or invalidate stored historical rows.
- [ ] Run the same seeded new SQL scenario command to GREEN, then `python scripts/test_database.py ministry_academic_test.sql`, `python scripts/test_database.py ministry_follow_up_test.sql`, `python scripts/test_database.py ministry_access_test.sql`, and `python scripts/test_database.py --ministry-follow-up-concurrency`, sequentially. Expected each exit 0/PASS; existing future-finalization denial and finalized cancel history/F1 behavior remain covered. Investigate any failure before deciding a fix.
- [ ] `git diff --check`; stage only new migration/scenario/seed file; `git commit -m "feat: add scoped class sessions and period guard"`. Fresh Sol/low review and required fix/re-review precede Task 3.

### Task 3: Add typed repository and gateway adapters

**Files:** Task 3 map; extend `test/features/ministry/data/ministry_repository_test.dart`, `test/data/supabase_gateway_ministry_contract_test.dart`.

**Interfaces:** define in `ministry_codec.dart` immutable `MinistrySessionSummary(id, classId, congregationId, date: CalendarDate, topic: String?, status: SessionStatus, revision: int)` and `decodeClassSessions(Map<String,dynamic> json, {required String congregationId, required String classId}) -> MinistryPage<MinistrySessionSummary>`. Define in repository:

```dart
Future<MinistryPage<MinistrySessionSummary>> listClassSessions({required String congregationId, required String classId, int limit = 50, String? cursor});
Future<MinistryCommandResult> createSession({required String operationId, required String id, required String congregationId, required String classId, required CalendarDate date, required String? topic});
Future<MinistryCommandResult> cancelSession({required String operationId, required String id, required String congregationId, required int expectedRevision});
```

Use gateway alias `ministry_list_class_sessions`; Supabase transport prefixes it as existing reads do. Require all four request keys in allowlist/required-key map. Mutation methods use existing command transport and exact create/cancel JSON from the contract.

- [ ] Add tests `class sessions decode all statuses and future dates`, `class sessions reject foreign item and invalid wire data`, `class sessions gateway requires exact keys`, `session mutations preserve exact envelope`. Assert unknown/missing result keys, bad date/UUID/status/nonpositive revision and foreign item class/congregation yield `DataFailure('invalid_response')`; list args default limit 50/cursor null; limits >100 rejected before transport; exact operation IDs/payload fields transmitted. Existing stale-context gateway checks still reject late responses.

  Assertion excerpts belong in the named tests after their setup. Define fixture constants `congregationId`, `classId`, `sessionId`, `operationId` as distinct valid UUIDs, `repository` as the real repository over the existing recording fake gateway, `calls` as its recorded alias/operation/payload calls, and `wire` as the exact class-session result. Use these assertions (not production test hooks):

```dart
final page = decodeClassSessions(wire, congregationId: congregationId, classId: classId);
expect(page.items.map((s) => s.status.wire), ['open', 'finalized', 'canceled']);
expect(page.items.first.date.toString(), '2099-01-10');
expect(page.items.first.revision, 1);
expect(page.nextCursor, isNull);
await repository.listClassSessions(congregationId: congregationId, classId: classId);
expect(calls.last.payload, {'congregation_id': congregationId, 'class_id': classId,
  'limit': 50, 'cursor': null});
await repository.createSession(operationId: operationId, id: sessionId,
  congregationId: congregationId, classId: classId,
  date: CalendarDate.parse('2026-12-20'), topic: null);
expect(calls.last.operationId, operationId);
expect(calls.last.payload, {'id': sessionId, 'congregation_id': congregationId,
  'class_id': classId, 'date': '2026-12-20', 'topic': null});
await repository.cancelSession(operationId: operationId, id: sessionId,
  congregationId: congregationId, expectedRevision: 7);
expect(calls.last.payload, {'id': sessionId, 'congregation_id': congregationId,
  'expected_revision': 7});
```

  In malformed-wire tests, assert the real repository future with `throwsA(isA<DataFailure>().having((e) => e.code, 'code', 'invalid_response'))`; construct each invalid result independently. In gateway tests assert missing `cursor` and added `role` fail before HTTP, while the exact four-key read reaches `ieadpe_ministry_list_class_sessions`.

- [ ] Run `flutter test --no-pub --concurrency=1 test/features/ministry/data/ministry_repository_test.dart test/data/supabase_gateway_ministry_contract_test.dart`. Expected RED at new API/allowlist or decoder assertions, then implement the stated signatures and rerun same command to exit 0. Existing pending decoder and request semantics stay unchanged.
- [ ] `git diff --check`; stage only Task 3 files; `git commit -m "feat: expose typed class session repository"`; fresh Sol/low review and fixes/re-review before Task 4.

### Task 4: Build session form, list and cancellation

**Files:** Task 4 map; use existing fake gateway/test utilities patterns from enrollment/class tests; production remains free of test-only hooks.

**Interfaces:** `SessionForm({required MinistryRepository repository, required String congregationId, required MinistryClassSummary classSummary})` is a pushed widget returning `String?` session ID via Navigator.pop. `SessionListPage({required MinistryRepository repository, required String congregationId, required MinistryClassSummary classSummary, required Future<void> Function(String sessionId) onOpenSession})` awaits the callback with the chosen/created session ID, then refreshes the current class list while retaining scroll position if its original context remains valid. No refresh occurs before the returned future completes. It consumes Task 3, authoritative `getSessionAttendance` for cancellation revision, and existing summary/date/status types. Both belong to the current fixed class context.

- [ ] Write tests named `create class-bound dated lesson`, `session uses selected class`, `future lesson remains listed after reload`, `duplicate date is rejected`, `cancel preserves roster history`, `ambiguous create retains exact request`, `ambiguous cancel retains exact request`, `changed input waits for pending operation resolution`, `definite rejection permits corrected input`. Assert class A IDs never become B; new ID opens directly; a future lesson reappears after widget recreation; list pagination appends/deduplicates IDs; canceled row remains; confirmation dismissal sends no mutation; cancel uses freshly loaded revision; stale revision requests refresh and renewed confirmation. Use real widget/repository execution against fake transport, not mocked widget outcomes.

  Use recording fake transport with real widgets/repository. Test-local `createCalls`/`cancelCalls` expose immutable captured `operationId` and `payload`; fake responses are controlled by Completers. Drive labeled production actions, then use these executable assertions in the corresponding tests:

```dart
expect(createCalls.single.payload['class_id'], classAId);
expect(createCalls.single.payload['congregation_id'], congregationId);
expect(createCalls.single.payload['date'], '2026-12-20');
expect(openedSessionIds, [createdSessionId]);
final firstCreate = createCalls.first;
expect(createCalls.last.operationId, firstCreate.operationId);
expect(createCalls.last.payload, firstCreate.payload);
expect(cancelCalls.single.payload['expected_revision'], 7);
expect(cancelCalls.single.payload['id'], selectedSessionId);
expect(find.text('Cancelada'), findsOneWidget);
expect(cancelCalls.last.operationId, cancelCalls.first.operationId);
expect(cancelCalls.last.payload, cancelCalls.first.payload);
```

  Add `historical class list is readable but cannot create`: for each `ClassStatus.completed` and `ClassStatus.archived`, pump its real SessionListPage with a finalized historical row; `expect(find.text('Nova aula'), findsNothing);` then tap its date row and `expect(openedSessionIds, [historicalSessionId]);`. For `ClassStatus.active`, `expect(find.text('Nova aula'), findsOneWidget);`. The open callback completes without new history/editing UI; L2 remains deferred. Also assert dismissal sends no cancellation with `expect(cancelCalls, isEmpty);` before the confirmed path.

- [ ] Run `flutter test --no-pub --concurrency=1 test/features/ministry/ui/lesson_session_test.dart`. Expected RED because widgets/behavior are absent; resolve compilation before accepting behavior RED. Implement form/list minimally; use immutable pending request patterns from `ClassEnrollmentPanel`, independently generated read tokens and bounded load-more. Disable new mutation while ambiguous outcome remains; allow correction after documented definite rejection only. Rerun to exit 0.
- [ ] `git diff --check`; stage only Task 4 files; `git commit -m "feat: manage lessons from a fixed class"`; fresh Sol/low review/fix/re-review before Task 5.

### Task 5: Integrate protected navigation and visual acceptance

**Files:** Task 5 map; extend existing `class_management_test.dart` only where its changed class action requires it. Existing global pending entry stays operational.

**Interfaces:** immutable `SessionNavigationContext({required String congregationId, required String classId, required String sessionId})` in the new domain file; UUID validation uses existing domain conventions. Add nullable `SessionNavigationContext? selectedSession` to `AttendancePage`; when supplied, load only that detail and require all three IDs to match before display. Keep no-context pending behavior. `ClassDetailPage` supplies `onOpenSession: (sessionId) async { await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => AttendancePage(repository: repository, congregationId: congregationId, selectedSession: SessionNavigationContext(congregationId: congregationId, classId: classSummary.id, sessionId: sessionId)))); }`; Task 4 owns the awaited post-return refresh. App scope owner clears nested routes on invalidation. Remove obsolete class-detail pending-queue callback wiring in ClassesPage/app without removing global attendance navigation. Navigator Back pops selected attendance -> same session list -> same class detail.

- [ ] Write `session_navigation_test.dart`: `class session survives create open back and reload`, `mismatched session detail is rejected`, `scope loss clears nested routes and late requests`, `identity and congregation switch clear pending operations`, `pending queue route remains available`. Assert class A/its congregation/session IDs in every request; completing a class B/old-scope response never exposes it; no protected route or marks remain after logout/revocation; back keeps list position and refreshes; future session reload does not call pending queue. Extend lesson tests for read-generation races after create/cancel refresh. Run `flutter test --no-pub --concurrency=1 test/features/ministry/ui/session_navigation_test.dart test/features/ministry/ui/lesson_session_test.dart` and observe intended RED before navigation implementation.

  In `awaited open refreshes only after return`, inject `onOpenSession: (_) => returnGate.future` where `returnGate = Completer<void>()`; record real list transport calls as `listCalls`. Before tapping a session, capture `final readsBeforeReturn = listCalls.length;`; tap the row, pump, and assert `expect(listCalls.length, readsBeforeReturn);`. Complete the gate and pump: `expect(listCalls.length, readsBeforeReturn + 1);`. Assert the new read retains `class_id == classAId` and original scroll offset. The same awaited callback must be used by both newly created and existing sessions.

  Navigation tests drive the real app/router fixture; test-local `detailCalls` record read parameters, and `oldRead` controls an old-context response. After their setup/action phases use:

```dart
expect(detailCalls.last.payload, {'congregation_id': congregationId,
  'session_id': selectedSessionId});
expect(selectedContext.classId, classAId);
await tester.pageBack();
await tester.pumpAndSettle();
expect(find.text('Aulas'), findsOneWidget);
expect(listCalls.last.payload['class_id'], classAId);
expect(listCalls.last.payload['congregation_id'], congregationId);
```

  After the fixture performs real logout/revocation or congregation switch, complete `oldRead` with old-scope data and pump; assert `expect(find.text('Turma A protegida'), findsNothing);`, `expect(find.byType(SessionForm), findsNothing);`, and `expect(find.byType(AttendancePage), findsNothing);`. In mismatched-detail tests return class B's detail under the selected ID, then assert its topic/marks are absent and an error is visible. For the no-context global entry assert `expect(pendingCalls.length, 1);`; selected-session entry asserts `expect(pendingCalls, isEmpty);`.

- [ ] Implement only selected-session entry/identity checks/return and app-level nested-route invalidation, using existing router authorization/revalidation and gateway context. Do not add attendance editing, finalized read-only/history/progress features. Run the same tests to GREEN, then `flutter test --no-pub --concurrency=1 test/features/ministry/ui/class_management_test.dart test/features/ministry/ui/ministry_journey_test.dart test/features/ministry/ui/enrollment_lifecycle_test.dart` (exit 0).
- [ ] Add `session_visual_test.dart`, using the existing class capture technique and production `buildUnifiedTheme()`; only deterministic test font substitution allowed. Assert no overflow, visible labels/focusable actions, accessible minimum 48px action targets and canceled/finalized text labels at 360x900, 1440x900 and 360x900 at TextScaler.linear(2). Capture form/list/cancel dialog, including long class/topic text, loading/error/empty states. Run `flutter test --no-pub --concurrency=1 test/features/ministry/ui/session_visual_test.dart`; inspect each generated synthetic PNG in `docs/verification/l1/`, record visual decisions in `docs/verification/l1/visual-review.md`, fix clipping/contrast/hidden actions and rerun. Capture approval is evidence, not a blanket golden update.

  In each visual test pump the real form/list/dialog at the specified size/scaler, scroll each action into view, and use these assertions. The form's active-class action is `Salvar`; the list's is `Nova aula`; the confirmation dialog's is `Cancelar aula` (use the same exact labels in widgets and tests):

```dart
expect(tester.takeException(), isNull);
expect(find.text('Cancelada'), findsOneWidget);
expect(find.text('Finalizada'), findsOneWidget);
await tester.ensureVisible(find.widgetWithText(FilledButton, 'Nova aula'));
expect(tester.getSize(find.widgetWithText(FilledButton, 'Nova aula')).height,
  greaterThanOrEqualTo(48));
expect(tester.getSize(find.widgetWithText(FilledButton, 'Nova aula')).width,
  greaterThanOrEqualTo(48));
```

  Repeat size/visibility assertions for `Salvar` and `Cancelar aula` in their respective fixtures, and `expect(tester.takeException(), isNull);` after scrolling at both 100% and 200% text. Use `tester.ensureSemantics()` and Flutter `meetsGuideline(androidTapTargetGuideline)`, `meetsGuideline(labeledTapTargetGuideline)` assertions before disposing the semantics handle. Focus traversal must reach the enabled primary action; captures still require human inspection for contrast and long text.

- [ ] Run final local L1 verification sequentially: `flutter analyze --no-pub`; `flutter test --no-pub --concurrency=1`; the seeded new SQL scenario, three existing SQL scenarios and F1 concurrency command from Task 2. Expected exit 0 for each. Inspect all failures and trace cause under systematic-debugging; do not stop at a baseline failure or label uninvestigated failures acceptable. Run formatter check on changed Dart files and `git diff --check` (both exit 0). Record commands/output in the ledger; no hosted/browser/device completion is inferred. The overall `verify_unified.ps1`/device delivery gate remains D1.
- [ ] Stage only Task 5 product/test/capture files and L1 ledger/manifest evidence; `git commit -m "feat: preserve class session navigation and scope"`. Fresh Sol/low task review, Luna/medium fixes and scoped re-review must leave zero Critical/Important findings.

## L1 final review and handoff

- [ ] Generate a whole-L1 package from the recorded pre-Task-1 BASE through final HEAD. Dispatch a fresh Sol/low reviewer with approved spec, this plan, contract review evidence, all task reports/commands and deferred-minor dispositions. Review requirements/security/data preservation/navigation/visuals, not merely passing tests.
- [ ] Resolve every Critical/Important with Luna/medium and scoped Sol/low re-review under the overall plan. Re-run covering checks after fixes, then required broader checks if the changed behavior warrants them; do not repeat unchanged checks solely for ceremony.
- [ ] Append final L1 reviewed head, checks, remaining minor disposition and local-only limits to execution ledger and manifest, then commit only those records as `docs: record reviewed L1 completion`. L2 starts only after this gate; no L2 implementation occurs here.

## Author self-review

Coverage: read/scope/cursor/period/history in Task 2; strict typed boundary in Task 3; create/list/cancel/retry in Task 4; identity/invalidation/visuals in Task 5; contract and fresh review gates in Task 1/final review. Five Review Focus cases have named owning assertions. Re-review corrections explicitly cover completed/archived SQL discovery and widget readability/creation policy; Task 4 opening is awaitable and owns exactly one post-return refresh, matching Task 5. Every product test-writing step now includes executable assertion excerpts with fixed values; fixture recording/Completer names are test-local only. Signatures and file ownership are consistent; old pending and mutation contracts remain unchanged. Tasks are independently reviewable with expected RED/GREEN commands and commit steps. No unresolved product choice; migration filename must be rechecked at Task 1. This is a written plan only: no implementation/tests executed. User review/approval of this plan is the next gate; preserve the already selected subagent method.
