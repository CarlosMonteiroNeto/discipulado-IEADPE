> **Current assessment:** S15 and the companion plan completion map refine this in-flight design. Historical proposal/CLI wording below is retained as history; current execution uses native Luna Medium plus Sol 6.1 low review. Documents only now; no APK build or remote changes.

# Ministry corrective release design

Status: complete proposal for review; implementation and hosted changes have not started. The immutable-finalization policy below was explicitly selected by the user on 2026-10-20. Other design choices are recommendations in this proposal, not claims of deployed behavior.

## S01 Intent and authority

Deliver the existing Flutter web/Android discipleship application as one coherent person journey: registration, canonical identity, team/access, class enrollment, lesson attendance, persisted progress and follow-up. Ordinary authorized operators perform the journey through the app. Preserve existing Base44 appearance, Portuguese UI, Supabase Free constraints, genuine visits, historical records, least privilege and explicit identity links.

Application baseline: `codex/ministry-production-completion@f2fffca489fd36f55957bba49736cb35dd31d5a6`. Parent requirements are the four recovered documents in `origin/main@c71534d`, particularly `2026-10-18-ministry-production-completion-design.md` and its implementation plan. Read the [expanded verification report](../../verification/2026-10-20-expanded-compliance-review.md) and the existing completion contracts before execution.

This proposal supersedes the old allowance for editing finalized attendance, the snapshot-backed handoff lookup, and retry behavior identified in the report. It does not restart completed implementation slices. Two task-specific registration entries using shared canonical fields remain correct. Enrollment remains explicit; referral alone does not establish discipleship.

### Approaches considered

1. **Recommended: repair locally, prove upgrade, then activate.** Small forward migrations and focused UI changes preserve validated behavior; hosted activation waits for consistent contracts, green verification and recovery evidence.
2. **Hosted-first repair.** Could restore some current permissions sooner, but exposes local import/finalization defects and risks replaying DDL already present without ledger entries. Reject for this release.
3. **Rewrite Ministry or replace the backend.** Discards working security/concurrency behavior and expands migration risk without evidence of a platform limitation. Reject.

### Elicitation record

Inception: recover usable integrated delivery. Elicitation: user request, parent spec, contracts, code and executed local/hosted evidence. Elaboration: exact contracts below. Negotiation: user selected immutable finalized calls with cancellation/replacement. Specification: this document. Validation: test matrix, self-review and user review. Management: stable requirement IDs and task mapping. The original Firebase export/absence, actual APK identity, physical-device access and usable worker profile remain external evidence questions; they do not prevent this written plan.

## S02 Engineering baseline and execution boundaries

The installed local skill source is `/workspace/.config/opencode/vendor/superpowers`, revision `ace9e92ac19d7cb485e8d946ee7b828177e46d08`. These files were actually read, rather than inferred from names:

| Skill | Design obligation applied here |
|---|---|
| `brainstorming` | Intent, alternatives, explicit product decision, decomposition and written review before implementation |
| `requirements` | Separate functional/domain/NFR requirements; resolve scope, comprehension and volatility risks; measurable acceptance |
| `design-oo-ux` | Composition, typed interfaces, one UML sequence view, scope/architecture exit criteria |
| `coding-standards` | Entry/Process/Exit boundaries, validated inputs, local state and narrowly owned changes |
| `verification-test` | Positive/negative partitions, boundaries, retry/race cases, assertion-based RED and regression evidence |
| `quality-gate` | Distinguish process assurance from executed product checks; no silent waivers or inferred release readiness |
| `apple-design` | Purpose, agency, familiarity, feedback, predictable return paths, large text and reduced motion; retain approved Base44 styling |
| `a11y-ethics` | POUR, actionable errors, privacy, keyboard/semantics and human/device evidence limits |
| `cloud-deploy` | PaaS shared responsibility, IAM, encryption, quotas, monitoring and demonstrated recovery before cutover |
| `agile-loop` | Small reviewable outcomes, dependencies, Definition of Ready/Done; no artificial Scrum ceremonies |
| `flutter-app-pipeline`, `two-model-sdd-pipeline`, `writing-plans` | Permanent complete JSON plan; script-owned dispatch/gates, exact interfaces and acceptance, scoped RED/GREEN and closing review |

Reusable baseline: existing app/theme, locked dependencies, Supabase RPC patterns and retained Base44 reference. No new package, template, external skill, paid service or runtime dependency is selected. New-project template search and package scoring are inapplicable to this corrective brownfield scope; introducing a dependency reopens that decision.

Resolved profiles: `generic@1.0.0`, `user-interface@1.0.0`, `flutter-forms@1.0.0`. Applicable requirements are input contracts, error handling, accessibility and form validation. `input-mask` is explicitly omitted: no new phone/postal mask is needed; date-only formatting remains distinct from validation. The installed resolver returned no unresolved profile dependencies/questions.

Execution readiness is not established by installed skill files. The observed `scripts/cmd` lacks executable permission (invocation through Bash works); packaged role examples use Terra 5.6/low and Sol 5.6/high; project hooks reference an obsolete Windows checkout. Do not install/activate those defaults silently. The user's latest direction explicitly selects the adapted execution protocol below, replacing those example model/dispatch defaults for this release.

Known baseline failures block full-suite approval. First restore the baseline through the explicitly described bootstrap work in the plan, recording focused results and remaining failures honestly. Bootstrap units receive a Sol review with their remaining baseline failures plainly disclosed; they receive a complete integration review after the full baseline is green. No baseline waiver is proposed. Then run the corrective JSON through the same adapted director/worker protocol. Do not invoke the original automatic backend entry point in parallel or report bootstrap reviews as compiler-approved pipeline completion.

