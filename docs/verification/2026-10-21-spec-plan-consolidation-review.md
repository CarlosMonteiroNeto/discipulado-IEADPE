# Spec and plan consolidation review — 2026-10-21

## Scope and candidate

Requested outcome: consolidate the current spec/plan and assess completed work, remaining work and evidence-based additions before later implementation. This pass changes documentation only, starting from `codex/ministry-production-completion@0b054731fe0804b0a939e96a22dedb1e8bf4a019` in `C:/Users/Carlos_Neto/.codex/worktrees/ministry-supabase-config/App discipulado`.

The canonical documents are the [spec](../superpowers/specs/2026-10-20-ministry-corrective-release-design.md), [plan](../superpowers/plans/2026-10-20-ministry-corrective-release-plan.md) and [machine plan](../superpowers/plans/2026-10-20-ministry-corrective-release-plan.json). Requirement IDs, task IDs and existing acceptance contracts remain traceable. Earlier proposals, source snapshots and scoped approvals are historical evidence, not parallel execution queues.

## Independent investigation

GPT-6.1 Sol low agent `audit_remaining_work` inspected the plan, spec, reports, contracts and relevant implementation without editing or running product tests. Sol low agent `consolidate_spec_plan` edited the three canonical documents. A separate Sol low review assesses the final document candidate.

The audit confirmed:

| Requirement | Existing owners | Work remaining after existing implementation |
| --- | --- | --- |
| R01 importer compatibility | B1, T12, H3 | Source-bound local evidence exists; real legacy reconciliation/import remains gated. |
| R02 canonical operational reads | T01, T11 | Actual local-stack journey and separate hosted parity. |
| R03 finalized immutability/replacement | T02, T04, T04-P, T11 | T04-P has subsequent real SQL scoped approval; integrated browser/device acceptance remains. |
| R04 ambiguous retry ownership | T03, T04, L0 | Historical 528/529 failure needs source-bound root-cause disposition. |
| R05 persisted history/progress | T05, T06, T11 | Existing source must be exercised through the live journey and fresh-session reads. |
| R06 authority compatibility | T07, T12, H1/H2 | Scoped local work does not prove current hosted roles, schema or recovery. |
| R07 greeting and Team access | T08, O1/H2, D2 | Real session/callback/role/device observations. |
| R08 verification quality | T09, T10, T11, L0 | Timeout diagnosis, visual/race disposition, real local gates and assembled review. |
| R09 safe activation | T12, H0/H1/H2 | Exact-state package, isolated recovery proof and separately authorized operations. |
| R10 legacy-source integrity | H3 | Export/source-inspected absence and stable-ID reconciliation. |
| R11 exact Android artifact | D0/D1/D2, G3/G4 | Device readiness, signing/build approval, installed/update journey and publication gates. |

T01/T02 have durable scoped local reviews. T03–T07 have implemented source and director-attributed scoped verdicts; missing individual review artifacts are not fabricated. Later T08–T10 corrections have reviewed local evidence with platform limits. T04-P and T12-006 are separately `APPROVED_LOCAL`, including actual first-save SQL and the 16-forward-migration/17-checkpoint preparation. T11 source already contains preview, finalized rejection, cancellation and linked replacement; missing runtime evidence does not justify reimplementing that journey.

## Reconciliation decisions

- Replace active OpenCode/executor and planning-only statements with the user's native Luna Medium/Sol low workflow; retain earlier provenance in Git/history.
- Distinguish source implementation, scoped approval and assembled acceptance. Preserve the latest recorded pinned 546/548 result, unresolved historical 528/529 and incomplete real T11/Android evidence.
- Mark the opening local-report tables as earlier snapshots so their T04-P SQL-blocked statements do not override later scoped closing records.
- Provide one current status/continuation index mirrored in JSON, keeping parent requirements and existing IDs/interfaces.
- Keep the 54-test Python run failed after its 90-second Bash timeout. The same test passed alone in 27.988 seconds; the timing cause remains undetermined.
- Separate default Flutter 3.47.2/Dart 3.13.2 from recorded pinned 3.47.7/Dart 3.13.5 evidence.
- Use archive/member evidence locators. The two excluded L0 approval-index JSON files remain unavailable; reconstructing or exposing them is not a task.
- Refine existing task owners for the toolchain/evidence index, timeout, larger golden viewports/race, local stack/client settings, physical Wi-Fi ADB/loopback routing, read-only package refresh, final local assembly and gated delivery. These are verification/readiness gaps, not a new feature backlog.

