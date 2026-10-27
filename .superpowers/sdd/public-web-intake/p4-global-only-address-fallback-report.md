# P4 global-only address fallback report

Date: 2026-10-26

## Ruling

The managed Supabase Edge address source remains unverified. The public intake handler now sends a required `network_hash` field whose value is either a validated 64-character lowercase HMAC or explicit JSON `null`. An unresolved address sends `null` and skips HMAC. Caller-provided `X-Forwarded-For`, `CF-Connecting-IP`, and `X-Real-IP` remain untrusted. Malformed non-null resolver values still fail closed.

The T2 RPC and its private queue/event hash columns accept null. Null requests skip only the per-network advisory lock and rolling hourly/daily checks. The global capacity lock and pending limit always apply. Turnstile, origin, hostname/action, strict key allowlists, validation, idempotency, and RPC grants remain enforced. The per-network limiter is **incomplete** until an authoritative managed address source is proven; global capacity and Turnstile are the only active fallback guards.

## Owned files

- `supabase/functions/public-intake/contracts.ts`
- `supabase/functions/public-intake/handler.ts`
- `supabase/functions/public-intake/handler_test.ts`
- `supabase/migrations/202610250003_public_intake.sql`
- `supabase/tests/database/public_intake_test.sql`
- `docs/operations/public-intake.md`
- `docs/verification/public-intake-acceptance.md`

## TDD evidence

- RED: the new SQL scenario against the original migration rejected null with `invalid_payload` at the new acceptance assertion.
- RED: the new Deno RPC-forwarding regression failed type-checking because `ReceiveIntakeRequest.network_hash` did not admit null.
- GREEN: unresolved address plus forged forwarding headers returns the generic accepted response, forwards only null, still verifies Turnstile, and never calls HMAC. A malformed non-null resolver value still returns 503.
- GREEN: SQL accepts null, stores null metadata, replays the same submission idempotently, and rejects a second null-hash submission at a pending limit of one.

## Verification

- `deno check supabase/functions/public-intake/index.ts` — PASS.
- `deno test supabase/functions/public-intake` — PASS, 20/20.
- `python scripts/test_database.py public_intake_test.sql --public-intake-concurrency` — PASS in the guarded disposable loopback PostgreSQL harness; scenario and existing global-capacity, same-network, retry, review, registration, and revocation concurrency checks passed.
- `git diff --check` — PASS.
- No hosted Supabase, Cloudflare, Google, Auth, Storage, function, migration, or Pages operation was run. No secret values were inspected or recorded.

## Commit and remaining limitation

Implementation commit: `4193f17` (`feat: add global-only intake address fallback`). This report is committed separately so it can record the implementation commit hash.

Hosted deployment and end-to-end behavior remain unverified. The authoritative Edge address source and per-network hourly/daily protection remain incomplete. Do not describe the fallback as equivalent to per-network limiting or publish the Pages site based on this local evidence.