### Adapted director and worker protocol

This is an explicit user-selected adaptation of the installed pipeline's roles and engineering gates, not a claim that the original Script CEO runtime is running:

1. **This Codex session is strategist/director.** It writes the spec and complete plan, prepares each bounded brief, sequences work, collects raw evidence, arbitrates TEST_DEFECT/contract conflicts, coordinates correction loops and performs the whole-product review. It does not claim to change its own model/effort.
2. **Coder is OpenCode CLI**, requested model `opencode/deepseek-v4.1-flash-free`, through the actual `opencode-cli-delegation` skill recovered from the user-provided environment bundle and made available at `/workspace/.agents/skills/opencode-cli-delegation/SKILL.md`. CLI version observed: 2.0.32. Existing CLI login/provider configuration is used; no credential inspection/copy or direct provider API call. A fresh task gets a fresh CLI session; corrections resume that task's reported session ID. Use the identical model with `--standalone` only for the documented managed-server/port conflict. Authentication/provider/model failures are BLOCKED, never a silent model/backend substitution.
3. **Stage reviewer is a native read-only subagent**, explicitly requested `gpt-6.1-sol`, `reasoning_effort=low`, clean context. Each review gets the accepted brief/spec sections, exact candidate identity, full relevant diff and director-verified test output. It returns APPROVED/SEND_BACK/ESCALATE, severity/file/line/trigger, acceptance gaps and minor disposition. Do not claim runtime metadata beyond what the tool confirms. The director remains the final holistic reviewer as requested.
4. Briefs identify OpenCode as the pipeline coder and include exact task ID, allowed existing/new test files, dependencies, interfaces, relevant pinned engineering skill paths, test commands, expected behavior, no hosted writes/no commit/push, and a structured result contract. Coder owns investigation, meaningful RED, minimal GREEN, self-review and evidence. It must report actual changed files, commands/exit codes/raw evidence paths, unresolved issues and CLI session identity; a completion sentence alone is not evidence.
5. Director records initial worktree state, uses argument-safe CLI invocation from the resolved project root, retains JSONL/raw logs outside tracked product files, then inspects the actual diff and runs/verifies authoritative gates. Scope drift is returned to the same coder rather than silently adopted. The directory brief is an application-level instruction, not a claimed OS sandbox. Do not pass privileged Supabase variables or production payloads into local coder requests; preserve provider proxy/CA settings.
6. Director sends Critical/Important findings to the same CLI coder session, reruns affected checks, and requests a new Sol 6.1/low review of the corrected candidate. Only director arbitration changes acceptance; neither coder nor reviewer may waive finalized immutability or weaken permission assertions. Minors are explicitly resolved or recorded for closing. No provider error causes Codex to take over product coding.
7. Record task/base/candidate digests, requested and observed worker/session identity, commands/exits, RED/GREEN evidence, review verdicts and rulings in an append-only execution record. Git commits require separate user authorization under the delegation skill; until then bind reviews to HEAD plus a full working-tree/new-file digest. Push, merge and hosted activation remain separate actions. No automatic commit/push defaults are inherited from packaged scripts.

The director may use deterministic helpers such as `scripts/cmd`, plan validation and profile resolution. It owns the adaptation state instead of writing fabricated Script CEO `task_complete` events. Starting the original autonomous runtime later requires a deliberate handoff with one authoritative ledger; do not run both controllers over the same branch. The user has selected this execution method, so no further execution-method question is needed for the written plan; product implementation begins after review of the documents.

## S03 Requirements and quality priorities

| ID | Type | Observable requirement |
|---|---|---|
| R01 | Functional | Import accepted legacy backup rows after the revision extension; preserve resumability, duplicates, tombstones and weekly counters. |
| R02 | Functional/domain | Current identity edits appear in referral/candidate operational reads; preserved historical snapshots stay unchanged. |
| R03 | Domain | A finalized call's roster/marks are immutable. Exact receipt replay remains valid. Cancel then create a linked replacement to correct it. |
| R04 | Functional/reliability | An ambiguous attendance result retains one immutable operation ID, payload and intended action until resolution. |
| R05 | Functional | Operators inspect enrollment history and persisted per-enrollment progress, including closed enrollments. |
| R06 | Security/compatibility | Shared authority comes from allowlist/user_access; Ministry scope includes active congregations only; campaign scope retains its established archival compatibility. |
| R07 | Usability | Session display name is presentation only; unavailable Team access stays in Admin with an explicit refresh action. |
| R08 | Verification | Local SQL, concurrency, widgets, browser and analyzer gates cover the new contracts and fail closed; no visual-baseline bypass. |
| R09 | Operations | Detect actual hosted schema independently of its ledger, prove recovery and rehearse the exact upgrade before activation. |
| R10 | Migration/privacy | Reconcile legacy sources by stable identifiers or retain a named blocker; no name-only merge or fabricated conversion history. |
| R11 | Delivery | Identify and verify the same APK's package/version/certificate/hash, OAuth, navigation and fresh-session persistence on an available target. |

NFR priority: data integrity/security before activation speed; understandable recovery before UI brevity; reuse bounded components instead of broad refactoring. Additional reads are bounded and on demand; no N+1 progress fetch for every student. No numeric latency/SLA promise is invented without measurement. Responsive/accessibility targets are widths 360/768/1440, 200% text, 48 logical-pixel interactive targets, text contrast 4.5:1, meaningful UI boundaries 3:1, keyboard focus and reduced-motion behavior. Catalog-backed UI checks do not substitute for human/screen-reader/device checks.

## S04 Import compatibility

