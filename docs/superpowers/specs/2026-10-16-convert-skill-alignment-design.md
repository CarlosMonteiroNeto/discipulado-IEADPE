# Convert App Skill Alignment — Design Spec

<!-- canonical-document-authority -->
> **Historical planning reference.** The [current spec](2026-10-20-ministry-corrective-release-design.md), [current plan](../plans/2026-10-20-ministry-corrective-release-plan.md) and [JSON mirror](../plans/2026-10-20-ministry-corrective-release-plan.json) govern current requirements, status, task order and authorization. The original body preserves its dated design, checklists and execution provenance; reconcile useful obligations through the current task owners before future work.

Status: documentary alignment completed and carried into the unified journey and quality gate. Implementation baseline was `implementation/supabase-free` at `642047f`; the completed 19 tasks were not replayed. Source domain skills are `superpowers-two-model-pipeline` `origin/main` at `ace9e92`.

## Evidence and intended result

The convert app already has 10 SQL migrations, transactional RPCs/RLS, private photo protocol, 240 passing Flutter tests, native PostgreSQL race tests, web and debug APK builds, and an independent whole-branch review (`docs/verification/final-report.md`). Its design has an Apple UI section and widgets test 200% scaling/reduced motion. The local evidence does not prove live OAuth/Storage HTTP, on-device behavior or hosted route refresh. No project `skills-routing.md`, requirements trace matrix, explicit quality SQA/SQC/ISO 25010 mapping, per-screen heuristic review, or documented field ownership for the future student link was found. Absence of an artifact is a planning gap, not proof that existing behavior is wrong.

| New skill | Existing evidence inspected | Remaining alignment work |
| --- | --- | --- |
| `requirements` | Accepted Supabase design defines roles, dates, lifecycle, imports and Free-tier boundaries. | Trace functional/domain/NFR requirements to executed and release-only evidence; rank cross-module NFR trade-offs. |
| `design-oo-ux` / `apple-design` | Design has a Pipeline UI section; `lib/routing/router.dart` and `lib/widgets/app_shell.dart` define a single convert shell; widget tests exercise mobile and 200% text. | Port/sequence sketch for cross-module link and comparative theme review; verify UI principles across both feature sets. |
| `coding-standards` | Feature repositories, domain policy and SQL command boundaries are separate; the full analyzer passed. | Apply Entry/Process/Exit and boundary checklist to newly touched handoff/composition code; no broad rewrite of completed modules. |
| `verification-test` | 240 Flutter tests and native-PG multi-session race checks; source hashes verified. | Explicit requirement trace and missing valid/invalid/boundary partitions for new integration; real Auth/Storage HTTP, browser/device evidence remains open. |
| `cloud-deploy` | `docs/operations/supabase-free.md` and release documentation identify quotas, manual backups and hosting. | Record shared-responsibility/IAM/restore/monitoring matrix for one combined app and migration cutover. |
| `quality-gate` | Final report separates executed checks from unrun release dependencies. | Define product-wide SQA blockers, SQC findings and ISO 25010/GQM evidence table. |
| `agile-loop` | The 19 tasks have owned files, sequencing and independent reviews; the SDD ledger marks them complete. | New integration stories need INVEST/DoR/DoD; no need to retroactively redo completed tasks. |
| `a11y-ethics` | Semantics/live regions, focus and scaling appear in convert widgets/tests. | Manual assistive-tech/heuristic evidence, privacy/consent review of cross-module referral and contact actions. |

## Requirements

- Preserve existing conversion behavior, 101 reference hashes, Supabase Free boundary and pt-BR UI.
- Use `requirements` to classify functional rules, domain invariants and NFRs; rank security, integrity, availability, cost and maintainability with rationale; map each requirement to a check or release-only prerequisite.
- Use `coding-standards` only on code touched by integration: show Entry/Process/Exit, validation and pure-policy boundaries. Avoid unrelated refactoring of completed code.
- Use `design-oo-ux` for typed port and link structure. For UI changes, `apple-design` governs feedback, motion, typography and materials; `a11y-ethics` supplies POUR, privacy, consent and heuristic findings.
- Use `verification-test` to add missing partition/boundary/concurrency cases where a concrete gap exists, with genuine RED/GREEN evidence. `quality-gate` defines blocking SQA for authorization/data integrity and SQC for UX polish, plus executed versus incomplete evidence.
- Use `cloud-deploy` to identify Supabase/static-host shared responsibility, IAM, encryption, backups/restore, monitoring and Free-tier limits. Do not activate production services or infer availability guarantees from a Free plan.
- Use `agile-loop` for INVEST slices and DoR/DoD in the new plans; Scrum ceremonies are not required for a solo agent workflow.

## Acceptance

The convert app remains green after focused changes; every new requirement has an owner and verifiable acceptance. Existing unrun live checks remain explicitly incomplete until actually executed. No new global theme is chosen before comparing the IEADPE and convert tokens in the journey spec.

## Scope boundary

This spec covers post-implementation engineering alignment and shared contracts. Ministry data port and convert-to-student UX have their own specs. A review may conclude an item needs only documentation; it must not manufacture code changes to satisfy a checklist.
