#!/usr/bin/env bash
# Reproducible end-to-end verification for the Discipulado IEADPE release
# candidate. It runs BOTH ecosystems and exits non-zero on the first failure:
# the Flutter analyzer/tests/build and the backend compilation/unit/emulator
# suites. Browser smoke checks are documented in docs/verification.md.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Flutter dependencies"
flutter pub get

echo "==> Flutter analyze"
flutter analyze

echo "==> Flutter tests"
flutter test

echo "==> Flutter web release build"
flutter build web --release

echo "==> Backend install, compile and unit tests"
(
  cd functions
  npm ci
  npm run build
  npm run test
)

echo "==> Backend emulator authorization suite (fails fast without emulators)"
(
  cd functions
  firebase emulators:exec \
    --project demo-discipulado \
    --only auth,firestore \
    "npm run test:emulator"
)

echo "==> Verification complete"
