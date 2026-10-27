# P4 Management API runner report

## Implemented

- Added the deliberate `--management-api` transport. The existing psql transport remains the default and retains its direct database URL validation.
- Management API mode still validates the trusted project reference and exact `SUPABASE_URL` host, but does not require `PUBLIC_INTAKE_DATABASE_URL`.
- Every SQL invocation uses `supabase db query --linked --project-ref <exact-ref> --file <OS-temp-file> --output-format json`. The temporary file is closed before invocation and removed in a `finally` block.
- Management API responses fail closed unless valid JSON contains a `rows` list and the specific result shape needed by the runner. Identity must report both `current_database=postgres` and `current_user=postgres`.
- The existing backup, authenticated project listing, typed target confirmation, migration inventory, scenario digest and SQL checks, rollback, baseline, and reconciliation gates remain in the shared execution flow. Raw CLI output is withheld.
- Added offline tests for a complete management-mode smoke run without a database URL, target and typed-confirmation failures before database queries, request scoping and temp-file cleanup, and CLI-output redaction. Existing backup tests continue to assert missing and wrong-project backups fail closed.

## Verification

- TDD RED observed: before implementation, target confirmation errored on the unsupported `management_api` keyword and the CLI rejected `--management-api`.
- The new management-mode tests pass, including baseline parsing, scenario result parsing, and after-state reconciliation.
- `python -m unittest discover -s scripts -p test_public_intake_hosted_runner.py -v`: all 38 tests passed, including both follow-up regressions.
- `python -m py_compile scripts/test_public_intake_hosted.py scripts/test_public_intake_hosted_runner.py`: passed.
- `git diff --check`: passed (Git emitted only existing LF-to-CRLF working-copy warnings).

## Management API result and reconciliation follow-up

- TDD RED reproduced the void-result bug: the management-mode full preproduction `public_intake_test.sql` run failed when the CLI returned `[{"assert_true": null}]`; direct result tests also failed because the scenario reader did not exist. Scenario-only result parsing now accepts empty rows and one null-valued cell as psql-equivalent empty output. Identity, baseline, and preflight reads still require exactly one scalar result.
- A fault-injection regression returns malformed CLI output after the full scenario has dispatched. With the old narrow final reconciliation handler restored, the test observed evidence stuck at `STARTED`. The current handler records `FAIL`, blocker code `reconciliation_unavailable`, recovery-required cleanup, and `completed_at`, while keeping raw output out of logs and evidence.
- This follow-up is offline only; no hosted scenario was dispatched.
- The full 38-test suite, Python compilation, and `git diff --check` all pass after these fixes.

## Reviewed scenario pin follow-up

The first full-suite run exposed a stale `SCENARIO_SHA256` entry for the unchanged `supabase/tests/database/public_intake_test.sql`. Parent review confirmed its canonical text-normalized SHA-256 is `70dfbc1b2fb7ba81023167f5d730cfddc9c7679f712157b5bd0bb6f2f09f128d`; its raw CRLF working-tree bytes hash differently. Updated only the pin to the canonical text digest; the SQL scenario stayed unchanged. The reviewed-scenario pin and psql preproduction dispatch tests now pass.

No hosted database query was run. No hosted concurrency path was enabled.
