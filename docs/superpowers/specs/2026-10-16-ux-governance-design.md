# UX-Governance — Design Spec

<!-- canonical-document-authority -->
> **Historical planning reference.** The [current spec](2026-10-20-ministry-corrective-release-design.md), [current plan](../plans/2026-10-20-ministry-corrective-release-plan.md) and [JSON mirror](../plans/2026-10-20-ministry-corrective-release-plan.json) govern current requirements, status, task order and authorization. The original body preserves its dated design, checklists and execution provenance; reconcile useful obligations through the current task owners before future work.

## Category Skeleton
- generic category: internal administration and learning-cohort management
- specific category: congregational discipleship administration for IEADPE
- original implementations: same as trust-data spec

## Goal
Shippable web UX with governance to operate safely: accessible, responsive, and auditable.

## Requirements (agile-loop overlay)
- Backlog INVEST, sliced by `depends_on`; DoR (spec_refs + touches clear) vs DoD (gate green + evidence recorded).
- No multi-org SaaS, no student portal, no public directory.

## Architecture (design-oo-ux + apple-design)
- Feature folders `lib/features/*` over `lib/domain/*` ports, `lib/data/*` adapters, `lib/ui/*` primitives; `ChangeNotifier` controllers, constructor injection.
- Tokens defined once in `lib/ui/app_theme.dart`: primary #002060, secondary #00A3E0, accent #E31B23; light/dark same language, no scattered re-theme.
- Breakpoints: >=1024 persistent nav + tables + 2-col forms; 600-1023 compact; <600 drawer + cards + single-col. No page-wide horizontal scroll.
- Motion: commit on activation, interruptible reversible panels, reduced-motion removes positional animation/overshoot, opaque fallback for translucency.

## Routes / Interaction
Routes `/entrar`, `/recuperar-senha`, `/visao-geral`, `/equipe`, `/alunos`, `/turmas`, `/congregacoes` with validated `congregacao` query param; cursor session-local; dirty-guard hooks + unload confirmation without custom-text promise; safe not-found/forbidden.

## Ethics / Privacy (a11y-ethics overlay)
- POUR: keyboard 44x44 targets, focus trap + Escape + restore, field-associated errors with focus to first invalid, outcome announcements, contrast text >=4.5:1 focus >=3:1, attendance never color-only.
- Transparency/consent: phone/WhatsApp audience explained, `wa.me/{digits}` only, no prefill of religious data, `Copiar telefone` fallback.
- Minimization: no PII in logs/URLs/analytics; `noindex`; retention/backup owned by deployment admin, no invented deletion schedule, no compliance claim.

## Verification
- Widget: reflow/text-scale, keyboard dialogs, reduced-motion, error focus, long accented names, contrast both modes.
- Manual: 360/768/1440, 200% text, keyboard-only flow, screen-reader names/outcomes, reduced motion, contrast.

## Non-goals
No offline sync, no push, no bulk WhatsApp, no finance/certificates/curriculum, no uploads/exports, no AI, no cross-congregation transfer.
