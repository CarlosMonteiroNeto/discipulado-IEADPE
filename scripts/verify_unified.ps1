$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Push-Location $root
try {
    $reportDir = Join-Path $root 'build/verification'
    New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
    $reportPath = Join-Path $reportDir 'unified-report.md'
    $results = [System.Collections.Generic.List[object]]::new()
    $transcript = Join-Path $reportDir 'unified-commands.log'
    "Unified verification started $(Get-Date -Format o)" | Set-Content $transcript

    function Invoke-Gate([string]$Name, [string]$File, [string[]]$Arguments, [bool]$Required = $true, [bool]$JourneyExitMapping = $false) {
        $command = "$File $($Arguments -join ' ')"
        if ($env:SUPABASE_ANON_KEY) { $command = $command.Replace($env:SUPABASE_ANON_KEY, '[redacted]') }
        $resolved = Get-Command $File -ErrorAction SilentlyContinue
        if (-not $resolved) {
            $state = if ($Required) { 'BLOCKED' } else { 'INCOMPLETE' }
            $results.Add([pscustomobject]@{ Name=$Name; State=$state; Exit='n/a'; Command=$command; Detail='executable unavailable' })
            Add-Content $transcript "$state [$Name] executable unavailable: $File"
            return
        }
        $command = "$($resolved.Source) $($Arguments -join ' ')"
        if ($env:SUPABASE_ANON_KEY) { $command = $command.Replace($env:SUPABASE_ANON_KEY, '[redacted]') }
        Add-Content $transcript "`n[$Name] $command"
        $previousErrorActionPreference = $ErrorActionPreference
        try {
            # Windows PowerShell 5.1 promotes native stderr to a terminating error under Stop,
            # even when the executable succeeds. Keep it as captured diagnostic output here.
            $ErrorActionPreference = 'Continue'
            & $resolved.Source @Arguments 2>&1 | Tee-Object -FilePath $transcript -Append -ErrorAction Stop
            $code = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
        if ($null -eq $code) { $code = 0 }
        $state = if ($code -eq 0) { 'PASS' } elseif ($JourneyExitMapping -and $code -eq 2) { 'BLOCKED' } else { 'FAIL' }
        $detail = if ($JourneyExitMapping -and $code -eq 2) { 'local browser journey prerequisites are unavailable or unsafe' } else { '' }
        $results.Add([pscustomobject]@{ Name=$Name; State=$state; Exit=$code; Command=$command; Detail=$detail })
        Add-Content $transcript "[$Name] exit=$code"
    }

    function Add-BlockedHealthChecks([string]$Detail) {
        $results.Add([pscustomobject]@{ Name='Auth HTTP health'; State='BLOCKED'; Exit='n/a'; Command='GET SUPABASE_URL/auth/v1/health'; Detail=$Detail })
        $results.Add([pscustomobject]@{ Name='Storage HTTP health'; State='BLOCKED'; Exit='n/a'; Command='GET SUPABASE_URL/storage/v1/status'; Detail=$Detail })
        Add-Content $transcript "BLOCKED [Auth/Storage HTTP health] $Detail"
    }

    $psqlTool = 'psql'
    if (-not (Get-Command psql -ErrorAction SilentlyContinue)) {
        $fallbackPsql = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex/tools/ieadpe-postgresql/pgsql/bin/psql.exe'
        if (Test-Path $fallbackPsql) { $psqlTool = $fallbackPsql }
    }
    foreach ($tool in @(@('Flutter version','flutter',@('--version')), @('Dart version','dart',@('--version')), @('Python version','python',@('--version')), @('PostgreSQL client version',$psqlTool,@('--version')), @('Supabase CLI version','supabase',@('--version')))) {
        Invoke-Gate $tool[0] $tool[1] $tool[2] $false
    }
    if (Get-Command flutter -ErrorAction SilentlyContinue) {
        Invoke-Gate 'Flutter analyze' 'flutter' @('analyze')
        Invoke-Gate 'Flutter tests' 'flutter' @('test')
        Invoke-Gate 'Flutter web build' 'flutter' @('build','web')
        Invoke-Gate 'Static web preflight' 'python' @('scripts/web_preflight.py','build/web')
    } else { Invoke-Gate 'Flutter analyze' 'flutter' @('analyze') }

    $sqlNames = @('access_test.sql','base44_unified_access_test.sql','catalog_test.sql','convert_commands_test.sql','convert_student_link_test.sql','feedback_test.sql','import_test.sql','lifecycle_test.sql','ministry_academic_test.sql','ministry_access_test.sql','ministry_congregations_test.sql','ministry_registry_test.sql','ministry_ui_reads_test.sql','photos_test.sql','unified_scope_test.sql','weekly_test.sql')
    foreach ($scenario in $sqlNames) { Invoke-Gate "SQL $scenario" 'python' @('scripts/test_database.py',$scenario) }
    Invoke-Gate 'Synthetic migration rehearsal' 'python' @('-m','unittest','discover','-s','test/migration','-p','*_test.py')
    foreach ($race in @('catalog','access','convert','convert-student','import','lifecycle','ministry-registry','ministry-academic')) {
        $flag = "--$race-concurrency"
        Invoke-Gate "Concurrency $race" 'python' @('scripts/test_database.py',$flag)
    }

    if (-not $env:SUPABASE_URL -or -not $env:SUPABASE_ANON_KEY) {
        Add-BlockedHealthChecks 'SUPABASE_URL or SUPABASE_ANON_KEY is unset'
    } else {
        $python = Get-Command python -ErrorAction SilentlyContinue
        if (-not $python) {
            Add-BlockedHealthChecks 'Python is unavailable to validate the local Supabase URL'
        } else {
            $guard = "import sys; sys.path.insert(0, 'scripts'); from local_supabase_guard import require_loopback_url; require_loopback_url(sys.argv[1])"
            try {
                & $python.Source -c $guard $env:SUPABASE_URL 1>$null 2>$null
                $guardExit = $LASTEXITCODE
            } catch { $guardExit = 1 }
            if ($guardExit -ne 0) {
                Add-BlockedHealthChecks 'SUPABASE_URL rejected: Auth and Storage probes require a loopback URL'
            } else {
                $healthBase = $env:SUPABASE_URL.TrimEnd('/')
                Invoke-Gate 'Auth HTTP health' 'curl.exe' @('-q','--noproxy','*','-fsS','-o','NUL',"$healthBase/auth/v1/health",'-H',"apikey: $($env:SUPABASE_ANON_KEY)")
                Invoke-Gate 'Storage HTTP health' 'curl.exe' @('-q','--noproxy','*','-fsS','-o','NUL',"$healthBase/storage/v1/status",'-H',"apikey: $($env:SUPABASE_ANON_KEY)")
            }
        }
    }

    $chrome = if ($env:CHROME_EXECUTABLE) { $env:CHROME_EXECUTABLE } elseif (Test-Path 'C:\Program Files\Google\Chrome\Application\chrome.exe') { 'C:\Program Files\Google\Chrome\Application\chrome.exe' } else { 'chrome' }
    if (Get-Command $chrome -ErrorAction SilentlyContinue) {
        $env:CHROME_EXECUTABLE = (Get-Command $chrome).Source
        if ($IsWindows -or $env:OS -eq 'Windows_NT') {
            $chromeVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($env:CHROME_EXECUTABLE).ProductVersion
            $results.Add([pscustomobject]@{ Name='Browser version'; State='PASS'; Exit=0; Command='Chrome file product version'; Detail=$chromeVersion })
            Add-Content $transcript "[Browser version] $chromeVersion (file metadata)"
        } else { Invoke-Gate 'Browser version' $env:CHROME_EXECUTABLE @('--version') $false }
        Invoke-Gate 'Browser locale smoke' 'python' @('test/platform/run_collation_browser.py')
        Invoke-Gate 'Browser file export smoke' 'python' @('test/platform/run_export_browser.py')
    } else {
        $results.Add([pscustomobject]@{ Name='Browser adapter smoke'; State='BLOCKED'; Exit='n/a'; Command='Chrome/Chromium smoke scripts'; Detail='Chrome/Chromium executable unavailable' })
    }
    Invoke-Gate 'Local routes and asset rewrite fixture' 'python' @('-m','unittest','discover','-s','scripts','-p','test_release_operations.py')

    Invoke-Gate 'Integrated registrar-to-attendance browser journey' 'python' @('scripts/run_unified_journey.py') $true $true
    $failed = @($results | Where-Object State -eq 'FAIL').Count
    $blocked = @($results | Where-Object State -in @('BLOCKED','INCOMPLETE')).Count
    $overall = if ($failed) { 'FAIL' } elseif ($blocked) { 'INCOMPLETE' } else { 'PASS' }
    $lines = @('# Unified verification report','',"- Overall: **$overall**","- Started: $(Get-Date -Format o)","- Branch: $(& git branch --show-current)","- Environment: $([System.Runtime.InteropServices.RuntimeInformation]::OSDescription)","- Command log: ``build/verification/unified-commands.log``",'', '| Gate | State | Exit | Command | Detail |','|---|---|---:|---|---|')
    foreach ($result in $results) { $lines += "| $($result.Name) | $($result.State) | $($result.Exit) | ``$($result.Command -replace '\|','/')`` | $($result.Detail) |" }
    $lines += ''; $lines += 'The SQL fixture models Auth/Storage tables; the HTTP checks above only verify service health. The integrated journey runs only against the local Supabase stack and records missing local prerequisites as BLOCKED.'
    $lines | Set-Content -Encoding utf8 $reportPath
    Get-Content $reportPath
    if ($overall -eq 'FAIL') { exit 1 }
    if ($overall -eq 'INCOMPLETE') { exit 2 }
} finally { Pop-Location }
