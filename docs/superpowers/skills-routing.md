# Engineering skill routing

## Corrective release adaptation — 2026-10-20

For the corrective release, use [the new design](specs/2026-10-20-ministry-corrective-release-design.md), [human plan](plans/2026-10-20-ministry-corrective-release-plan.md), and [canonical JSON tasks](plans/2026-10-20-ministry-corrective-release-plan.json). The installed source was inspected at `/workspace/.config/opencode/vendor/superpowers@ace9e92ac19d7cb485e8d946ee7b828177e46d08`, including all nine domain/overlay skills listed below, both pipeline skills and their plan validator/profile resolver.

The user's latest execution choice overrides the packaged Script CEO dispatch/model/commit defaults: this Codex session is strategist/director/arbiter/whole-product reviewer; OpenCode CLI `opencode/deepseek-v4.1-flash-free` is coder; a native `gpt-6.1-sol` low-effort subagent performs each stage review. Read `/workspace/.agents/skills/opencode-cli-delegation/SKILL.md` before coding delegation. Do not silently activate packaged Terra 5.6/Sol 5.6 examples or use a competing automatic controller. This is an explicit adaptation of roles and engineering gates, not evidence that the original autonomous runtime ran.

The OpenCode no-tool readiness request succeeded and the corrected design/plan received proposal-level Sol review; no product implementation or hosted change was performed. Actual task/test/review evidence remains required. See [planning validation and review](../verification/2026-10-20-corrective-planning-review.md).

## Earlier integration routing

This routing applies to post-implementation convert alignment and the unified integration. The completed 19-task convert implementation remains the baseline. Domain checklists are sourced from `C:/Users/Carlos_Neto/superpowers-two-model-pipeline` at `origin/main@ace9e92` (resolved commit `ace9e92ac19d7cb485e8d946ee7b828177e46d08`). The installed/sourced version must be checked before claiming compliance.

| Stage / process skill | When it owns the work | Domain skill and overlays | Required artifact / gate |
|---|---|---|---|
| Requirements discovery: `requirements` | Before a new integration brief, clarify actors, scope, rules, interfaces, quality constraints and acceptance; separate functional/domain/NFR and rank trade-offs. | Add `design-oo-ux` when choosing UML/class/port structure; `agile-loop` when slicing stories. | Requirement trace with evidence, unresolved decisions and measurable acceptance. |
| Architecture: `design-oo-ux` | Select one useful UML view, composition-first boundaries, conception/elaboration exit criteria and prototype fidelity. | `apple-design` governs interface feel; `a11y-ethics` adds POUR, privacy, consent and heuristics. | Typed port sketch plus sequence/class view and acceptance. |
| Implementation: `coding-standards` | Apply Entry/Process/Exit, single responsibility, validation and pure-policy/adapter boundaries only to changed code. | `design-oo-ux` for structure; `apple-design` and `a11y-ethics` for presentation and behavior. | Narrow diff, boundary assertions and no unrelated completed-module rewrite. |
| Verification: `verification-test` | Translate each requirement to positive, negative, boundary, retry/race and regression cases; distinguish local from release evidence. | `quality-gate` decides blockers/SQC and evidence reporting; `a11y-ethics` supplies manual checks. | Executed command/result ledger; live service, host and device checks remain incomplete until run. |
| Release/operations: `cloud-deploy` | Plan hosting, shared responsibility, IAM, encryption, monitoring, backup/restore, quotas, outage and cutover. | `quality-gate` sets release blockers; `verification-test` owns proof. | Operator checklist with boundaries and actual evidence, without provisioning during local implementation. |
| Backlog loop: `agile-loop` | Order integration work as INVEST slices with explicit dependencies and entry/exit criteria. | Each slice routes to its stage skill and overlays above. | DoR/DoD stated without requiring solo-agent Scrum ceremonies. |

## Domain keyword routing

Use one process skill for the current stage and the matching domain skill. Apply overlays only when the work invokes their concern; do not load every domain skill for every task.

