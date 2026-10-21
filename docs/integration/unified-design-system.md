# Unified design system contract

<!-- canonical-document-authority -->
> **Supporting technical reference.** The [current spec](../superpowers/specs/2026-10-20-ministry-corrective-release-design.md), [current plan](../superpowers/plans/2026-10-20-ministry-corrective-release-plan.md) and [JSON mirror](../superpowers/plans/2026-10-20-ministry-corrective-release-plan.json) govern current requirements, status, task order and authorization. Reuse procedures/contracts only through the corresponding current task and its reviewed interface, prerequisites and authorization. Counts, completed operations and old environment statements retain their original observation date.

Status: proposed implementation contract; approved Base44 identity retained. No theme code changed by this document.

## Evidence and applicable guidance

The application already has lib/ui/unified_theme.dart, lib/ui/base44_widgets.dart, widgets/app_shell.dart and brand_header.dart. Extend these as the single source of presentation rules rather than introducing a parallel theme. Reference: retained Base44 source and the approved visual-restoration design.

Apple Design was located and read at C:/Users/Carlos_Neto/.codex/worktrees/pipeline-consolidation/skills/apple-design/SKILL.md. It emphasizes immediate feedback, predictable navigation, grouped controls, system typography, text scaling, restrained interruptible motion and reduced-motion alternatives. Its web snippets must be translated to Flutter APIs, not copied as runtime dependencies. The measurements below are project decisions, not values claimed to be mandated by Apple.

Before implementation, resolve and record the actual engineering overlays in the user's Superpowers fork, with path/revision and applicable requirements. Previously referenced overlay names alone are not proof of loading their instructions. Use requirements, design/UX, coding, accessibility and verification guidance actually found; report unavailable sources rather than inventing rules.

## Tokens

Centralize named tokens in the existing theme or a small adjacent theme extension. Screens use semantic names, not repeated literal values.

| Category | Initial project scale |
| --- | --- |
| Brand | Navy #1E3A5F, blue #2563EB; existing Base44 gradient |
| Surfaces | Page #F8FAFC, tint #EFF6FF, cards white; existing semantic text/border colors |
| Spacing | 4, 8, 12, 16, 24, 32, 48 logical pixels; page inset 16 on phone, 24 on wider layouts; field gap 16, section gap 24 |
| Radius | 8 compact controls, 12 fields/cards, 16 sheets/dialogs; pills only for badges |
| Type | System font; body 16/1.5, supporting text 14/1.4, section title 20/1.3, page title 24/1.2; weights 400/600/700; never clamp user text scaling |
| Icons | 20 inline, 24 actions; 48 minimum interactive target including padding; provide text or accessible label |
| Width/layout | Preserve current 768 navigation breakpoint and 896 content-width limit initially; validate rather than invent separate breakpoints per screen |
| Motion | Immediate pressed/focus feedback; modest platform transitions; interruptible gesture-driven motion; respect disableAnimations/accessibility settings; no artificial wait before actions |

Semantic colors include primary, secondary, success, warning, error, disabled, focus and surface variants with verified foreground contrast. WhatsApp retains a recognizable green action and chat icon. Text accompanies attendance states, warnings and errors. White-on-green and muted text must be measured, not assumed accessible from their names.

## Shared components and behavior

Standardize page heading, form section, field/help/error, required marker, panel, list/detail row, primary/secondary/destructive action, search/filter, congregation selector, confirmation sheet/dialog, empty/loading/error/retry states, status badge and attendance row. Reuse existing Base44 widgets where possible. Add components only for genuine reused responsibilities, not wrappers around every Flutter widget.

Use ThemeData component themes for buttons, inputs, dialogs, cards, menus, snackbars and text. Apply tokens to both convert and ministry surfaces; do not redesign the approved quick-register flow. Prefer solid readable surfaces; translucency is optional only where it improves hierarchy and passes accessibility/performance checks. Keep Flutter/Android navigation, back and keyboard behavior predictable.

Every screen has a named location, clear next action and return path. Group related fields and keep optional academic detail subordinate to quick registration. Pending saves show progress and guard duplicate submission; success is confirmed only after acknowledgement. Inline validation and preserved recoverable drafts follow existing security/session contracts.

## Enforcement and acceptance

Create a development/test-only component gallery using synthetic data showing component states. Compare Base44-derived convert pages and ministry pages at 360, 768 and 1440 widths and 200% text. Verify no clipped labels, unreachable actions or overflow; keyboard focus/order, semantics and screen-reader labels; contrast (4.5:1 ordinary text, 3:1 large text and meaningful UI boundaries); reduced-motion behavior. These are project accessibility targets.

Review diffs for ad hoc colors, typography, padding/radii and duplicated presentation logic. Exceptions require a local documented purpose and visual check; tests should check user-visible usability rather than equating token constants. Run flutter analyze and focused responsive/semantics tests, retain synthetic screenshots and manual-review outcomes. Do not claim human or physical-device review from widget tests alone.
