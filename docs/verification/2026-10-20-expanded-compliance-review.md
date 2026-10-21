# Expanded Ministry compliance review — 2026-10-20

**Disposition: not ready to merge as completed delivery or activate against the current hosted backend.** The recovered parent requirements confirm that the remaining attendance/progress and hosted/device work is required product scope. Hosted incompatibility is now observed, rather than hypothetical. Three additional local behavior gaps were reproduced. Existing import and verification failures remain open.

## Review identity and recovered authority

- Application reviewed: `codex/ministry-production-completion` at `f2fffca489fd36f55957bba49736cb35dd31d5a6`.
- Additional requirements: `origin/main` at `c71534d` (`docs: refine unified ministry delivery plan`). The application branch was not merged or rebased during this review.
- The previously unavailable [parent design](https://github.com/CarlosMonteiroNeto/discipulado-IEADPE/blob/c71534d/docs/superpowers/specs/2026-10-18-ministry-production-completion-design.md), [parent plan](https://github.com/CarlosMonteiroNeto/discipulado-IEADPE/blob/c71534d/docs/superpowers/plans/2026-10-18-ministry-production-completion-plan.md), [design system](https://github.com/CarlosMonteiroNeto/discipulado-IEADPE/blob/c71534d/docs/integration/unified-design-system.md), and [input inventory](https://github.com/CarlosMonteiroNeto/discipulado-IEADPE/blob/c71534d/docs/integration/unified-input-inventory.md) are now recovered in that commit. The initial report's missing-document blocker is resolved.
- These documents contain older/proposed wording alongside explicit refinements. The design's “Confirmed registration entry points” section takes precedence over its earlier single-entry wording: quick convert registration plus protected student registration using shared canonical fields is the stated target. Two contextual entries alone are not a defect.
- [Exact completion contracts](../integration/ministry-completion-contracts.md), [task manifest](ministry-task-manifest.md), [execution ledger](ministry-execution-ledger.md), and the separate L1 spec/plan remain implementation evidence. The separate APK identity/access recovery plan remains a draft, not delivered functionality.

This report extends the [initial local review](2026-10-20-branch-compliance-review.md). Its 450-pass/4-failure Flutter run, 20/25 SQL scenarios, 8/9 concurrency runs, 36 analyzer diagnostics, successful web build and static preflight were executed against the same application SHA earlier in this session. They were not rerun wholesale or relabeled as new hosted evidence. The new executions below focus on previously unavailable requirements and backend facts.

## Confirmed hosted state

Target: `voqmtnqjrbugpazcimvh`, PostgreSQL 17.11. Account PAT access works. Catalog queries used the management API with `read_only: true` and explicit `BEGIN READ ONLY`; no application scope-binding RPC was called. Only definitions, schema, privileges, configuration and non-identifying counts were inspected.

| Observation | Evidence and implication |
|---|---|
| Ledger contains 18 versions, ending at `202610140018` | Twelve repository versions are absent from the ledger; this does **not** mean all twelve DDL sets are absent. |
| Base44 history/archive objects are already present | `legacy_base44_id` and four private Base44 tables exist. Hosted `ieadpe_weekly_overview` also contains the later actual-convert read logic. |
| Catalog matches repository state through `202610180002` | Generated an independent disposable local database and compared all `public/private` table columns and constraints, all private functions, and public `ieadpe_*` function definitions/security settings/execute privileges. After whitespace normalization, these compared sets have zero missing/changed/extra entries against that baseline. This does not verify historical data reconciliation, indexes, every policy, or the counter-rebuild operation. |
| Ledger and effective schema disagree | The two Base44 migration object sets are present without their ledger versions. A blind migration push could try to recreate existing objects and fail. Reconcile the ledger only after verifying the exact applied changes; do not mark unapplied migrations as applied. |
| Unified authorization is absent | Hosted `private.ministry_supervisor`, `private.ministry_can_access` and `ieadpe_get_scope` still use `ministry_grants`; `202610180003` behavior is absent. |
| Branch identity/team/session extensions are absent | No `ministry_people`, `converts.person_id/revision`, or contact `email/user_access_id`. Against the complete branch catalog: 16 column entries and 14 constraints are missing; 26 functions are missing and 22 definitions differ when private helpers are included. These are catalog entry counts, not migration counts. |
| Fourteen public RPCs are absent | Includes person/student/contact detail and mutation functions, access candidates, `ieadpe_ministry_list_class_sessions`, and `ieadpe_ministry_list_converts`. The complete list is retained in the local evidence artifacts. |
| Current permission data cannot satisfy the intended Ministry authority | 28 direction assignments, two supervision assignments, one technical administrator, and zero active `ministry_grants`. The technical administrator also lacks a legacy Ministry-supervision grant. Existing access assignments therefore do not supply the Ministry permissions required by the hosted helpers. This is derived from definitions and aggregate counts, not an observed Google-session scope response. |

The effective hosted state is therefore behind the branch's required contracts, including the shared authorization slice that predates this branch. The intended forward path starts from verified state through `202610180002`, then needs reviewed unified authorization and the nine October 19 migrations, plus corrections identified by local verification. This describes compatibility dependencies, not approval to apply them now.

### HTTP and security checks actually executed

Used the project's public key in memory; no key value was logged or written to artifacts.

| Read-only/denied HTTP probe | Result |
|---|---|
| Auth health | HTTP 200 |
| Anonymous HEAD on `converts` | HTTP 401; no personal response body requested |
| Anonymous existing congregation-directory RPC | HTTP 401 / SQLSTATE 42501 |
| New convert-list RPC | HTTP 404 / `PGRST202` — function absent from PostgREST |

All inspected public/private application tables have RLS enabled. Public application RPCs deny anonymous/PUBLIC execution and use empty `search_path` for SECURITY DEFINER functions. Explicit `has_table_privilege` inspection confirms client roles have no direct Ministry table reads/writes and authenticated users have no direct public-table insert/update/delete. Some campaign tables intentionally permit authenticated SELECT behind RLS. The `information_schema.role_table_grants` result alone was not used to infer effective privileges, because its visibility differs for the API's diagnostic role.

These checks establish anonymous denial and catalog posture. They do **not** establish allowed authenticated access, cross-congregation denial under real sessions, revocation with an existing token, Google OAuth completion, or Storage object policy behavior.

### Existing data and operational readiness

Non-identifying counts: 51 converts, 24 congregations, and zero Ministry contacts, students, classes, enrollments, sessions or attendance. All current converts are scoped; none has an over-200-character name, an archived state, or a manual discipleship flag without a start date. These aggregates help assess the proposed migration; they do not establish that legacy Firebase records never existed.

Google provider is enabled. Auth site URL is `http://localhost:3000`; the allowlist contains local web and `ieadpe://login/auth/callback` returns. A production HTTPS web origin and live new Ministry-route callbacks have not been validated. Existing Android callbacks in configuration do not prove a delivered APK can complete OAuth.

Backup metadata API returned PITR disabled and zero listed backups. No independently retained export or restore rehearsal was inspected. Recovery readiness is therefore unestablished; the API result does not prove that no external backup exists.

## Additional findings from the recovered requirements

### A. High — production client and hosted backend are incompatible

The new client uses person-backed convert-list/detail RPCs and linked Team management; the hosted API lacks those RPCs and columns. The missing convert-list function was reproduced over actual HTTP as `404/PGRST202`. Hosted Ministry helpers still require a grant source with no active rows, so imported `user_access` assignments and the technical-admin allowlist do not unlock the intended module.

This is a confirmed backend compatibility defect for this branch, and a supported explanation for the reported convert-loading/Team symptoms. The exact APK source/configuration and real signed-in account response were not observed, so those specific device symptoms are not declared reproduced.

### B. High — finalized-attendance requirement conflicts with both UI and server policy

Recovered parent design line 55 requires finalized attendance to remain readable and uneditable; Task 4 requires persisted read-only marks/progress and finalized-edit denial.

`lib/features/ministry/ui/attendance_page.dart:361–369,403–410` enables mark changes and both save actions whenever no request is in progress, without considering session status. A focused test mounted the real page with a finalized synthetic roster and expected a disabled control; it failed because `onChanged` was non-null.

This is more than presentation. `202610190007_ministry_class_receipt_replay.sql:120` rejects a finalized write only when `finalize=false`; submitting changed marks with `finalize=true` is allowed. The older contract (`docs/integration/ministry-contracts.md:94`) explicitly permits finalized corrections. Existing `ministry_academic_test.sql:250–255` requires that correction to succeed; a fresh run of the scenario passed. The browser test checks denial only with `finalize=false`, so it cannot prove the parent design's stronger rule.

Resolve this explicit contract contradiction before completing L2: either implement the parent design's immutable-finalization rule with a reviewed forward migration/UI/tests, preserving receipt replay and the separate cancellation rule, or record a separately approved correction policy in the authoritative design. Disabling the UI alone would not enforce immutability.

### C. High — ambiguous attendance retry changes payload under the same operation ID

At `attendance_page.dart:195`, `_operationId` survives a network failure; `_save` nevertheless reconstructs its payload from current marks and the clicked action (`:204–213`). After an error, mark controls and both save buttons are enabled again. The retry banner invokes `_save(finalize:false)` even if the unresolved request was finalization (`:280`).

Focused reproduction: save a draft, simulate a network failure, then click “Salvar e finalizar”. Both captured calls have the same operation ID but `finalize` changes from false to true. The exact-payload retry assertion fails. If the first request committed, the server receipt rejects the changed retry as `operation_conflict`; repeatedly clicking retry cannot settle that changed request correctly. Freeze the operation's exact payload and action until its result is resolved; revisions alone do not provide ambiguous-response recovery.

### D. High — canonical identity edits do not propagate to handoff lookup

The recovered parent plan requires canonical identity edits to appear across modules. Current person saves update `ministry_people` (`202610190001_ministry_people_identity.sql:395–399`), correctly preserving profile snapshots. However, the unchanged referral RPC still reads `converts.name/phone/address` (`202610140015_convert_student_link.sql:115–125`), and candidate search still filters/returns `ministry_students` snapshot identity (`:67–76`). Production handoff uses both RPCs.

A fresh disposable SQL scenario created linked synthetic person/convert/student rows, renamed the person using the real `ieadpe_ministry_save_person` RPC, then read the production projections:

| Projection after canonical edit | Observed result |
|---|---|
| Convert canonical detail | `Corrected Name` |
| Student canonical detail | `Corrected Name` |
| Referral list | `Original Name` |
| Candidate search for corrected prefix | Zero matches |
| Candidate search for old prefix | One match |

These are live operational selection surfaces, not historical snapshot displays. Join current canonical fields for linked identities while preserving explicit legacy fallback, scope restrictions, bounded projections and cursor semantics. Do not overwrite frozen historical snapshots as a shortcut.

### E. Required progress/history workflow is still absent

The parent design requires inspecting enrollment history/progress and reopening persisted read-only attendance/progress. `getEnrollmentProgress` exists in the repository and is used by an integration assertion, but no production Ministry UI calls it. Session discovery/navigation and backend progress tests do not complete the operator-facing L2 workflow. The manifest's deferred L2 status is consistent with this gap; it cannot be waived because L1 passed a scoped review.

## Requirement matrix after recovering the parent plan

| Required unit | Current disposition |
|---|---|
| I1/C1 — evidence and exact contracts | Parent documents recovered; local contracts exist. Hosted state is now inventoried. Resolve finalized-correction contradiction and update stale “hosted unknown” evidence. |
| V1 — unified Base44 theme/accessibility | Shared theme/components exist; previous functional/accessibility coverage passes, but two visual comparison failures remain. No new human/device visual acceptance claimed. |
| P1/P2 — canonical identity and two contextual registrations | Local implementations and tests support the main flows; handoff projection mismatch and import incompatibility violate full cross-module/backup compatibility. |
| P3 — academic detail and automatic unique extension at enrollment | Local implementation/SQL evidence supports this; full historical/progress UI is incomplete and hosted RPCs are absent. |
| E1/E2 — unified Team/contact/access lifecycle | Local linked workflow exists; hosted schema/RPC/authorization mismatch prevents activation. |
| A1/A2 — class and enrollment management | Local implementation and SQL/concurrency evidence exist; no hosted records or normal-operator hosted workflow verified. |
| F1 — automatic enrollment/attendance follow-up | Local SQL and concurrency coverage support the derived facts and genuine-visit counters. Hosted projection/identity model is absent; coupled production acceptance remains unexecuted. |
| L1 — class-bound lesson creation/discovery/cancel/navigation | Local acceptance evidence remains favorable; scoped completion is distinct from L2 and full delivery. |
| L2 — draft/finalize/read-only history/progress | Incomplete; new finalized-control and retry probes fail; finalized server policy conflicts with the recovered design. |
| H1 — hosted activation | Confirmed incompatible; migration ledger drift and recovery readiness require resolution before any update. |
| H2 — legacy records | Hosted Ministry tables are empty; source Firebase absence/import reconciliation is still unknown. Synthetic rehearsal is not real-data reconciliation. |
| D1 — full acceptance and exact Android delivery | Incomplete: local gate failures, outdated browser journey/cleanup, no authenticated hosted end-to-end acceptance, no exact delivered APK/device verification. |

## Existing local findings retained

1. Adding non-null `converts.revision` breaks the composite-record importer: two Flutter database tests and import concurrency fail with SQLSTATE 23502. The hosted database does not yet have this new column; do not describe that local integration failure as an already observed hosted import failure. Fix before applying the canonical-identity migrations.
2. The old Chromium journey registers without congregation and later transfers congregation, contrary to the current client contract. Its cleanup omits canonical-person dependencies. It remains unexecuted against a real local Supabase HTTP stack.
3. Four other standalone SQL scenarios still fail: archived campaign-scope contract drift, canonical-address snapshot assertion, and two old contact payloads missing explicit `email`.
4. Both verification gates omit the new standalone seeded identity/session scenarios and other new Ministry acceptance; F1 concurrency is omitted as well.
5. Analyzer reports 36 diagnostics; two visual suites differ from committed goldens; two Windows-specific runner tests are not portable to Linux.

None of these findings is closed by publishing documentation or obtaining a valid PAT.

## Evidence and next sequence

New evidence is under `build/verification/hosted-review/`: `inventory.json`, `security-ledger.json`, `access-summary.json`, `hosted-schema.json`, `schema-comparison.json`, `function-comparison.json`, `operations-summary.json`, `http-probes.json`, `academic-policy-recheck.log`, `attendance-contract-probes.log`, and `canonical-read-probe.log`. The focused widget test source and SQL probe are retained beside the logs. The two widget contract probes intentionally fail on current behavior; the SQL projection probe succeeds and prints the conflicting synthetic projections. Temporary databases were dropped.

Recommended sequence:

1. Resolve finalized-attendance policy against the recovered design; fix canonical handoff projections, ambiguous attendance recovery, importer compatibility, and finish operator-facing history/progress.
2. Bring acceptance tests/gates into agreement with the final contracts, resolve visual/analyzer/platform failures, and run the coupled real-local-Supabase browser workflow with bounded cleanup.
3. Establish a recoverable backup and tested restore. Reconcile the two already-present Base44 object sets with their absent ledger entries, then prepare the exact reviewed pending migration sequence and rollback plan. Do not run a blind push of all twelve ledger-missing versions.
4. After the concrete migration package is reviewed and authorized, activate compatible hosted contracts. Verify real admin/supervision/direction/denied sessions, own/foreign HTTP access and revocation, and the normal-operator workflow with isolated traceable records.
5. Reconcile the original legacy source or verify its absence; then identify/build/verify the exact Android artifact and observe install/update, OAuth and persisted journey on the delivery target.

No hosted mutation, scope binding, migration repair/application, import, user/grant provisioning, deployment or APK delivery was performed. No application code or migration was changed. The review remains incomplete for authenticated user/device behavior, but the principal hosted incompatibilities and the local gaps above are now concrete and reproducible.