Reserve forward migration `202610200001_import_revision_compatibility.sql`; recheck numbering immediately before implementation. Replace the importer body, not historical files. Explicitly initialize new inserted convert `revision=1`; do not accept a client revision or expand the existing accepted legacy import payload.

Maintain existing authorization, stable `internal_id`, actor/operation receipt, advisory lock order, scope/week counter locks, duplicate/tombstone results and no personal values in receipts. Existing duplicates must not reset revision/person links/history. Keep imported legacy identity snapshots and `person_id=NULL` under the current legacy import contract; do not synthesize conversion dates or name-based canonical links as part of this bug fix. This does not complete canonical reconciliation of imported legacy rows: H3 must map them by stable source keys before claiming editable canonical delivery for that source. Preserve canonical fields in the supported export/import mapping; any unsupported source shape stays explicitly blocked.

## S05 Canonical handoff reads

Reserve `202610200002_canonical_handoff_reads.sql`. Preserve public RPC names/envelopes, authorization, signed cursor resources, page bounds and minimal projections:

- `ieadpe_ministry_list_convert_referrals(request jsonb) -> jsonb`, request `{congregation_id,limit,cursor}`, result `{items:[{convert_id,congregation_id,name,phone,address,conversion_date}],next_cursor}`.
- `ieadpe_ministry_list_convert_student_candidates(request jsonb) -> jsonb`, request `{congregation_id,name_prefix,limit,cursor}`, result `{items:[{student_id,name,phone,address}],next_cursor}`.

Linked identity reads join `ministry_people` by both person and congregation. Name/phone/address come from canonical fields even when a canonical value is null; null must not resurrect an old snapshot. Only an unlinked legacy row uses the existing snapshot fallback. Candidate prefix/filter/order/cursor tail use the same canonical-or-legacy normalized name. Do not auto-match identities by the name used for searching.

Referral `address` retains its existing nullable-string type: join nonblank canonical `street,district,city,state_code,postal_code` components with `, `, returning null if none. Candidate `address` remains the structured nullable Address object with the established keys. Document the formatter once; do not expose additional person/academic/access fields. Historical convert snapshots and frozen roster labels are not rewritten.

## S06 Immutable finalization and replacement

User decision: **finalized calls cannot be edited; corrections cancel the original and register a replacement**. This supersedes the old finalized-correction allowance and its SQL assertion.

Reserve `202610200003_attendance_integrity.sql`. `ieadpe_ministry_save_attendance(uuid,jsonb)` keeps its existing payload/result. After authorization and exact-receipt replay handling, any new operation targeting finalized/canceled sessions is rejected with `session_finalized`/`session_canceled` (23514), regardless of `finalize`. No roster/mark/revision/event/projection change is permitted on rejection. Exact successful finalization replay still returns its receipt after finalization; revoked access remains denied. Preserve frozen-roster validation, class/session locks and future-date finalization guard in `America/Recife`.

On first roster freeze, capture the current same-congregation canonical person name for linked students; only unlinked legacy students use the compatibility name. Renames after a freeze never rewrite retained roster labels. Cover rename-before-freeze, rename-after-freeze and legacy fallback without changing eligibility or lock order.

Cancellation uses the existing explicit confirmed command, expected revision and exact retry semantics. It preserves original roster/marks and excludes only that session from derived progress/follow-up. Genuine visits and other valid presence remain effective.

Make replacements auditable without a new bulk “cancel-and-recreate” RPC:

- Add nullable `ministry_sessions.replaces_session_id uuid REFERENCES ministry_sessions(id) ON DELETE RESTRICT`; existing rows remain null. A partial unique index permits at most one direct replacement per original.
- Existing `ieadpe_ministry_create_session(operation_id,payload)` adds optional `replaces_session_id`; absent/null preserves ordinary creation. Result remains `{id,revision,...existing fields}`. Repository `createSession(..., String? replacesSessionId)` and strict gateway key validation carry it.
- A replacement requires an already acknowledged canceled predecessor in the same authorized congregation, class and lesson date, no existing direct replacement, and the normal active-class/in-period creation rules. Reject missing/foreign/mismatched predecessor as `academic_invalid` (22023), and duplicate replacement/live-date conflict as `academic_conflict` (23505). Parent linkage cannot be edited. Lock the existing class and predecessor before validation; check exact receipt replay before new-operation state constraints. Normal UUID identity makes self-link impossible; canceled-before-create plus immutable one-parent linkage prevents cycles/forks.
- If a replacement is later canceled, replace that latest session, forming a chain. Historical completed/archived classes remain readable/cancellable; creating a replacement there is disabled under normal active-class creation policy, with an actionable explanation. Do not silently reactivate a class.
- Session detail (`get_session_attendance.session`) and class-session summaries add nullable `replaces_session_id` and nullable `replacement_session_id`. The former is the stored predecessor; the latter is the authoritative direct child's ID, computed from the unique reverse relationship in the same bounded SQL read, even if that child is on another page or is itself canceled. Existing cursor binding/order and other fields remain unchanged. Extend Session/MinistrySessionSummary models/codecs with nullable `replacesSessionId/replacementSessionId` and all exact-envelope consumers together. Do not infer absence of a child from the currently loaded pages.
- Original and replacement both remain visible, with status and reference. “Registrar substituta” appears on an eligible canceled session whose authoritative `replacement_session_id` is null. Prefill fixed class/date; no marks are copied or auto-finalized. If another actor creates the child after that read, show the safe conflict and refresh eligibility/reverse link; never automatically choose a different parent, repeat with a new operation ID or create a fork. The replacement's first save freezes the normally eligible roster for that lesson date, which may differ from the retained original if enrollment history has changed. Show that fact; never overwrite the original roster to force equality.

