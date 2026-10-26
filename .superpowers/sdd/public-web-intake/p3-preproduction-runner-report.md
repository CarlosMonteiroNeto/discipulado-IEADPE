# P3 — Pre-production hosted runner

Status: complete. Implementation commit: `51ce48f088eb855ed683c287ca4442f969fcf227` (`feat: add guarded preproduction intake runner mode`).

## Changes

- `scripts/test_public_intake_hosted.py` adds explicit `--preproduction`. Default mode keeps the T2 capacity scenario blocked. Pre-production permits only the existing digest-pinned, rollback-only `public_intake_test.sql` scenario, and only after the existing external fresh backup, trusted project/TLS, authenticated project-list, exact typed confirmation, and migration checks.
- The validator narrowly permits that scenario's exact four-private-table `TRUNCATE ... CASCADE` reset and its test-only call set. Other truncation targets and unsafe SQL remain rejected. The limited run-owned Auth/receipt metadata requirement is waived only for this transaction because all its fixtures roll back. Evidence records the mode and marks a write attempt before dispatch.
- The existing `--concurrency` path remains unconditionally blocked. No hosted database or other remote command was run.
- `.superpowers/sdd/public-web-intake/progress.md` records P3 implementation and the existing concurrency and network-address trust blockers.

## Verification

- `python -m unittest discover -s scripts -p test_public_intake_hosted_runner.py -v` — 32/32 passed. New cases cover default blocking, exact SQL allowlisting, rejection of another truncate target, explicit offline mode dispatch after confirmations, wrong typed target refusal, and continued concurrency blocking under pre-production mode.
- `python -m py_compile scripts/test_public_intake_hosted.py scripts/test_public_intake_hosted_runner.py` — passed.
- `git diff --check` — passed.

## Limitations

- The legacy concurrency helper still truncates shared tables and commits fixed Auth, grant, and official-row fixtures without exact cleanup. It remains blocked pending a separately proven run-owned hosted procedure.
- Provider documentation reviewed by the acceptance controller does not prove Supabase managed Edge sanitizes or authoritatively supplies `cf-connecting-ip`, `x-real-ip`, or `x-forwarded-for`. Keep the per-network limiter incomplete and retain Turnstile plus global capacity fallback; do not trust those headers.
- P3 only prepares the runner. This task applied no migrations, deployed no function, and executed no hosted scenario.