| Keyword or concern | Domain skill | Overlays |
|---|---|---|
| Requirement, role, scope, business rule, NFR | `requirements` | `quality-gate` when defining Done. |
| Data model, person link, port, architecture, UML, prototype | `design-oo-ux` | `apple-design` for UI decisions; `a11y-ethics` for access and privacy. |
| Screen, gesture, motion, typography, theme | `apple-design` | `design-oo-ux` for structure; `a11y-ethics`. |
| Handler, validator, pure function, module boundary | `coding-standards` | `verification-test` for case design. |
| Test, TDD, regression, emulator, RLS proof | `verification-test` | `quality-gate` for release gates. |
| Backend, hosting, deployment, backup, IAM, monitoring | `cloud-deploy` | `quality-gate` for operational Done. |
| Backlog, story, dependency, DoR, DoD, sprint | `agile-loop` | `requirements` and `quality-gate` as applicable. |
| Accessibility, WCAG, privacy, consent, usability | `a11y-ethics` | `apple-design` for UI execution. |

The IEADPE skill-coverage spec records how the earlier Firebase plans map to the unified Supabase app and which acceptance criteria must change before implementation: `specs/2026-10-16-engineering-skills-extension.md`. Do not infer that a skill is available just because this table names it; pin and load the fork version before claiming compliance.

## Plan mapping

| Plan | Primary stage | Domain and overlay routing |
|---|---|---|
| `2026-10-16-convert-skill-alignment-plan.json` | Requirements discovery, architecture review, verification | `requirements`, `design-oo-ux`, `apple-design`, `a11y-ethics`, `verification-test`, `quality-gate`, `cloud-deploy`, `agile-loop`, `coding-standards`. |
| `2026-10-16-ministry-supabase-port-plan.json` | Requirements and implementation | `requirements`, `coding-standards`, `verification-test`, `quality-gate`, `cloud-deploy`; `design-oo-ux` for ports; `agile-loop` for slices. |
| `2026-10-16-unified-journey-plan.json` | Architecture and implementation | `design-oo-ux`, `apple-design`, `a11y-ethics`, `coding-standards`, `verification-test`, `quality-gate`; `requirements` for unresolved field/role policy; `agile-loop` for DoR/DoD. |
| `2026-10-16-unified-quality-release-plan.json` | Verification and release | `verification-test`, `quality-gate`, `cloud-deploy`, `a11y-ethics`, `apple-design`; `agile-loop` only for gate-owned work items. |

## Integration story entry and exit

| Story | INVEST slice | Definition of Ready | Definition of Done |
|---|---|---|---|
| Handoff contract | One policy decision package for roles, lifecycle, shared fields and consent. | Existing convert and ministry contracts inspected; unresolved choices listed with defaults and owners. | `docs/integration/handoff-contract.md` plus one sequence view agrees with unified journey spec and plan; no code claim. |
| Atomic promotion | One migration/RPC implementing one-to-one link and minimal referral. | Handoff policy fixed; schema owner and RLS boundary known; operation envelope/lock order defined. | Positive, denied, invalid, boundary, same-scope explicit match, replay/lost response and both race orders covered; existing module SQL suites pass; unauthorized direct read denied. |
| Linked screens | One feature-owned flow for review, promotion and linked journey. | RPC/projection and role matrix stable; no route/query PII. | Draft/retry/error states, explicit enrollment step, scoped candidate review, 360/768/1440/200% text, keyboard/focus/screen-reader/reduced-motion/contrast checks and deliberate contact action verified. |
| Unified shell | Route/theme composition after feature pages exist. | Convert session/cache contract and ministry role needs documented; palette comparison complete. | One root session guard, scope revocation/identity switch/refresh regression, no page overflow and no accidental conversion-history exposure. |
| Release gate | Reproducible local and release evidence ledger. | Exact commands, environments and supported services/devices chosen. | Executed results reported separately from open live OAuth/Storage/host/device checks; SQA blockers closed; backup/restore and cutover responsibility assigned. |

Story slices must be independently understandable and verifiable. “Independent” means a bounded outcome, not a requirement to run Scrum meetings or to parallelize work.