Finalized/canceled attendance pages expose status and read-only text marks, not editable controls/save actions. Cancellation belongs to the existing session-list confirmation flow. The finalization action explains “Após finalizar, a chamada não poderá ser editada. Para corrigir, cancele e registre uma substituta.” No false success before server acknowledgement.

## S07 Attendance operation ownership

Compose `AttendancePage` with a small feature-owned `AttendanceSaveController`, not a global retry facility. An immutable `PendingAttendanceSave` owns protected generation, selected congregation/class/session, operation ID, expected revision, deep-copied marks and `finalize`. `MinistryRepository.command` remains the transport port.

Entry: validate current context and an editable open session. Process: capture the exact request once, submit, classify result. Exit: acknowledge and reload persisted state, retain unknown request, or surface a definite rejection.

States: `idle -> submitting -> acknowledged|unknown|rejected`. While submitting/unknown, disable draft changes and alternate actions. “Tentar novamente” resends the captured request, including the original finalization flag. It never reconstructs a request from current controls or changes operation ID. Only acknowledged success, or a proven non-committing validation/stale failure followed by explicit fresh read/decision, clears a pending command for another intent. Network timeouts/5xx and receipt conflicts do not prove non-commit. Scope/identity loss synchronously clears protected state and discards late replies; a future authorized visit begins with a fresh server read, not automatic resubmission. Leaving an unknown operation warns that it may have completed; no silent cancel or automatic resend on return.

The controller is owned by the selected AttendancePage state. Same-page rebuild/resume retains it while the protected context is valid. A deliberate page pop disposes/clears it after the unknown-outcome warning; it is not transferred to another page or persisted to disk. The already-sent server operation may still complete. Returning constructs a new controller after an authoritative roster read, with no old automatic resend. Signout/scope loss clears immediately without a navigation warning delaying security invalidation. Process termination likewise cannot guarantee cancellation or preserve an in-memory request.

Public feature interface: `Future<void> submit({required SessionNavigationContext context, required int expectedRevision, required Map<String,AttendanceStatus> marks, required bool finalize})`, `Future<void> retryPending()`, `void clear()`, read-only `pending/isBusy/hasUnknownResult`. Bind to the existing protected boundary and injectable operation-ID factory. A rejected call never receives a fabricated success response.

## S08 Enrollment history and progress

Reserve `202610200004_student_enrollment_history.sql` for the missing bounded read; reuse the existing progress calculation.

`ieadpe_ministry_list_student_enrollments(request jsonb) -> jsonb` takes exactly `{congregation_id:UUID,student_id:UUID,limit:int 1..100,cursor:string|null}`. Return `{items:[{id,class_id,class_name,start_date,end_date,status,revision}],next_cursor}` for that student's same-scope active/completed/withdrawn enrollments. Dates are strict date-only; positive revision; nullable end date. Order `(start_date DESC,id DESC)`, limit+1 continuation, signed cursor bound to actor/resource `student_enrollments`, congregation, student and last date/id. Authorize before existence lookup; missing or foreign student is `student_not_found` (22023), invalid envelope/limit/cursor uses existing safe error conventions. No Auth IDs, other students or unbounded histories.

Add `StudentEnrollmentSummary` in `lib/features/ministry/data/ministry_codec.dart`, alongside the existing read-summary DTOs, and `MinistryRepository.listStudentEnrollments({required congregationId,required studentId,int limit=50,String? cursor})`. Reuse `getEnrollmentProgress({required congregationId,required enrollmentId}) -> EnrollmentProgress` for a user-selected enrollment only. Add a reusable `EnrollmentProgressPanel` in student detail and class roster/detail; no simultaneous progress RPC for every row.

Display present/absent/excused and `present/(present+absent)` using existing server/codec contract; denominator zero renders “Sem aulas avaliadas”, not 0%/100%. Count only finalized non-canceled sessions; excused/unmarked do not affect the denominator. Closed enrollments retain inspectable history. Cancellation/replacement requires fresh progress/follow-up reads; never locally increment counters. All reads/pagination discard obsolete scope/identity responses.

## S09 Scope compatibility and account presentation

Reserve `202610200005_campaign_scope_compatibility.sql` for the observed archival contract drift. Keep all verified-email/contact-email predicates and current access locks. Campaign `congregation_ids` retains direction assignment IDs including archived congregations, matching the established scope contract; Ministry IDs and active picker exclude archived congregations. This is a response compatibility rule, not permission to write archived catalogs or academic records. Global authority remains allowlist/user_access; `ministry_grants` remains non-authoritative after unified activation. Do not broaden access based on contact title, metadata or client flags.

Complete the bounded APK recovery behavior already drafted: greeting selects trimmed nonblank string `full_name`, then `name`, else neutral “Olá!”. Do not fall back to email or treat metadata as authority. Admin's Team entry receives `canOpenTeam=scope.hasMinistryAccess`; inconsistent admin-only scope keeps the operator in Admin with “O servidor não confirmou acesso à equipe. Atualize seu acesso para tentar novamente.” and “Atualizar acesso”. Preserve routes/authority; do not invent Ministry flags in the client.

## S10 Architecture sequence

Use one UML sequence view: the primary risk is time/order around ambiguous results and publication, not a new class hierarchy. Widgets own presentation, the composed controller owns pending intent, repositories own typed transport, RPCs own authority/transactions, and read projections own canonical identity/derived facts.

