#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
mkdir -p build/verification
REPORT=build/verification/unified-report.md
LOG=build/verification/unified-commands.log
RESULTS=()
printf 'Unified verification started %s\n' "$(date --iso-8601=seconds 2>/dev/null || date -u)" > "$LOG"

run_gate() {
  local name="$1"; shift
  local required="${1:-required}"
  if [[ "$required" == optional ]]; then shift; fi
  local cmd="$*"
  if [[ -n "${SUPABASE_ANON_KEY:-}" ]]; then cmd="${cmd//"$SUPABASE_ANON_KEY"/[redacted]}"; fi
  if ! command -v "$1" >/dev/null 2>&1; then
    local state=BLOCKED
    [[ "$required" == optional ]] && state=INCOMPLETE
    RESULTS+=("$name|$state|n/a|$cmd|executable unavailable")
    printf '%s [%s] executable unavailable: %s\n' "$state" "$name" "$1" >> "$LOG"
    return
  fi
  printf '\n[%s] %s\n' "$name" "$cmd" | tee -a "$LOG"
  "$@" 2>&1 | tee -a "$LOG"
  local code=${PIPESTATUS[0]}
  local state=PASS; (( code == 0 )) || state=FAIL
  RESULTS+=("$name|$state|$code|$cmd|")
  printf '[%s] exit=%s\n' "$name" "$code" | tee -a "$LOG"
}

run_journey() {
  local name='Integrated registrar-to-attendance browser journey'
  local python_tool
  python_tool="$(command -v python3 || command -v python || true)"
  if [[ -z "$python_tool" ]]; then
    RESULTS+=("$name|BLOCKED|n/a|python scripts/run_unified_journey.py|Python executable unavailable")
    printf 'BLOCKED [%s] Python executable unavailable\n' "$name" >> "$LOG"
    return
  fi
  local cmd="$python_tool scripts/run_unified_journey.py"
  printf '\n[%s] %s\n' "$name" "$cmd" | tee -a "$LOG"
  "$python_tool" scripts/run_unified_journey.py 2>&1 | tee -a "$LOG"
  local code=${PIPESTATUS[0]}
  local state=PASS; local detail=''
  if (( code == 2 )); then
    state=BLOCKED
    detail='local browser journey prerequisites are unavailable or unsafe'
  elif (( code != 0 )); then
    state=FAIL
  fi
  RESULTS+=("$name|$state|$code|$cmd|$detail")
  printf '[%s] exit=%s state=%s\n' "$name" "$code" "$state" | tee -a "$LOG"
}

block_health_probes() {
  local detail="$1"
  RESULTS+=("Auth HTTP health|BLOCKED|n/a|GET SUPABASE_URL/auth/v1/health|$detail")
  RESULTS+=("Storage HTTP health|BLOCKED|n/a|GET SUPABASE_URL/storage/v1/status|$detail")
  printf 'BLOCKED [Auth/Storage HTTP health] %s\n' "$detail" >> "$LOG"
}

run_gate 'Flutter version' optional flutter --version
run_gate 'Dart version' optional dart --version
run_gate 'Python version' optional python3 --version
psql_tool="$(command -v psql || true)"
if [[ -z "$psql_tool" && -x "$HOME/.codex/tools/ieadpe-postgresql/pgsql/bin/psql" ]]; then psql_tool="$HOME/.codex/tools/ieadpe-postgresql/pgsql/bin/psql"; fi
if [[ -n "$psql_tool" ]]; then run_gate 'PostgreSQL client version' "$psql_tool" --version
else RESULTS+=('PostgreSQL client version|INCOMPLETE|n/a|psql --version|executable unavailable'); fi
run_gate 'Supabase CLI version' optional supabase --version
run_gate 'Flutter analyze' flutter analyze
run_gate 'Flutter tests' flutter test
run_gate 'Flutter web build' flutter build web
run_gate 'Static web preflight' python3 scripts/web_preflight.py build/web

case_file=build/verification/unified-cases.tsv
if python3 scripts/verification_cases.py --cases-lines > "$case_file" 2>> "$LOG"; then
  while IFS=$'\t' read -r kind name arg1 arg2 arg3 arg4 arg5; do
    [[ -n "$kind" && -n "$name" ]] || continue
    argv=()
    [[ -n "${arg1:-}" ]] && argv+=("$arg1")
    [[ -n "${arg2:-}" ]] && argv+=("$arg2")
    [[ -n "${arg3:-}" ]] && argv+=("$arg3")
    [[ -n "${arg4:-}" ]] && argv+=("$arg4")
    [[ -n "${arg5:-}" ]] && argv+=("$arg5")
    if [[ "$kind" == sql ]]; then
      run_gate "SQL $name" python3 scripts/test_database.py "${argv[@]}"
    else
      run_gate "Concurrency $name" python3 scripts/test_database.py "${argv[@]}"
    fi
  done < "$case_file"