## Documentary validation

- Original handoff archive detached SHA-256 matched; all 522 entries were regular relative paths without traversal, with matching per-entry sizes and SHA-256 values.
- All 27 indexed recent evidence members and all 16 recovered-history members matched their ZIP manifest hashes; CRC checks passed.
- All seven current source/test files matched the exact SHA-256 values in the portable recent source manifest.
- Final JSON/ID/dependency/reference/diff checks and independent document-review results are recorded in the closing section below.

No application tests, build, device pairing, hosted change or migration were performed for this documentation pass. Prior test outcomes retain their original candidate/toolchain scope. Finalized attendance remains immutable, and APK/signing/publication retain their existing gates.

## Closing review

Independent reviewer: GPT-6.1 Sol low, read-only agent `final_diff_review`.

Round 1 returned **SEND_BACK** for two executable documentation gaps: selecting a pinned Flutter launcher did not constrain subprocess PATH resolution, and the expanded T04 file/test ownership was not reflected in its verification command. The editor added a process-only inherited PATH with Python/Bash/PowerShell resolution/version proofs and added the first-save SQL and contained Flutter wrapper to T04 verification. These changes refine existing task execution; they do not alter application behavior.

Round 2 returned **APPROVED — documentary review**, with no remaining findings. The reviewer confirmed requirements/contracts, failure states and authorization/build gates remain preserved. Approved canonical file hashes:

| File | SHA-256 |
| --- | --- |
| Spec | `77e0b92d4417d16680e6269bdcc1e617c971f29ced6174bdb0fea31a5d9c5930` |
| Plan Markdown | `3bfa0214a280a5726fb25a0a76c45a8c2fcadecb708aa8f2737d153dc215f2d8` |
| Plan JSON | `126920bced7ac3612301189d1f3cd34a436e9cdad7c95f36ec4e7fbbcd33e376` |

The [documentary check log](2026-10-21-spec-plan-document-checks.log) records final schema/ID/dependency/reference/hash checks and `git diff --check`. Original task interfaces/dependencies and existing tests remain preserved; T04 now explicitly owns and invokes the already-implemented roster-preview extension. T12's acceptance states the existing migration-006 chain. No new feature task was added.

The next implementation entry is B0/L0 toolchain and evidence identity, followed by the existing timeout/visual/race and local T11 work, with D0 physical-device readiness and separate gated delivery. The 23-unit status map and eight owned continuations are the active queue. Product, L0, hosted, Android and release acceptance remain incomplete; this approval applies to the documentation only.

## Follow-up: parallel documents and engineering assurance

The user approved the consolidated direction and requested a broader reconciliation of handoffs and parallel documents with brainstorming/software-engineering/quality skill guidance. Investigation base for this follow-up is `36c53e9f6f233868abdac44fdf0569c513dc9463`. The earlier closing verdict and hashes above remain the record of the first consolidation candidate, not the hashes of the extended revision.

Read-only Sol low audit `audit_remaining_work` found conflicting entry points in the root README, L1/portable handoffs, task manifest, execution ledger and operational runbooks. Sol low editor `consolidate_spec_plan` incorporated useful remaining obligations into S18 and the existing plan owners; no second backlog or new product implementation was created. The root README now describes implemented authentication/routing and points to the canonical pair instead of resuming L1.