```mermaid
sequenceDiagram
    actor Operator
    participant UI as AttendancePage
    participant Pending as AttendanceSaveController
    participant Repo as MinistryRepository
    participant SQL as Transactional RPC
    Operator->>UI: Finalize open lesson
    UI->>Pending: Capture immutable intent
    Pending->>Repo: Same operation ID + exact payload
    Repo->>SQL: Authorized transaction
    SQL->>SQL: Receipt replay or lock/validate/finalize
    SQL--xRepo: Response lost
    Repo-->>Pending: Unknown outcome
    Pending-->>UI: Retain request; disable changed intent
    Operator->>UI: Retry
    UI->>Pending: retryPending()
    Pending->>Repo: Identical request
    Repo->>SQL: Replay
    SQL-->>Repo: Original receipt
    Repo-->>UI: Acknowledged; reload read-only marks/progress
    Operator->>UI: Correct by confirmed cancellation
    UI->>SQL: Existing cancel command
    SQL-->>UI: Canceled; history retained
    UI->>SQL: Create same-class/date linked replacement
    SQL-->>UI: New open session; original unchanged
```

Conception exit: scope and immutable policy clear. Elaboration exit: exact envelopes, lineage, errors, lock/replay order and dependency graph agree; no unresolved contract handed to workers. Use existing widget fixtures as interactive mid-fidelity prototypes; phone/desktop captures and real-device inspection complete high-fidelity acceptance. No unrelated theme overhaul, gesture system, audit platform or offline mutation queue.

## S11 Verification and release gates

SQA: pinned skills/profiles, contracts, allowed paths, review packages, recorded decisions and authoritative source/ref. SQC: actual tests, analyzer/build, HTTP allow/deny, restore rehearsal and device observations. No ISO certification is claimed. Quality goal is correct persisted journey without cross-scope exposure; measures are pass/fail per requirement and evidence category, not a vanity aggregate pass count.

Every changed behavior receives a meaningful assertion-based RED, focused GREEN, negative/scope cases and relevant boundary/replay/race coverage. Compile/load failures are environment/test defects, not behavior RED. Test partitions include draft/finalized/canceled; 0/1/100/101 roster/page/capacity boundaries as relevant; null/blank/malformed fields; 0/1,6/7,29/30,89/90 reminder/completion boundaries; same-operation identical/different payload; changed identity/scope; and both meaningful transaction commit orders. Preserve one active enrollment/student, historical capacity, frozen roster and manual terminal safeguards.

Centralize executable verification cases in a shared manifest consumed by Bash and PowerShell. Include every standalone SQL scenario, required pre-migration seed ordering, all concurrency suites and portable runner tests. Unknown/unlisted SQL files fail coverage validation. Neither gate probes hosted endpoints as a substitute for local acceptance. The real-local Supabase/Chromium journey must use current registration/enrollment/replacement contracts and cleanup all run-owned canonical dependencies. No missing prerequisite or test failure is relabeled PASS. Full suite/analyzer/local browser acceptance block activation; zero open Critical/Important findings and explicit minor disposition block closing.

Visual acceptance preserves Base44 branding and shared tokens, text status, focus, WhatsApp affordances and user scaling. Keep standard immediate feedback and reversible navigation, avoid artificial delays/new decorative motion, and honor reduced motion. Inspect actual/golden differences before promotion; pin SDK/font identity rather than widening tolerances or refreshing blindly. Test captures go to build artifacts; normal tests do not rewrite tracked documentation screenshots.

## S12 Hosted activation and recovery

Observed target is `voqmtnqjrbugpazcimvh`: ledger ends at `202610140018`, but inspected columns/constraints/functions match through `202610180002`; unified authorization and October 19 identity/session contracts are absent. Fourteen required public RPCs are missing; convert list returns PGRST202. There are 51 converts, 24 congregations, 30 access assignments, one admin, no active Ministry grants, and no current academic records. These facts must be rechecked at execution; they are not fixed constants for authorization or migration.

Build a private, reviewable activation package before asking to apply it: target identity, exact source SHA, migration hashes, actual-state classification, required grants, backup/restore evidence, expected counts, execution channel and stop/rollback rules. Read-only inventory must distinguish `recorded+present`, `unrecorded+fully-equivalent`, `absent`, and `partial/conflicting` per migration. A partial/conflicting object fails closed. Never infer full application from a single column or the ledger alone. Compare required indexes, RLS policies, function/table grants, and migration data transformations as well as columns/definitions.

For the two unrecorded Base44 versions, prove complete equivalence and reconcile/rebuild aggregate guards as needed, with authorization, before ledger repair. Do not replay duplicate CREATE/ALTER statements or mark unknown changes applied. Then rehearse the exact ordered missing sequence beginning at `202610180003`, the nine October 19 files and these corrective forward migrations on an isolated target with production-shaped synthetic data. Verify partial-resume behavior and old client/new server compatibility; coordinate activation so an incompatible old APK cannot keep writing to changed envelopes. Unsupported compatibility blocks cutover; never add unrestricted table-read fallbacks.

Recovery: management API listed zero backups/PITR disabled, so obtain an encrypted database backup and relevant Storage inventory/backup through an authorized channel, restore into an isolated destination, verify counts/constraints/links/object access, and retain digest plus recovery procedure. Do not place private exports/tokens/SQL response rows in Git, logs, prompts or Flutter defines. App XLSX export is not a database/Storage backup. Do not assume an external backup is absent merely because API metadata lists none.

Hosted activation is an explicit operational stage after the local package is complete and reviewed; current authorization is planning only. The future operator must confirm the concrete package/target and user authorization before writes. Managed credential injection may use placeholders: verify the selected SDK/API/CLI channel without extracting/bypassing injected secrets or assuming CLI format validation will accept them.

