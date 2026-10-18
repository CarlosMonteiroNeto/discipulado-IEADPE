# Base44 Visual Restoration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. The user explicitly selected Luna max implementation, Sol low review and Luna max fixes until zero critical or important findings; preserve that workflow. Steps use checkbox syntax for tracking.

**Goal:** Restore Base44 appearance throughout the unified Flutter Android/web app without changing functional contracts.

**Architecture:** Extend explicit theme tokens and focused presentation widgets, then restyle the shell and existing feature owners. Keep state, callbacks, repositories, route authorization and session ownership in their current owners.

**Tech Stack:** Flutter/Dart, existing Material widgets, existing Flutter test harnesses; no added runtime packages.

**Spec:** `docs/superpowers/specs/2026-10-18-base44-visual-restoration-design.md`

## Global Constraints

- Work in `C:/Users/Carlos_Neto/.codex/worktrees/ieadpe-supabase-pipeline/App discipulado`, branch `implementation/supabase-free`; preserve unrelated dirty files.
- Brand navy #1e3a5f, blue #2563eb; page #f8fafc to #eff6ff; content maximum 896, form maximum 512, gutters 16.
- Android and web; check 360x800, 390x844, 768x1024, 1440x1000, plus 320 wide and text scale 2.0.
- Existing callbacks, field labels, validation, roles, policy/status logic, route paths, repositories, access guards, async ownership and confirmations remain authoritative.
- No runtime dependencies, remote fonts/assets, production data in screenshots, remote writes, migration edits, deploy or push.

## Review Focus

1. Combined campaign/ministry permissions: every authorized destination remains reachable; protected destinations stay hidden.
2. Narrow viewport and enlarged text: navigation, forms, dialogs and last-row actions remain reachable without overflow.
3. Long names, missing/failed photos and absent phones: cards remain legible and unsafe contact stays disabled.
4. Busy/stale/permission-change states: styling preserves disabled actions, retry ownership and confirmation focus.
5. Ministry scope pagination and selection: source restoration cannot hide the active congregation or enable unscoped operations.

## Task 1: Shared visual foundation

**Files:** Modify `lib/ui/unified_theme.dart`, `lib/widgets/brand_header.dart`; create `lib/ui/base44_widgets.dart`.

**Interfaces:** Keep `ThemeData buildUnifiedTheme()` and `BrandHeader({Key? key, String subtitle = 'Novos Convertidos'})`. Add focused stateless `Base44PageHeading({required String title, required IconData icon, String? subtitle, Widget? trailing})`, `Base44Panel({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(16)})` and `Base44Hero({required Widget child})`; all accept optional `Key` and return adaptive layout, no scrolling or state ownership. Shared palette lives in `UnifiedColors`, existing names retained.

- [ ] Read spec and source Layout/Home/Register/Card. Inspect current theme use and existing test assumptions before edits. Record baseline screenshots using deterministic widget fixtures, saving only local artifact paths.
- [ ] Set explicit ColorScheme, text hierarchy, white card/field surfaces, border/radius, button and input themes, visible focus and 48 pixel minimum targets. Add the shared widgets and circular brand badge. Avoid global fixed text heights.
- [ ] Run `flutter test test/branding_test.dart test/widgets/unified_navigation_test.dart`; update implementation-coupled seed palette expectations to verify actual readable theme behavior where necessary. Inspect headings and panels at 320 width with text scale 2.0 through the later shared responsive fixture test. Cosmetic changes alone need no new unit tests.

## Task 2: Restore adaptive shell navigation

**Files:** Modify `lib/widgets/app_shell.dart`; tests `test/widgets/app_shell_test.dart`, `test/widgets/unified_navigation_test.dart`.

**Interfaces:** Preserve AppShell constructor and callbacks. Consume `routesFor(scope)` without editing authorization in `lib/routing/router.dart`. Compute presentation-only primary routes and ministry child selection inside shell; pass each original route string to `onNavigate`.

- [ ] Add failing behavior tests: a combined manager at 360x800 reaches Admin and every ministry child through Menu/Discipulado; selected ministry child highlights ministry parent; register-only scope has no protected links; drawer closes after selection. Ensure tests fail at the intended missing behavior.
- [ ] Implement the spec's compact header, white selected desktop action, right drawer, single-row bottom navigation and ministry section selector; use Menu overflow when combined routes exceed five. Keep feedback and sign out accessible, use SafeArea and sufficient content clearance.
- [ ] Run `flutter test test/widgets/app_shell_test.dart test/widgets/unified_navigation_test.dart`. Pump at 320 and 768 widths with text scale 2.0 and assert no framework exceptions; scroll/tap overflow entries to prove reachability.

## Task 3: Home and convert presentation

**Files:** Modify `lib/features/home/home_page.dart`, `lib/features/converts/{register_page,edit_page,convert_form,converts_page,convert_card}.dart`; tests `test/features/home/home_page_test.dart`, `test/features/converts/{page,form,photo_save,stale_save}_test.dart`; create `test/widgets/base44_responsive_test.dart`.

**Interfaces:** Keep every existing public page/form/card constructor, `ConvertDraft`, ConvertAction callbacks and save controller API unchanged. Consume shared presentation widgets from Task 1. `visitState`, `brazilWhatsApp`, photo ownership and confirmation actions remain in existing paths.

