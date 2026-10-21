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