Acceptance uses real admin/supervision/direction/denied sessions with isolated run-owned records, exact own/foreign allow/deny, existing-token revocation, schema/RPC checks, fresh-session journey and traced cleanup. Do not invoke `ieadpe_get_scope` as a read-only inventory probe because it binds access rows; observe it through the explicitly authorized app-session test stage. Retain only scope booleans/ID counts and safe codes. Google/Storage/callback verification remains separate from account PAT access.

Retain Supabase as managed PostgreSQL/Auth/private Storage and the existing static-web/Android clients; no new VM/serverless/geo-replication architecture. Operator responsibilities are IAM/grants, TLS, secret hygiene, quotas, backup/restore, incident contacts, compatibility and patching. Provider replication is not an operator backup. Record current Free-tier quotas/capacity and alerts from actual service configuration rather than inventing paid guarantees.

## S13 Legacy evidence and Android delivery

H3 requires an authorized legacy export shape or verified source absence. Empty current Ministry tables do not prove Firebase was empty. Map only stable source IDs and explicitly reviewed congregation/person decisions; preserve ambiguous rows and manual history. Rehearse repeat import, counts/links/attendance, rollback and canonicalization before any real import. If the source remains unavailable, record H3 as BLOCKED and withhold complete legacy-delivery claims; continue independent local work.

Identify the installed artifact's source/configuration when available; otherwise treat the new APK as a candidate. Build with public Supabase URL/key only and approved existing signing continuity, increment version, record SHA-256/package/version/certificate, and verify install/update, Google return, navigation, large text, logout/revocation and persistence after reopening. The same artifact must complete the coupled registration/enrollment/finalization/follow-up/cancellation/replacement/progress journey against the intended backend. Human/device checks may remain blocked but cannot be inferred from widget tests. Publishing, merge and delivery destinations are separate explicit actions, not defaults inherited from historical Taildrop instructions.

## S14 Acceptance ownership and stopping rules

Local correctness, hosted compatibility, legacy reconciliation and device delivery have separate dispositions: PASS, FAIL, BLOCKED or INCOMPLETE. All R01–R11 must have mapped tasks and observed evidence for complete delivery. A fresh semantic review examines both code and whether tests actually encode the requirement; a test requiring finalized corrections must be changed only because the user selected the superseding policy, never to hide a failure.

Stop the affected stage for contract ambiguity, missing worker/runtime capability, failed restore, schema drift, unknown target, new security/integrity failures or incomplete cleanup. Do not stop independent planning/local work because a hosted/device prerequisite is unavailable. No broad redesign, new backend, name merge, invented presence, duplicate person entry, secret in artifacts, unauthorized hosted write or automatic branch merge is part of this proposal.

Self-review: confirmed decision is explicit; parent/current contradictions are resolved for future implementation; failure/unknown behavior and compatibility boundaries are defined; every requirement is mapped in the accompanying plan. Implementation remains subject to review of these concrete documents.


## S15 Completion assessment and bounded delivery clarification — 2026-10-20

Authored by native Sol 6.1 low for review only. This is an addendum to the in-flight design, not a replacement project. The companion plan's task completion map must be read first. Existing S12/S13 and H1–H3/D1 already own recovery, legacy reconciliation and Android delivery; the following pins their acceptance evidence. No product implementation, build, remote mutation, key generation, commit or push occurs in this assessment. The user's current execution method supersedes all older CLI wording: native Luna Medium implementers, native Sol 6.1 low task reviewers and an independent final whole-product reviewer; no OpenCode.

A functional downloadable APK means successful end-to-end installation and use against intended project `voqmtnqjrbugpazcimvh`, with the contracts below, durable fresh-session reads, correct release identity and verified download bytes. A candidate compile or task approval is not completed delivery. These criteria refine existing R01–R11 rather than adding unrelated features.

## Product acceptance contracts

| ID | Required outcome and proof |
|---|---|
| A1 identity | Real Google login completes SDK PKCE on cold and warm Android callbacks `ieadpe://login/auth/callback`; cancel/denial returns usable retry. Greeting uses trimmed nonblank string `full_name`, then `name`; missing/malformed metadata displays `Olá!`, otherwise `Olá, <name>!`. No email fallback or metadata-derived authority; user switch clears old greeting/data. |
| A2 scope/Team | Real server-confirmed global manager obtains intended Ministry scope through reviewed SQL authority. Admin-only inconsistent snapshot stays in Admin, displays `O servidor não confirmou acesso à equipe. Atualize seu acesso para tentar novamente.` and `Atualizar acesso`; no forbidden navigation or manufactured flags. Direction/supervision/registrar, cross-congregation denial and revocation are verified through actual authenticated sessions. Directory roles/names do not grant login authority. |
| A3 converts | Authorized list, detail, registration/edit and canonical handoff use required RPC envelopes including identity/revision and effective follow-up fields. Existing data loads, genuine empty states differ from RPC/permission/decoder errors; no empty-data masking, relaxed decoder, unrestricted table fallback or RLS bypass. |
| A4 registration/identity | Quick convert registration and protected student registration coexist using canonical person fields. A non-convert student creates no fabricated conversion/event; academic extension is unique in scope. Explicit same-scope identity links preserve source UUIDs and histories; no name/phone-based or cross-source inferred merge. |
| A5 Team/classes/enrollment | Authorized Team contact lifecycle and explicit contact/access linking, verified email binding, revoke behavior; class create/edit/detail/enroll/close/reopen/archive guards and bounded enrollment history work through persisted RPCs. Roles, revision conflicts and retries match exact contracts. Permission changes/import remain separately approved actions. |
| A6 sessions/progress | Class-scoped session discovery/create/edit; attendance draft/finalize/reopen read-only history; finalized/canceled rows reject new saves while exact receipts replay. Cancellation retains history; replacement is explicitly linked with no copied roster/marks. First freeze captures canonical names once. Progress counts only finalized qualifying marks; denominator present+absent, null percentage for zero. |
| A7 retries/follow-up | Ambiguous attendance retry preserves immutable operation ID, payload, finalize intent and actor/scope generation; no changed-payload replay. Late responses cannot cross logout/scope/session boundaries. Definite rejection requires fresh read plus explicit decision. Follow-up derives qualifying attendance/enrollment without inventing visits or bypassing manual thresholds. |
| A8 durability/platform | Close/relaunch, reconnect and a second authorized session re-read persisted records/history/progress; no fixture-only success or protected record/photo cache across user loss. Android photo/Storage and XLSX SAF choose/cancel/write/flush/open (including accents) work where exposed by parent flows. 360px/200% text, keyboard and reduced-motion checks preserve usable actions. |
| A9 delivery identity | One signed release APK has exact package/version/minSdk/targetSdk/ABIs, source SHA plus reviewed dirty-tree digest, dependency/toolchain/configuration identity, APK SHA-256/size, certificate SHA-256, verification output, installed package/certificate evidence and working approved download URL whose downloaded bytes match. No debug certificate; fresh-install and same-certificate update preserve intended behavior/data. |

