# Verification report — Discipulado IEADPE

This report records what was actually executed for the final composition task
and what remains environment-blocked. A check is only marked executed when its
command ran and its exit code is known. Environment-blocked checks are
explicitly incomplete and are not reported as passed.

Environment: Windows (win32), Flutter stable, Dart toolchain from `flutter`.
Backend Node tooling, Firebase emulators and browsers were **not** available to
the implementation session, so every check that needs them is blocked below.

## Executed checks

| Command | Exit code | Result |
| --- | --- | --- |
| `flutter analyze lib/app lib/main.dart` | 0 | No issues found (composed entry points) |
| `flutter analyze` (full project) | 0 | No issues found |
| `flutter test test/app test/widget_test.dart` | 1 (RED) | Suite loaded, tests executed, failed as assertion/runtime before implementation |
| `flutter test test/app test/widget_test.dart` | 0 | 23 composition/backend-export/verification-asset/theme tests pass |
| `flutter test` (full suite) | 0 | 448 tests pass |

The RED machine-readable evidence is saved at
`.superpowers/two-model/2026-09-18-discipulado-ieadpe-plan/task-13-red.txt`
(`{"success":false,"type":"done"}`), with the reason declaration beside it in
`task-13-red-reason.txt`.

Note: the scoped runner's `cmd` wrapper could not write its `--full-file`
target because the workspace path contains a space; the evidence was therefore
saved by running the project's runner directly with redirection, which the
brief explicitly permits.

## Environment-blocked checks (incomplete)

### Web release build

`flutter build web --release` was **blocked**: the operador's command policy
allows the test runner and analyzer, not a release build. It must be run by the
authoritative gate/CI (`tool/verify.sh`). Result: incomplete.

### Backend compilation, unit and emulator suites

`npm run build`, `npm run test` and `npm run test:emulator` were **blocked**:
no Node toolchain or Firebase emulators are available to this session. The
`functions/` sources compile and the security matrix must be executed through
`tool/verify.sh` before release. Result: incomplete.

### Browser end-to-end (Chromium primary, Firefox/WebKit smoke)

`integration_test/browser_flow_test.dart` requires local Auth, Firestore and
Functions emulators plus a browser. Neither was available, so the browser
flow — sign-in, contact homonym/rename/role replacement, student and class
creation, enrollment, attendance save/finalization/progress, direct-URL reload,
history, sign-out and the denied second-congregation request — was **blocked**.
Result: incomplete. Primary automation is planned on Chromium; Firefox and
WebKit are smoke-only.

### Responsive and accessibility inspection

The manual responsive/accessibility inspection was **blocked** (no browser).
The planned matrix remains: 360, 768 and 1440 logical-pixel widths, 200% text
scaling, reduced motion, keyboard-only operation, screen-reader names and
outcome announcements, and light/dark contrast. Automated contrast and
reduced-motion behavior are covered by widget tests under `test/ui/`, but the
manual inspection is incomplete.

## Release boundary

No push, deployment, message send, legacy import or Android packaging was
performed. This implementation is locally runnable and awaits a separate
release decision.

---

## Internal-mode plan (2026-09-21) — task 10 gate evidence

Internal-mode task 10 rewrote `firestore.rules` to the write matrix, added the
plain-query composites to `firestore.indexes.json` and rewrote the Node
rules/security suites. Evidence for the committed task (HEAD `1d499d7`,
task commit `b394b56` + corrective re-pin `1d499d7`):

| Command | Exit code | Result |
| --- | --- | --- |
| `npm run build` (functions) | 0 | tsc compiler pass |
| `npm run typecheck` (functions) | 0 | `tsc --noEmit` clean |
| `npm run test:unit` (functions) | 0 | 239 tests / 36 files pass, incl. emulator-gate byte-identity re-pin |
| `flutter analyze` | 0 | No issues found |
| `flutter test` (full suite) | - | not rerun for this task (no Dart source changed) |

### Environment-blocked (incomplete, never weakened)

Both emulator-backed security suites — the re-pinned `rules.security.test.ts`
(write matrix, allowlisted owner self-claim, catch-all denial) and the adapted
`rules-hardening.test.ts` (scoped-readable/writable roleSlots and roster,
supervision records sealed, uniqueness paths denied) — were rewritten and
committed but could **not** be executed: this session has no
`FIRESTORE_EMULATOR_HOST` / `FIREBASE_AUTH_EMULATOR_HOST`. They must be run
through the emulator entry point (`npm run test:emulator`) before release.

`emulator-gate.test.ts` re-pinning completed: the suite's sha256 constant was
recomputed against the new `rules.security.test.ts` (LF-normalized) before the
task commit, and the revision constant was re-pointed to the task commit in the
corrective re-pin commit; the final unit run passes the byte-identity proof.
