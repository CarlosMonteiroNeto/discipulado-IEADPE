# Verification-Quality Gate — Design Spec

## Category Skeleton
- generic category: internal administration and learning-cohort management
- specific category: congregational discipleship administration for IEADPE
- original implementations: same as trust-data spec

## Goal
Make verification reproducible and honest: every release decision has executed evidence or an explicit environment-blocked marker.

## Context
`flutter analyze` clean, 632 Flutter tests + 239 Functions unit tests pass, but `rules.security.test.ts`, `rules-hardening.test.ts`, `flutter build web --release`, `integration_test/browser_flow_test.dart`, and manual responsive/a11y inspection never executed in the implementation session. `tool/verify.sh` is the canonical gate; CI must invoke the same entry points.

## Requirements (requirements + quality-gate overlay)
- Definition of Done: `flutter pub get` + `flutter analyze` + `flutter test` + `flutter build web --release` + `npm ci/build/typecheck/test:unit/test:emulator` + Chromium E2E + Firefox/WebKit smoke + responsive/a11y sheet, all exit codes recorded in `docs/verification.md`.
- SQA vs SQC: rules matrix and enrollment cap are SQA gates (block release); UI polish deltas are SQC.
- ISO 25010 mapping: functional suitability (matrix), reliability (atomic attendance), performance efficiency (read budget), usability (Section 4 spec), security (deny-by-default).

## Architecture
- `tool/verify.sh/ps1` remains single entry; `functions/package.json:test:emulator` fails fast without both emulator hosts.
- Emulator exec: `firebase emulators:exec --project demo-discipulado --only auth,firestore "npm run test:emulator"`.
- Ledger distinguishes executed vs environment-blocked; blocked never reported as passed.

## Data flow
Seed (`seed-emulators.ts`, emulator UIDs) -> Auth/Firestore emulators -> Flutter driver + Vitest security suites -> `docs/verification.md` evidence table with browser/runtime versions.

## Changes
1. Re-pin emulator-gate byte-identity after any security-test edit.
2. Add sentinel assertion proving security suite actually ran.
3. Record Chromium/Firefox/WebKit versions, 360/768/1440 widths, 200% text, keyboard-only, screen-reader, reduced-motion, contrast.
4. CI `verify.yml` pins Flutter stable, Node 20, Java runtime; no silent fallback to production.

## Verification
This spec is verified by its own execution: full gate green or explicit incomplete markers. Flutter unit green alone never proves backend authorization.

## Non-goals
No deployment, no push, no legacy import, no message send.
