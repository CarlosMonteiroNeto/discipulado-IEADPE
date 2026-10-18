# Domain Skill Routing

Apply the Superpowers process skill for the stage plus the single matching domain stage skill. Add overlays only where the task invokes their concern. Source: `superpowers-two-model-pipeline` `origin/main` at `ace9e92`.

| Keyword | Skill | Overlays |
| --- | --- | --- |
| requirement, role, scope, business rule, NFR | `requirements` | `quality-gate` when defining Done |
| model, person link, port, architecture, UML, prototype | `design-oo-ux` | `apple-design` for every UI design; `a11y-ethics` for access/privacy |
| screen, gesture, motion, typography, theme | `apple-design` | `design-oo-ux` for structural decisions; `a11y-ethics` |
| handler, validator, pure function, module boundary | `coding-standards` | `verification-test` for case design |
| test, TDD, regression, emulator, RLS proof | `verification-test` | `quality-gate` for release gate |
| backend, hosting, deployment, backup, IAM, monitoring | `cloud-deploy` | `quality-gate` for operational Done |
| backlog, story, dependency, DoR, DoD, sprint | `agile-loop` | `requirements`, `quality-gate` as applicable |
| accessibility, WCAG, privacy, consent, usability | `a11y-ethics` | `apple-design` for UI execution |

The coverage and plan disposition are in `specs/2026-10-16-engineering-skills-extension.md`. Do not infer that a domain skill is installed solely because this routing table names it; pin the fork revision and load the skill source before execution.
