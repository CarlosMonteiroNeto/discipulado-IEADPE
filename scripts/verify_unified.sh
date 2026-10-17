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

sql=(access_test.sql catalog_test.sql convert_commands_test.sql convert_student_link_test.sql feedback_test.sql import_test.sql lifecycle_test.sql ministry_academic_test.sql ministry_access_test.sql ministry_congregations_test.sql ministry_registry_test.sql ministry_ui_reads_test.sql photos_test.sql unified_scope_test.sql weekly_test.sql)
for scenario in "${sql[@]}"; do run_gate "SQL $scenario" python3 scripts/test_database.py "$scenario"; done
run_gate 'Synthetic migration rehearsal' python3 -m unittest discover -s test/migration -p '*_test.py'
for race in catalog access convert convert-student import lifecycle ministry-registry ministry-academic; do
  run_gate "Concurrency $race" python3 scripts/test_database.py "--${race}-concurrency"
done

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]]; then
  RESULTS+=('Auth HTTP health|BLOCKED|n/a|GET SUPABASE_URL/auth/v1/health|SUPABASE_URL or SUPABASE_ANON_KEY is unset')
  RESULTS+=('Storage HTTP health|BLOCKED|n/a|GET SUPABASE_URL/storage/v1/status|SUPABASE_URL or SUPABASE_ANON_KEY is unset')
else
  run_gate 'Auth HTTP health' curl -fsS "${SUPABASE_URL%/}/auth/v1/health" -H "apikey: $SUPABASE_ANON_KEY"
  run_gate 'Storage HTTP health' curl -fsS "${SUPABASE_URL%/}/storage/v1/status" -H "apikey: $SUPABASE_ANON_KEY"
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
RESULTS+=('Integrated registrar-to-attendance browser journey|INCOMPLETE|n/a|integration_test/unified_journey_test.dart|owned by Task 3; no runnable integrated driver exists')

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
  printf '\nThe SQL fixture models Auth/Storage tables; the HTTP checks above only verify service health. No integrated registrar-to-attendance browser journey exists in this worktree and it remains a release prerequisite.\n'
} > "$REPORT"
cat "$REPORT"
if (( failed > 0 )); then exit 1; fi
if (( blocked > 0 )); then exit 2; fi