- [ ] Add a failing responsive regression in `base44_responsive_test.dart` with long name/congregation/address, all three statuses, missing phone and photo failure; at 320 width/text scale 2.0 verify no layout exceptions, WhatsApp stays disabled for invalid phone, and edit/delete/confirmation controls can be reached by scrolling. Reuse existing fixture gateways rather than add production connectivity.
- [ ] Restore welcome hero, colored metric icons/tiles, prominent registration action, recent cards and admin link. Keep real metric data and existing loading/error states.
- [ ] Restore narrow registration/edit card, gradient title, photo presentation and consistent fields; keep all save/photo/validation semantics and existing control labels.
- [ ] Restore converts heading, tinted filter tiles and white filter panel. Restore card status strip/tinted body/avatar/icon metadata/badges and green conversation-icon WhatsApp action; use existing URI callback and all disabled conditions. Adapt action rows and photo zoom to small screens.
- [ ] Run `flutter test test/features/home test/features/converts test/widgets/base44_responsive_test.dart`; investigate any failures before updating snapshots/assertions. Capture fixtures for home/register/list and red/yellow/green cards at mobile and desktop sizes.

## Task 4: Admin, reports and secondary surfaces

**Files:** Modify `lib/features/admin/{admin_page,access_panel,congregations_panel}.dart`, `lib/features/reports/{report_view,conversion_panel,events_panel}.dart`, `lib/features/weekly/weekly_panel.dart`, `lib/features/backup/backup_panel.dart`, `lib/features/feedback/{feedback_dialog,feedback_manager}.dart`, `lib/features/auth/login_page.dart`; reuse existing tests in `test/features/{admin,reports,weekly,backup,feedback,auth}`.

**Interfaces:** Public panel/page constructors, mutation callbacks, retry locks and tab builder contracts unchanged. Use shared heading/panel widgets and theme; no repository changes.

- [ ] Read corresponding React admin/home/feedback components for each rendered panel. Restore navy icon heading, compact selected tabs, white cards, consistent buttons/fields, report table hierarchy and dialog spacing.
- [ ] Extend the responsive fixture to exercise admin tabs and a long error/locked retry state at 320/text scale 2.0; verify tab/action reachability and disabled mutation controls, not token values. Preserve test labels and confirmation semantics.
- [ ] Run `flutter test test/features/admin test/features/reports test/features/weekly test/features/backup test/features/feedback test/features/auth test/widgets/base44_responsive_test.dart`. Capture representative admin and feedback fixtures.

## Task 5: Ministry consistency

**Files:** Modify `lib/features/ministry/ui/{ministry_home_page,team_page,students_page,classes_page,attendance_page,convert_handoff_page}.dart`; tests `test/features/ministry/ui/ministry_journey_test.dart`, `test/widgets/unified_navigation_test.dart`, `test/widgets/base44_responsive_test.dart`.

**Interfaces:** Retain current page constructors, scope and pagination callbacks, repository methods and drafts. Nested Scaffold backgrounds become transparent where shell owns the gradient; pages must still render sensibly in standalone tests.

- [ ] Inspect each page's workflow and existing journey tests. Apply overview gradient hero, icon metric cards, white scope panel and common headings/forms/cards for all child screens; do not alter fetch or mutation paths.
- [ ] Add/extend a regression showing a long congregation name remains visible while paginating and scoped actions stay disabled until selection; at 320/text scale 2.0 verify overview and attendance controls can be reached without overflow. Confirm expected RED before any behavior fix.
- [ ] Run `flutter test test/features/ministry test/widgets/unified_navigation_test.dart test/widgets/base44_responsive_test.dart test/workflows_test.dart`. Capture ministry overview and attendance/students at mobile and desktop sizes.

## Task 6: Verify, compare and review

**Files:** Create `docs/operations/base44-visual-restoration.md`; screenshot artifacts outside tracked product sources.

- [ ] Format changed Dart files, run `flutter analyze` then `flutter test` (database integration tests may require their documented local harness; inspect failures and run the appropriate harness rather than labeling them baseline). Run `flutter build web` and `flutter build apk --debug` using existing configuration without exposing secrets. If the repository supplies a command runner, use its actual discovered entry point.
- [ ] Start the local web build with deterministic fixtures and inspect screenshots at the four required sizes. Exercise register/filter/confirmation/photo zoom/admin/ministry navigation and keyboard focus. Compare component hierarchy, colors, dimensions and spacing against the actual React reference. Check text scale 2.0, bottom clearance and long data. Build Android and run the equivalent smoke on an available emulator/device; if unavailable document that runtime limitation explicitly.
- [ ] Record exact commands, outcomes, screenshot paths and any real environmental blockers. Do not claim browser or Android runtime validation from compilation alone.
- [ ] Hand the complete diff and evidence to Sol low for critical/important findings covering fidelity, responsiveness, permissions and preserved workflows. Luna max fixes each finding and reruns affected checks; repeat Sol low review until zero critical/important findings. Do not stop at uninvestigated test failures.
- [ ] Inspect final diff for accidental data/config/migration edits and capture `git status --short`; report final changed files and verification. Commit only scoped files if the parent workflow requests a commit, never include unrelated pre-existing work.

## Plan self-review

Every visual contract maps to Tasks 1–5; cross-platform evidence maps to Task 6. The five review risks have focused behavior/interaction coverage in Tasks 2–5. No task changes business contracts or requires a new package. Exact reference values are specified in the linked design; cosmetic fidelity is judged using rendered evidence rather than tautological style tests.
