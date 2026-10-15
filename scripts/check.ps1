$ErrorActionPreference = 'Stop'
Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    & flutter analyze
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & flutter test
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
    Pop-Location
}
