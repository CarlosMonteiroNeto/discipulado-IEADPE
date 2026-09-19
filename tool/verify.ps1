# Reproducible end-to-end verification for the Discipulado IEADPE release
# candidate. It runs BOTH ecosystems and stops on the first failure: the
# Flutter analyzer/tests/build and the backend compilation/unit/emulator
# suites. Browser smoke checks are documented in docs/verification.md.
$ErrorActionPreference = "Stop"

Push-Location (Join-Path $PSScriptRoot "..")
try {
  Write-Host "==> Flutter dependencies"
  flutter pub get

  Write-Host "==> Flutter analyze"
  flutter analyze

  Write-Host "==> Flutter tests"
  flutter test

  Write-Host "==> Flutter web release build"
  flutter build web --release

  Write-Host "==> Backend install, compile and unit tests"
  Push-Location functions
  try {
    npm ci
    npm run build
    npm run test

    Write-Host "==> Backend emulator authorization suite"
    firebase emulators:exec --project demo-discipulado --only auth,firestore "npm run test:emulator"
  }
  finally {
    Pop-Location
  }

  Write-Host "==> Verification complete"
}
finally {
  Pop-Location
}