| Annotated document role | Files | Preservation rule |
| --- | --- | --- |
| Historical Markdown specs/plans/runbooks | 32 | Add authority pointer; retain original body. |
| Supporting operations/integration references | 16 | Preserve procedures/typed details, subordinate use to current task/contracts/gates. |
| Historical integration baselines | 2 | Preserve superseded authority/identity/attendance assumptions as provenance. |
| Dated report/handoff/ledger/manifest entry points | 13 | Retain candidate-scoped observations; current queue and authorization come from the canonical pair. |
| Historical JSON plans/configuration examples | 9 | Add `_documentation_authority`; original parsed payload remains unchanged. |
| Historical TOML example | 1 | Add comments; preserve original body. |

The [preservation manifest](2026-10-21-document-authority-manifest.json) records all 73 paths, original Git blobs, inserted-block offsets and raw/LF-normalized hashes. The [sweep log](2026-10-21-document-authority-sweep.log) records the role counts. Original raw reviews, prior logs, archive manifests, ZIP/TAR archives and images were not rewritten. Recovery copies remain outside the repository. An initial command-transport quoting error occurred before edits; the corrected external helper performed the sweep and verified body preservation.

Engineering sources were actually read at `C:/Users/Carlos_Neto/.config/opencode/vendor/superpowers`, revision `ace9e92ac19d7cb485e8d946ee7b828177e46d08`, with all nine skill files clean against that checkout. The [routing record](../superpowers/skills-routing.md) pins their hashes and the official brainstorming file actually read. S18 states the seven elicitation states, scope/comprehension/volatility risks, quality trade-offs, DoR/DoD, SQA versus SQC and static versus dynamic evidence. The plan maps inherited behavior to case partitions, boundaries, owners and real evidence. Skill reading/planning coverage is not product execution or ISO/CMMI/MPS certification; external skills were not installed or invoked.

Retained coverage includes PKCE/session edge cases, private photos and Storage HTTP/cleanup, DB plus Storage-byte recovery, safe file/SAF lifecycle, deliberate contact/privacy, bounded queries/capacity/date rules, accessibility and exact-artifact delivery. Firefox/WebKit smoke and older dark-mode support require explicit existing-owner disposition where evidence/decisions are absent; they are neither silently discarded nor automatically added as new features/build blockers.

The installed strict plan validator additionally found duplicate Task 4 test ownership: `attendance_roster_preview_test.dart` appeared in both `touches` and `verification.new_test_files`. The failure is retained in the [validator log](2026-10-21-document-authority-plan-validator.log). Correction keeps the wrapper in test ownership and its verification command, removing only the duplicate `touches` entry. This is a plan-schema correction, not an application defect or a reconstructed TDD RED. Final validation and independent review of this follow-up are recorded below.

**Follow-up closing review: APPROVED — documentary consolidation**, independent read-only GPT-6.1 Sol low agent `final_diff_review`, no blocking findings. The reviewer confirmed preservation of all 73 documents and nine historical JSON payloads, unchanged 12 task IDs/dependencies/interfaces/acceptance, corrected T04 ownership/verification, real skill hashes, current relative links and one authority without a second backlog. This does not approve product, L0, hosted, Android or release.

| Approved file | SHA-256 |
| --- | --- |
| Spec | `a7d758f300dbf6eff65ec02e9a0dd3f0f1697a1cab3890b3b8a978410c79800c` |
| Plan Markdown | `888692dc7367e53508ac7e5db7534270f2ddfb72f9c76f6c8b58f5dac6cc2ee9` |
| Plan JSON | `73b6840ce6b889ba197b23b43e06d08ac57fcf39b5bf847f0a8418c0932de03e` |
| Skills routing | `945a4490021521ae12ad870678378b69c7f8081276856bcd50cdd8c6b4cb99da` |

Fresh [documentary checks](2026-10-21-document-authority-checks.log) passed exact inserted-block removal/raw body preservation, Git baseline comparison, historical JSON payload equivalence, all documentation JSON parsing, task invariants, documentation-only diff and whitespace checks. The real installed [strict plan validator passed after correction](2026-10-21-document-authority-plan-validator-green.log); the original failure remains preserved separately. No application tests, build, hosted mutation, migration, signing or publication was performed by this documentary audit. The next execution remains the current plan's B0/L0 entry and eight existing owned continuations.