## Recovery and hosted compatibility design

Prepare an encrypted database backup including schema/data and required Auth/role/config recovery information, plus Storage bucket/object inventory and recoverable bytes/policies. Retain hashes, timestamp, encrypted location/access owner, recovery point, measured restore duration and operator-approved RPO/RTO. Restore into isolated approved infrastructure, validate counts/constraints/RLS/links/Auth recovery constraints and representative Storage object access. A provider metadata endpoint returning no usable backup and an application XLSX are not recoverability proof. Never put dumps/PII/secrets in public artifacts.

Reconcile original Firebase with a reviewed export or owner-attested, source-inspected verified absence. Preserve text source IDs, frozen attendance/names, archived/tombstoned rows, links and counts; quarantine ambiguous mappings. Reconcile Base44 input/archives and current Supabase totals, duplicates/events/counters. Use synthetic fixtures for development, protected evidence for real sources. An import requires its own reviewed mapping, dry-run discrepancies, restore proof and approval.

Before cutover, refresh read-only catalog/ledger/invariants through authorized credentials. Do not invoke `ieadpe_get_scope()` as a diagnostic read: it may bind access rows. Compare complete semantic fingerprints (columns, constraints, indexes, policies, RLS, function definitions/signatures/grants and data invariants). Prove the two Base44 migrations are fully applied, including data/counter/guard effects, before proposing exact ledger reconciliation for `202610180001` and `202610180002`. No blind repair or duplicate replay. Expected forward chain from proven 180002 state is `202610180003`, `202610190001`–`202610190009`, `202610200001`–`202610200005`; unknown/noncontiguous drift stops the procedure. Pin checksums and resume only an exact recognized prefix.

The cutover package contains target identity, refreshed inventory, exact SQL/order/checksums and any separate ledger commands, backup/restore proof, source reconciliation, approved operator/test accounts, old-client write-pause confirmation, maintenance timing/owner, smoke queries and stop/rollback criteria. Stop on schema drift, failed restore, count/link mismatch, authority regression, unpaused old writers or integrity/security failure. Freeze writes, preserve logs/source and restore first into isolation; reconcile post-backup deltas before a separately authorized production restore or forward repair. Do not drop data or run down-migrations automatically. Monitor authorization/RPC errors, counts/links, quota and Storage after activation.

## OAuth and artifact policy

Inspect intended Supabase URL/project binding, provider enabled state, Google Cloud project/client ownership, audience/basic scopes (`openid email profile`), service redirect `https://voqmtnqjrbugpazcimvh.supabase.co/auth/v1/callback`, exact app return allowlist and Android manifest intent handling. Localhost site URL/provider-enabled evidence does not prove live Android authentication. Google provider secrets stay solely on Auth service. Confirm explicit admin UID/verified email/current grants through protected evidence; never grant based on a greeting.

Owner must approve package `br.org.ieadpe.ieadpe_converts`, version increment and signing custody/continuity before generating or using a release key. Locate and verify any previous distributed certificate first; a new incompatible key cannot update an installed package. Keep keystore/passwords outside repo, encrypted backup and recovery owner; retain only public certificate fingerprints. Build using only public Supabase URL/publishable configuration, never PAT/service role/SQL password/Google secret. Require `apksigner verify --verbose --print-certs` and package inspection. Emulator with Google-capable browser/Play image and an authorized physical Android device must become available; actual device callback and persistence checks cannot be replaced with fixtures.

## Approval gates and prerequisites

| Gate | Concrete evidence before asking |
|---|---|
| G0 written design/plan review | These self-reviewed documents, scope/acceptance matrix, known blockers and native agent method. Review is not execution or release approval. |
| G1 hosted recovery/ledger/migration cutover | Exact cutover package above, successful isolated restore, fresh complete parity/drift report, rehearsal, rollback owner/window and commands. Approval names target and exact mutation set; ledger repair is explicit. |
| G2 grants/import/Google changes | Exact account roles/scopes and consent, reviewed source mapping/dry run/conflicts, or exact Google/Supabase setting diff and callback proof requirements. Separate changes cannot be smuggled into G1. |
| G3 key/signing policy | Existing-certificate search, package/version, custody/backup/update policy, named owner and exact signing configuration diff. No key generation before authorization. |
| G4 deployment and publication/download | All prior gates, final independent review, final suite/device/hosted acceptance, exact APK digest/certificate/source identity, approved destination/audience/retention and download access policy. Backend deploy and artifact publication are individually explicit, even if reviewed together. |

