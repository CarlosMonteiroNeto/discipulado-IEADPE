# Starts the local emulators and serves the Flutter web app against them.
# Nothing here deploys, pushes or touches production data.
$ErrorActionPreference = "Stop"

Push-Location (Join-Path $PSScriptRoot "..")
try {
  if (-not $env:FIREBASE_PROJECT_ID) { $env:FIREBASE_PROJECT_ID = "demo-discipulado" }
  $env:FIREBASE_USE_EMULATOR = "true"
  if (-not $env:FIREBASE_EMULATOR_HOST) { $env:FIREBASE_EMULATOR_HOST = "localhost" }

  Write-Host "==> Compiling backend functions"
  Push-Location functions
  try {
    npm ci
    npm run build
  }
  finally {
    Pop-Location
  }

  Write-Host "==> Starting Auth, Firestore and Functions emulators"
  $emulators = Start-Process -PassThru -NoNewWindow firebase `
    "emulators:start --project $env:FIREBASE_PROJECT_ID --only auth,firestore,functions"

  try {
    Write-Host "==> Running Flutter web against the local emulators"
    flutter run -d chrome `
      --dart-define=FIREBASE_PROJECT_ID=$env:FIREBASE_PROJECT_ID `
      --dart-define=FIREBASE_API_KEY=demo-api-key `
      --dart-define=FIREBASE_AUTH_DOMAIN="$env:FIREBASE_PROJECT_ID.firebaseapp.com" `
      --dart-define=FIREBASE_APP_ID=1:1:web:emulator `
      --dart-define=FIREBASE_USE_EMULATOR=true `
      --dart-define=FIREBASE_EMULATOR_HOST=$env:FIREBASE_EMULATOR_HOST
  }
  finally {
    if ($emulators -and -not $emulators.HasExited) { Stop-Process -Id $emulators.Id }
  }
}
finally {
  Pop-Location
}
