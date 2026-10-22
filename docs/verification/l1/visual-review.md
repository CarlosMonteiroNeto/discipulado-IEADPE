# Session visual review

Visual acceptance used `buildUnifiedTheme()` with only the deterministic Roboto test font substitution. Captures were generated at 360×900, 1440×900, and 360×900 with a 200% text scaler. The test also checked semantic tap-target guidelines, focus traversal to primary form action, no Flutter exceptions, and 48×48 minimum primary actions.

Each screen has one PNG at each target size in this folder:

- Form: `session-form-360x900.png`, `session-form-1440x900.png`, `session-form-360x900-text-200.png`.
- Session list: `session-list-360x900.png`, `session-list-1440x900.png`, `session-list-360x900-text-200.png`.
- Cancel confirmation: `session-cancel-dialog-360x900.png`, `session-cancel-dialog-1440x900.png`, `session-cancel-dialog-360x900-text-200.png`.
- Empty state: `session-empty-360x900.png`, `session-empty-1440x900.png`, `session-empty-360x900-text-200.png`.
- Loading state: `session-loading-360x900.png`, `session-loading-1440x900.png`, `session-loading-360x900-text-200.png`.
- Error state: `session-error-360x900.png`, `session-error-1440x900.png`, `session-error-360x900-text-200.png`.

All 18 PNGs were visually inspected after the final capture run. Long class and topic text wraps in the form, list, and dialog. The primary form and list actions remain available. Empty, loading, and error states remain readable at 200% text. At wide size, content correctly uses available width; no clipping or overflow was visible.

The initial 200% list capture exposed a real layout issue: the cancellation action in `ListTile.trailing` fell outside the viewport beside the long topic. `SessionListPage` now places that action below the wrapping text. The visual regression asserts its right edge remains within the 360 logical-pixel viewport and captures the list after scrolling the action into view. The Task 4 lesson-session test is rerun as a regression for this list layout change.

The capture fixture initially returned detail for a different session than the cancellation row. It now returns the exact requested session and the dialog assertion checks the long selected topic. This was a fixture correction; product detail identity validation is separately covered by navigation tests.

Review follow-up: the 200% form capture showed the full date-format label truncated. The date field now uses the short `Data` label and a visible `Formato: DD/MM/AAAA` helper; the full format wraps and remains legible. The 200% list capture also exposed that `ensureVisible` needed a settling frame before capture. The test now pumps after scrolling, asserts all four button bounds stay inside the viewport, and captures the full `Cancelar aula` action. Both affected PNGs were regenerated and inspected; the full visual matrix and Task 4 lesson-session regression passed.

The list uses two captures per viewport: the initial position preserves the complete `Nova aula` primary action, and `session-list-cancel-action-*` shows the cancellation action after scrolling. The test checks that both controls' full rectangles remain within the viewport. The long 200% list fixture includes an additional historical row so scrolling can fully move the header action out of view rather than leave it clipped while the cancellation action is centered. There are 21 PNGs total after adding this separate action capture; all list variants affected by the change were inspected.

## B2 portability and golden review (2026-10-20)

This section records the bounded B2 visual review. It does not replace the earlier capture history above.

### Font lookup and capture routing

- The four visual suites now use the shared `test/support/sdk_fonts.dart` helper. It searches the installed Flutter SDK `bin/cache/artifacts/material_fonts` directory and checks canonical names (`Roboto-Regular.ttf`, `MaterialIcons-Regular.otf`) before compatibility lowercase aliases. The lowercase aliases are external symlinks; they were not modified and are not required.
- A focused test asserts that the resolver returns the real canonical files and that neither resolved path is a symlink. A second test asserts that a failed lookup reports the family, all candidate names and all searched locations. Exact SDK/font hashes are in [sdk-font-provenance.md](sdk-font-provenance.md).
- Ordinary session captures now go to `build/verification/corrective-release/B2/session-captures/`, and the class 200% capture goes to `build/verification/corrective-release/B2/class-captures/`. Tests no longer write into tracked documentation or `.superpowers`. The pre-change reproduction run used the old tests and did rewrite the tracked docs; those PNGs were restored byte-for-byte from `HEAD` before the final status. Subsequent runs touched only `build/`.
- The 21 current session captures and the class capture pass the existing assertions for complete control bounds, keyboard/scroll reachability, semantics and focus. The class capture is byte-identical to the previous `.superpowers` capture.

### Gallery and Team golden comparison

The full existing matrix was generated as candidates under `build/verification/corrective-release/B2/golden-candidates/`: 20 gallery PNGs (five states at 360, 768, 1440, plus 200% text at 360) and four Team PNGs (360, 768, 1440, plus 200% text at 360).

Before promotion, every candidate was compared with its committed reference:

- 360 gallery: 3.641%-4.198% of pixels differed; Team 360: 2.625%.
- 768 gallery: 1.706%-1.967%; Team 768: 1.241%.
- 1440 gallery: 0.682%-0.787%; Team 1440: 0.662%.
- 200% gallery: 3.746%-4.972%; Team 200%: 4.090%.

