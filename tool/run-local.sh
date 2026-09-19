#!/usr/bin/env bash
# Starts the local emulators and serves the Flutter web app against them.
# Nothing here deploys, pushes or touches production data.
set -euo pipefail

cd "$(dirname "$0")/.."

export FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-demo-discipulado}"
export FIREBASE_USE_EMULATOR="true"
export FIREBASE_EMULATOR_HOST="${FIREBASE_EMULATOR_HOST:-localhost}"

echo "==> Compiling backend functions"
( cd functions && npm ci && npm run build )

echo "==> Starting Auth, Firestore and Functions emulators"
firebase emulators:start \
  --project "$FIREBASE_PROJECT_ID" \
  --only auth,firestore,functions &
EMULATOR_PID=$!
trap 'kill "$EMULATOR_PID" 2>/dev/null || true' EXIT

echo "==> Running Flutter web against the local emulators"
flutter run -d chrome \
  --dart-define=FIREBASE_PROJECT_ID="$FIREBASE_PROJECT_ID" \
  --dart-define=FIREBASE_API_KEY=demo-api-key \
  --dart-define=FIREBASE_AUTH_DOMAIN="$FIREBASE_PROJECT_ID.firebaseapp.com" \
  --dart-define=FIREBASE_APP_ID=1:1:web:emulator \
  --dart-define=FIREBASE_USE_EMULATOR=true \
  --dart-define=FIREBASE_EMULATOR_HOST="$FIREBASE_EMULATOR_HOST"
