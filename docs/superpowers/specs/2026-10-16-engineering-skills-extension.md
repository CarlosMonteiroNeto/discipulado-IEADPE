# Engineering Skill Coverage for IEADPE Integration

Status: planning requirements for the IEADPE side of the unified app. Source: `origin/main` of `C:/Users/Carlos_Neto/superpowers-two-model-pipeline` at `ace9e92` (2026-10-16 inspection), specifically `skills/brainstorming/SKILL.md` and the eight new domain skills. The installed cached Superpowers 6.4.2 does not yet expose those domain skills; executors must pin and load the fork version that owns the plan before claiming skill compliance. No external skill installation is implied.

## Baseline and correction

The App Discipulado 19-task Supabase implementation is complete in its managed worktree on `implementation/supabase-free` at `642047f`; it is the integration baseline. IEADPE still has three unimplemented local plan JSON files: trust-data, UX-governance and verification-quality. They already cite the domain skill names, but their acceptance is tied to Firebase Spark. For integration, preserve their intent and tests while replacing Firebase-specific execution with equivalent Supabase RLS/RPC and the unified Flutter app. Do not treat the complete convert plan as pending.

## Process x domain routing

Use one process skill for the stage (`brainstorming`, `systematic-debugging`, `writing-plans`, or review) and the applicable domain skill, with overlays as needed. The fork requires a project routing table with a single stage skill plus overlays, not loading all domain skills on every task. `apple-design` governs UI feel, motion, typography and materials; `design-oo-ux` adds structural input and yields on visual conflict. For a genuinely new subsystem, record per-area scope and acceptance in `CONTEXT.md` before approach selection. Produce complete JSON plans with `title`, `summary`, `spec_refs`, exclusive `touches`, `depends_on` and checkable `acceptance`, without `expected_red`. Shared registration files belong to a composition task after dependencies. Documentation and briefs are English; UI copy is pt-BR.

| Skill | Required IEADPE planning evidence | Acceptance in integration slices |
| --- | --- | --- |
| `requirements` | Elicitation gaps, scope/volatility risks, functional rules versus NFRs, ranked security/availability/performance/maintainability trade-offs, INVEST stories | A role/congregation/person-link matrix and explicit acceptance for unassigned converts, existing students, revocation and historical records before schema work. |
| `design-oo-ux` + `apple-design` | Class/port sketch with composition, one justified UML view, architecture risk gate, prototype fidelity; Apple interface principles applied to the resulting screens | One shell and route model; linked journey UX at 360/768/1440 and 200% text; immediate feedback, interruptible transitions where motion exists, reduced-motion alternative, contrast and keyboard proof. |
| `coding-standards` | Top-down Entry/Process/Exit and function sketch before implementation; initialized local state, boundary validation, pure policies, explicit recursion choice | Mapping and promotion commands validate input and return typed results; no global mutable cross-feature cache; shared fields have one declared owner. |
| `verification-test` | Traceability from requirements to cases; valid and two invalid partitions, boundary values, base-path/loop cases where relevant; TDD RED evidence and isolated regression environment | SQL/RLS/concurrency, Dart/widget, browser and migration rehearsal cases include retry, race, cross-scope denial, 99/100/101 capacity, empty/full pages and malformed identity mapping. |
| `cloud-deploy` | PaaS/shared-responsibility choice, provider mapping when relevant, IAM/encryption/resilience/monitoring/backup checklist | Supabase Free limits and static host duties are explicit; local tests never contact production; migration cutover, restore and rollback are rehearsed before any release request. Cloud VM/serverless triad is marked not applicable unless chosen. |
| `quality-gate` | Definition of Done tied to ISO 25010 qualities, SQA/SQC distinction, prevention/appraisal/failure cost, static/dynamic evidence | Security and data-integrity gates block release; UI polish remains tracked separately; no skipped backend/browser check is reported green. |
| `agile-loop` | INVEST slices, dependencies, DoR/DoD and reviewable increments; only completed evidence counts | Each new plan task owns exact files, has a narrow regression and a usable artifact; the completed convert tasks remain completed. Ceremony/timebox details apply only if a human team is actually using Scrum. |
| `a11y-ethics` | Heuristic severity, POUR, responsive/manual PCD checks, privacy/consent and auditability | No religious status or phone in URLs/logs; linked history is scoped; WhatsApp requires deliberate action; screen-reader outcomes, keyboard paths and error recovery are verified with people where available. |

## Existing IEADPE plan disposition

- `2026-10-16-trust-data-plan.json`: retain role-matrix, validation, cost-budget and race analysis. Its Spark acceptance of advisory uniqueness and best-effort class capacity is insufficient for the unified product. Replace with server-enforced PostgreSQL unique/invariant and transactional RPC assertions; retain a separate operator runbook for ambiguous legacy identities. Firestore rules/indexes and hardcoded owner-email work become historical parity checks, not integration tasks.
- `2026-10-16-ux-governance-plan.json`: retain token/a11y/privacy requirements. Re-evaluate its exact palette against the completed convert app before choosing one shared semantic theme; do not overwrite convert styling by copying the IEADPE palette. Keep `apple-design` authoritative for visual decisions and `design-oo-ux` for structure.
- `2026-10-16-verification-quality-plan.json`: retain fail-closed gate, evidence ledger, browser/responsive/a11y checks. Replace Firebase emulator-only proof with Supabase local SQL/RLS/RPC plus Auth/Storage HTTP where available. Record blocked checks as incomplete. The existing convert final report's unrun live OAuth/Storage/on-device checks remain release prerequisites, not evidence of passing integration.

## New integration plan coverage

The integration now has four subsystem spec/plan pairs in `App discipulado/docs/superpowers`: convert skill alignment, IEADPE ministry Supabase port, unified convert-to-student journey, and quality/release. They sequence 3 + 5 + 4 + 3 tasks in the completed convert worktree. Every plan uses exact source references, per-task skill `spec_refs`, exclusive `touches`, dependencies and acceptance derived from the table above. The three existing IEADPE plans are source material but must not be executed unchanged against the unified Supabase app.

## Review questions that block code, not this planning artifact

1. Confirm staff login transition from IEADPE email/password to the unified session.
2. Select canonical name/phone/congregation ownership after promotion.
3. Define which IEADPE roles may see full conversion history versus a minimal referral snapshot.
4. Inventory any real Firebase records and obtain a separate release decision before export/import.