else
  code=$?
  RESULTS+=("Verification case manifest|FAIL|$code|python3 scripts/verification_cases.py --cases-lines|invalid or unavailable manifest")
  printf '[FAIL] Verification case manifest exit=%s\n' "$code" | tee -a "$LOG"
fi
run_gate 'Synthetic migration rehearsal' python3 -m unittest discover -s test/migration -p '*_test.py'

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]]; then
  block_health_probes 'SUPABASE_URL or SUPABASE_ANON_KEY is unset'
else
  guard_python="$(command -v python3 || command -v python || true)"
  if [[ -z "$guard_python" ]]; then
    block_health_probes 'Python is unavailable to validate the local Supabase URL'
  elif ! "$guard_python" -c "import sys; sys.path.insert(0, 'scripts'); from local_supabase_guard import require_loopback_url; require_loopback_url(sys.argv[1])" "$SUPABASE_URL" >/dev/null 2>&1; then
    block_health_probes 'SUPABASE_URL rejected: Auth and Storage probes require a loopback URL'
  else
    run_gate 'Auth HTTP health' curl -q --noproxy '*' -fsS -o /dev/null "${SUPABASE_URL%/}/auth/v1/health" -H "apikey: $SUPABASE_ANON_KEY"
    run_gate 'Storage HTTP health' curl -q --noproxy '*' -fsS -o /dev/null "${SUPABASE_URL%/}/storage/v1/status" -H "apikey: $SUPABASE_ANON_KEY"
  fi
fi

chrome="${CHROME_EXECUTABLE:-}"
if [[ -z "$chrome" ]]; then chrome="$(command -v chromium || command -v chromium-browser || command -v google-chrome || command -v chrome || true)"; fi
if [[ -z "$chrome" ]]; then
  RESULTS+=('Browser adapter smoke|BLOCKED|n/a|Chrome/Chromium smoke scripts|Chrome/Chromium executable unavailable')
else
  export CHROME_EXECUTABLE="$chrome"
  run_gate 'Browser version' optional "$chrome" --version
  run_gate 'Browser locale smoke' python3 test/platform/run_collation_browser.py
  run_gate 'Browser file export smoke' python3 test/platform/run_export_browser.py
fi
run_gate 'Local routes and asset rewrite fixture' python3 -m unittest discover -s scripts -p test_release_operations.py
run_gate 'Unified journey runner guards' python3 -m unittest discover -s scripts -p test_unified_journey_runner.py

deno_tool="$(command -v deno || true)"
if [[ -z "$deno_tool" && -x "$HOME/.codex/tools/deno-local/bin/deno" ]]; then
  deno_tool="$HOME/.codex/tools/deno-local/bin/deno"
fi
if [[ -z "$deno_tool" && -x "$HOME/.codex/tools/deno-local/bin/deno.exe" ]]; then
  deno_tool="$HOME/.codex/tools/deno-local/bin/deno.exe"
fi
if [[ -n "$deno_tool" ]]; then
  run_gate 'Public intake test handler check' "$deno_tool" check scripts/public_intake_test_server.ts
  run_gate 'Public intake Edge handler tests' "$deno_tool" test supabase/functions/public-intake
else
  RESULTS+=('Public intake test handler check|INCOMPLETE|n/a|deno check scripts/public_intake_test_server.ts|Deno executable unavailable')
  RESULTS+=('Public intake Edge handler tests|INCOMPLETE|n/a|deno test supabase/functions/public-intake|Deno executable unavailable')
fi
run_journey

failed=0; blocked=0
for item in "${RESULTS[@]}"; do
  state="${item#*|}"; state="${state%%|*}"
  [[ "$state" == FAIL ]] && ((failed+=1))
  [[ "$state" == BLOCKED || "$state" == INCOMPLETE ]] && ((blocked+=1))
done
overall=PASS
(( failed > 0 )) && overall=FAIL
(( failed == 0 && blocked > 0 )) && overall=INCOMPLETE
{
  printf '# Unified verification report\n\n- Overall: **%s**\n- Started: %s\n- Branch: %s\n- Environment: %s\n- Command log: `build/verification/unified-commands.log`\n\n| Gate | State | Exit | Command | Detail |\n|---|---|---:|---|---|\n' "$overall" "$(date --iso-8601=seconds 2>/dev/null || date -u)" "$(git branch --show-current)" "$(uname -a)"
  for item in "${RESULTS[@]}"; do IFS='|' read -r name state code cmd detail <<< "$item"; printf '| %s | %s | %s | `%s` | %s |\n' "$name" "$state" "$code" "${cmd//|//}" "$detail"; done
  printf '\nThe SQL fixture models Auth/Storage tables; the HTTP checks above only verify service health. The integrated journey runs only against the local Supabase stack and records missing local prerequisites as BLOCKED.\n'
} > "$REPORT"
cat "$REPORT"
if (( failed > 0 )); then exit 1; fi
if (( blocked > 0 )); then exit 2; fi