The amplified difference images contain text and icon contours only. Component panels, buttons, chips, backgrounds and spacing align. A brute-force ±2 px alignment check found the best translation `(0,0)` for all 24 candidates. Labels, icons, status chips and actions are present in every state. At 200% text, titles and body copy wrap at the same words and no new clipping or overflow appears. No real layout defect was observed, so B2 made no product UI change. The historical cause of the rasterization difference is not proven; it is consistent with a different Flutter/font rasterization environment when the references were originally created.

Only after that inspection were the 24 gallery/Team golden PNGs replaced with the reviewed candidates. Before/after SHA-256 lists and per-image diff metrics are retained under `build/verification/corrective-release/B2/` (`golden-sha256-before.txt`, `golden-sha256-after.txt`, `visual-diff-metrics.json`, `layout-shift-check.json`, `visual-diffs/`).

### Tracked documentation captures

The tracked PNGs in this directory were **not** promoted or regenerated in B2. They remain the earlier reviewed captures and are now stale relative to the installed runtime: current build captures differ by roughly 0.30%-5.94%, with text/icon contour changes and at most a 1 px vertical baseline shift in three 360 captures. No control bounds or wrapping changed. Promoting current captures into this folder remains an explicit reviewed action; ordinary test runs no longer mutate these files. Evidence: `session-vs-tracked-docs-metrics.json` and `session-doc-layout-shift-check.json`.

### Task 4 immutable attendance and replacement review (2026-10-20)

This section covers the corrective-release Task 4 surfaces. It does not rewrite the earlier capture history and it did not promote any tracked PNGs.

- Every session surface used the shared SDK font resolver and the production `buildUnifiedTheme()`. Captures now go to `build/verification/corrective-release/task4/session-captures/` (66 PNGs): 11 surface states at 360×900, 768×900 and 1440×900, each also at 200% text. No file under `docs/` or `.superpowers/` was written by the run.
- New states: open attendance with draft/finalize actions, finalized attendance with labeled read-only marks and no controls, canceled attendance with the same read-only treatment, and the replacement form with a fixed read-only class/date and the roster-freeze explanation. The session list also captures the eligible `Registrar substituta` action.
- Assertions cover the 48×48 minimum primary actions, viewport bounds, keyboard Tab focus to the primary form/list/finalize/replacement action, `androidTapTargetGuideline`, `labeledTapTargetGuideline`, and no Flutter exception at every viewport/scale. Long class, topic and student names wrap without horizontal overflow.
- Representative images were inspected after the final run: 360 and 360-at-200% finalized/canceled attendance, 1440-at-200% canceled attendance, 360 and 360-at-200% replacement form, and 360-at-200% session list. Status badges are textual (`Aberta`, `Finalizada`, `Cancelada`), read-only marks remain legible, the replacement date reads `20/12/2026`, and the list replacement action stays reachable.
- The layout uses the existing Base44 panels and buttons, standard immediate loading/error feedback, no new animation or artificial delay, and no gesture change. Reduced motion is preserved by not adding decorative motion.
- Not performed here: a screen-reader pass, physical-device rendering, or the real local Supabase/Chromium journey. The full local Supabase stack is still unavailable because Docker image extraction exceeds the environment storage limit, so the dependent browser gate remains blocked rather than claimed as passed.

## Remaining human/device checks

Automation proves deterministic pixels, current assertions and the reviewed candidate files. It does not replace a screen-reader pass, physical-device rendering, or independent reviewer/director sign-off of the golden promotion. The Sol visual/code review for B2 is still required.

## Windows baseline correction for the B2 promotion (2026-10-21)

The B2 candidate run that produced the 20 gallery and 4 Team promotions ran on Linux (`/workspace/discipulado-IEADPE`, per `B2/generate-candidates.log` and `B2/promotion-review.md`). The authoritative final gate runs on Windows with pinned Flutter 3.47.7. Those are different rasterization environments: the promoted Linux PNGs differ from the Windows output by 0.662%–4.972% of pixels, with text/icon contours only and identical geometry, wrapping, control bounds and state selection.

A fresh pinned-Windows capture with `MINISTRY_GOLDEN_CAPTURE_ROOT` executed all 24 cases (4 Team and 20 gallery at 360/768/1440 plus 200% text) before any comparison stopped the loop. Every one of the 24 Windows captures is **byte-identical** to the corresponding pre-B2 baseline at `d0d0e0f^`; none matches the Linux-promoted `HEAD` baseline. The pre-B2 Windows baselines were therefore restored rather than re-promoting new unknown pixels or raising a tolerance.

Evidence (local, git-ignored): `build/verification/corrective-release/L0-visual-2026-10-21/` — `captures/`, `capture-vs-tracked-metrics.json`, `compare_captures.py`, `compare_old_new.py`, `inspect-team360.png`, `inspect-gallery360top.png`, focused and full-suite logs. The focused suites pass 23/23 against the restored baselines; the pinned full suite passes 548/548. This correction is Windows-host-specific; a Linux golden job would need its own reviewed baseline or a deterministic cross-platform font renderer. It does not waive any assertion or change product UI.
