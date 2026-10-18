# Unified Quality and Release Preparation — Design Spec

Status: local verification and synthetic migration tooling implemented; release preparation documented. Integrated browser journey and external release evidence remain incomplete. No production deployment or private-record migration is included.

## Quality contract

One local/CI entry point runs Dart analysis/tests, web build, SQL migration/RLS/concurrency suites, Auth/Storage HTTP checks when the local stack is available, and browser flows. Supabase HTTP/database targets must be loopback-only; a hosted user-scoped URL is rejected before any health request or fixture write. It records each command and environment. Missing services/devices are incomplete, never green. Security and integrity checks are blocking SQA; usability defects are prioritized SQC findings. Map evidence to ISO 25010 functional suitability, security, reliability, usability, performance efficiency and maintainability. Use a small GQM metric set: unauthorized-read denials, idempotent handoff count, 100-cap enforcement, page read budget, task completion/error rate and build/test results.

## Human-facing verification

Use `verification-test` traceability, equivalence classes, boundary values, base paths and regression cases. Use `a11y-ethics` to check keyboard, screen reader, 200% text, reduced motion, contrast, privacy and consent at 360/768/1440. Use `apple-design` to assess feedback and motion without adding decorative motion. Run Chromium end-to-end and Firefox/WebKit smoke where available; document actual versions and limitations.

### Integrated Chromium journey

The registrar-to-attendance browser journey runs against the local Supabase stack with synthetic Auth identities and records. Before any HTTP request or SQL provisioning, its runner validates the API and database hosts as loopback-only; it never falls back to a user-scoped or hosted `SUPABASE_URL`. A local `service_role` key may be used only by the host-side fixture provisioner and is never placed in Flutter defines, browser storage, logs, or artifacts.

The Chromium test exercises registrar creation, authorized campaign assignment/follow-up, scoped referral, one-to-one student linking, separate enrollment, and finalized attendance through the production Flutter widgets and local Supabase HTTP API. It also proves cross-congregation reads/writes are denied and that revoking the `user_access` congregation assignment denies subsequent requests with the same authenticated session and clears protected app state. Existing SQL tests remain separate evidence for database invariants. The test does not use hosted OAuth or any private/production record.

## Operations and migration

`cloud-deploy` records Supabase/static-host shared responsibilities, grants/IAM, encryption, backup and restore rehearsal, monitoring, outage behavior and Free-tier usage. Migration tooling performs synthetic dry runs with stable legacy IDs and reconciliation counts; a real export/import is separately authorized. Cutover and rollback must be written and reviewed before release, with the old data kept intact until reconciliation succeeds. Live OAuth/Storage HTTP, hosted deep links and on-device Android checks from the convert final report remain open release prerequisites.

## Completion

The app and local backend composition exist, and the executed local security/behavior evidence is reported separately from release checks. The spec remains incomplete until the plan's local-Supabase Chromium journey and accessibility/operations evidence are executed. The report clearly separates passing, failing, blocked and incomplete checks and never treats the completed convert unit suite as proof of the integrated app.
