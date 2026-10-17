# Engineering skill routing

This routing applies to post-implementation convert alignment and the unified integration. The completed 19-task convert implementation remains the baseline. Domain checklists are sourced from `C:/Users/Carlos_Neto/superpowers-two-model-pipeline` at `origin/main@ace9e92` (resolved commit `ace9e92ac19d7cb485e8d946ee7b828177e46d08`). The installed/sourced version must be checked before claiming compliance.

| Stage / process skill | When it owns the work | Domain skill and overlays | Required artifact / gate |
|---|---|---|---|
| Requirements discovery: `requirements` | Before a new integration brief, clarify actors, scope, rules, interfaces, quality constraints and acceptance; separate functional/domain/NFR and rank trade-offs. | Add `design-oo-ux` when choosing UML/class/port structure; `agile-loop` when slicing stories. | Requirement trace with evidence, unresolved decisions and measurable acceptance. |
| Architecture: `design-oo-ux` | Select one useful UML view, composition-first boundaries, conception/elaboration exit criteria and prototype fidelity. | `apple-design` governs interface feel; `a11y-ethics` adds POUR, privacy, consent and heuristics. | Typed port sketch plus sequence/class view and acceptance. |
| Implementation: `coding-standards` | Apply Entry/Process/Exit, single responsibility, validation and pure-policy/adapter boundaries only to changed code. | `design-oo-ux` for structure; `apple-design` and `a11y-ethics` for presentation and behavior. | Narrow diff, boundary assertions and no unrelated completed-module rewrite. |
| Verification: `verification-test` | Translate each requirement to positive, negative, boundary, retry/race and regression cases; distinguish local from release evidence. | `quality-gate` decides blockers/SQC and evidence reporting; `a11y-ethics` supplies manual checks. | Executed command/result ledger; live service, host and device checks remain incomplete until run. |
| Release/operations: `cloud-deploy` | Plan hosting, shared responsibility, IAM, encryption, monitoring, backup/restore, quotas, outage and cutover. | `quality-gate` sets release blockers; `verification-test` owns proof. | Operator checklist with boundaries and actual evidence, without provisioning during local implementation. |
| Backlog loop: `agile-loop` | Order integration work as INVEST slices with explicit dependencies and entry/exit criteria. | Each slice routes to its stage skill and overlays above. | DoR/DoD stated without requiring solo-agent Scrum ceremonies. |

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