Only planning documents change now. Later agents prepare each concrete package before asking; stop only the dependent action while continuing authorized independent local preparation. No approval is inferred from elapsed time or credential presence.


### Assessment evidence qualifiers

Branch `codex/ministry-production-completion` remains at `f2fffca489fd36f55957bba49736cb35dd31d5a6` with uncommitted work. The current-session read-only check supplied by the director confirms ACTIVE_HEALTHY, ledger 18 migrations through `202610140018`, selected required RPCs `ieadpe_get_scope`/`ieadpe_ministry_list_students` present, convert-list HTTP 404, identity markers absent, Auth/Storage health HTTP 200. This does not supersede the more complete catalog evidence or prove allowed real-session behavior. A publishable key exists; never print/write its value. The Management API token is not a database password/client key. T12 local preparation is Sol-approved; hosted parity/activation pending. SDK platform/build tools are installed, no emulator/physical target is attached, no release certificate is authorized/available, and Gradle release uses debug signing. An interrupted debug-build run ended exit 143; no APK was produced and no build-failure/test result is claimed. Full Flutter checkpoint 528/529 plus isolated-pass lock race remains unresolved as a branch gate.


## S16 T04 correction: eligible roster preview before first save — 2026-10-21

Sol 6.1 low owns this bounded addendum and review; native Luna Medium owns the implementation. This corrects the already-required T04 open attendance/replacement interface. No new project, privileged T11 setup or hosted migration is authorized. This authoring operation changes documents only. The companion T04-P addendum names the exact implementation files and gates.

**Local number reservation:** local migration inventory on 2026-10-21 contains October 20 versions 001–005 only; `202610200006_attendance_roster_preview.sql` is free and reserved for this correction. Recheck immediately before creation; a conflict stops for Sol renumbering, never overwrite a migration. A local reservation says nothing about hosted ledger state.

**Contract:** keep `public.ieadpe_ministry_get_session_attendance(request jsonb) RETURNS jsonb`, exact request `{congregation_id:UUID,session_id:UUID}` and exact existing `{session,roster}` envelope. Preserve every session field, including revision/status/date/class, `roster_frozen`, lesson fields and forward/reverse replacement IDs. Each roster row remains exactly `{enrollment_id:UUID,student_id:UUID,student_name:string,status:'present'|'absent'|'excused'|'unmarked'}`. No new flags, parameters, tables, columns, dependencies or client table privileges. Existing `Session.rosterFrozen`, codec and `MinistryRepository.getSessionAttendance` signatures remain unchanged.

Only for `session.status='open' AND roster_frozen=false`, derive read-only preview rows from same-congregation enrollments in that session's class where `start_date <= session_date AND (end_date IS NULL OR end_date >= session_date)`. This is the writer's existing eligibility predicate, including closed-but-date-eligible enrollments; do not filter by current active status or today's date. Join students by identity and scope, canonical person by identity and scope; use current canonical name when linked, legacy student name otherwise. Every preview status is `unmarked`, ordered by enrollment ID. A zero-eligible preview is empty. For all frozen or terminal sessions return stored roster/marks exclusively, including frozen-empty and canceled-unfrozen cases. Replacement preview uses its own eligible enrollments; never copy predecessor marks/roster. Read performs no data mutation, freezes nothing and does not change revision, counters or receipts. Existing access-lock behavior may remain; no new write is introduced.

Preserve authenticated UID checks, current `private.ministry_can_access` authorization before session exposure, exact request validation/errors, SECURITY DEFINER with empty search_path, PUBLIC/anon denial and authenticated EXECUTE only. Do not bypass RLS, grant SELECT on Ministry tables or call binding scope RPC as inventory. Anonymous/foreign/revoked users obtain existing safe denial, not previews. The forward migration replaces only this function and retains/reasserts its existing execute privileges.

The writer remains the sole freezer: first explicit save recomputes eligibility under existing locks, freezes canonical labels once, requires exact marks coverage and preserves finalization/replay validation. Changed eligibility between preview and save yields existing `roster_mismatch` and full transaction rollback, not implicit roster alteration. Preserve conservative controller classification and explicit fresh-read/review behavior; do not redefine receipt conflicts, auto-retry with new operation IDs or alter Task 3 state transitions in this correction.

UI uses existing `rosterFrozen` for `Lista prevista` plus `A lista será congelada no primeiro salvamento.` versus existing `Lista congelada`. Empty preview states `Nenhum aluno elegível para a data desta aula.`; preserve server empty-draft policy and prohibit empty finalization. Preview mark editing sends existing full marks payload through the existing controller. Announce frozen/success only after acknowledgement and fresh read. Scope/identity loss discards preview and late replies exactly as protected persisted data. Finalized/canceled controls remain read-only.

Acceptance requires meaningful SQL and widget RED/GREEN from a genuinely unfrozen empty-storage session, then explicit draft -> persisted reopen -> finalize, including an independently eligible replacement. Cover date endpoints, zero eligible, closed-date-eligible, future/expired/foreign exclusion, pre/post-freeze rename, terminal/frozen-empty, read-no-DML, eligibility drift/rollback and authorization loss. Existing populated-roster fixtures alone cannot close this correction. Local SQL runs only on an owned disposable loopback target. Hosted application remains H1/H2 approval-gated; T12 must later reconcile the additional migration and semantic fingerprints before any cutover proposal.
