# Final Sol 6.1 review follow-up fixes

Date: 2026-10-25

Branch: `feat/public-web-intake`
Baseline: `790c095b7d7d84a78f38fab3ac6e802669532bcc`

## Investigation and fixes

The adapter used `JSON.stringify(request)`, which emitted `submission_id`, `network_hash`, and `draft` at the JSON root while the SQL RPC contract is `ieadpe_receive_public_intake(request jsonb)`. The real adapter test now checks the named PostgREST shape `{request: {submission_id, network_hash, draft}}`; the request endpoint, credentials, headers, response handling, and error mapping are unchanged.

The approved retention values are fixed at 30 days for pending submissions and 90 days for decision metadata. PostgreSQL interval equality alone admits calendar months because interval comparisons normalize months. The settings constraints now reject nonzero year/month fields for `pending_ttl` and `decision_retention` while retaining exact interval equality. The T5 writer independently rejects nonzero year/month fields before recording a decision. SQL scenarios assert `1 month` pending expiry and `3 months` decision retention fail, and the decision test pins the expected `2027-01-23 12:00:00+00` expiry for its fixed test clock. Receipt retention was not changed.

The authenticated congregation repository depends on the existing `SELECT` grant. The hosted smoke fixture now asserts anon direct SELECT is denied and authenticated SELECT remains granted; the names-only public catalog checks remain in place. No grant migration or production privilege was changed.

Recomputed the SHA-256 values over normalized `read_text(encoding="utf-8").encode("utf-8")` sources after all SQL fixture edits, then updated the four allowlisted digest pins. The offline tests compare all pins with all allowlisted files and prove a safe source modification is rejected by the reviewed-digest check.

The tracked hosted readiness evidence continues to show migrations `202610250002`–`004` pending, so those migration source files were safe to amend. No applied migration history was rewritten.

## TDD evidence

- RPC wire: the adapter-level test failed first with expected `request` but received the three flat keys; passed after wrapping the RPC argument.
- Retention and smoke contracts: static contract tests failed first because the migration lacked month/year checks and the smoke denied authenticated congregation SELECT; both passed after the source changes.
- Digest pins: test first found the three updated allowlisted SQL scenarios did not match their old pins; after recomputation, all allowlisted sources match. A separate safe-edit test confirms modified source is refused.

## Verification

- `deno test supabase/functions/public-intake` — 19 passed.
- `deno check supabase/functions/public-intake/index.ts` — passed.
- `deno fmt --check supabase/functions/public-intake` — passed.
- `python -m unittest discover -s scripts -p 'test_public_intake_hosted*.py' -v` — 19 passed.
- `python -m unittest discover -s scripts -p test_verification_cases.py -v` — 10 passed.
- `python -m unittest discover -s scripts -p test_release_operations.py -v` — 9 passed.
- `python scripts/verification_cases.py --validate` — 34 SQL scenarios and 10 concurrency cases validated.
- `py_compile` for the hosted runner, hosted runner tests, verification tests, and release tests — passed.
- Recomputed all scenario digests against `SCENARIO_SHA256` — passed.
- `git diff --check` — passed.

## Remaining verification limit

SQL runtime verification is **INCOMPLETE**. No native PostgreSQL/`psql` target is installed. The authored SQL assertions and offline static contract regression were not executed against a database. No Docker, local Supabase, hosted SQL, migration apply, deployment, account change, or publication was performed.

## Commits

- `9924817e075d4770f7d8aaa88a1ef4c470827cb5` — `fix: honor public intake RPC and retention contracts`
- The report and progress receipt are committed separately.
