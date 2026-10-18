param([switch]$Apply)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($env:SUPABASE_URL) -or
    [string]::IsNullOrWhiteSpace($env:SUPABASE_SERVICE_ROLE_KEY)) {
    Write-Error 'Missing operator configuration. No request was sent.'
    exit 1
}
$cleanupScript = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'cleanup_photos.py')).Path
$cleanupArguments = @($cleanupScript)
if ($Apply) { $cleanupArguments += '--execute' }
& python @cleanupArguments
exit $LASTEXITCODE
