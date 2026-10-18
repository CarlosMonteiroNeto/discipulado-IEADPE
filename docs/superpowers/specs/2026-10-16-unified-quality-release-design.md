# Unified Quality and Release Preparation — Design Spec

Status: local verification and synthetic migration tooling implemented; release preparation documented. Integrated browser journey and external release evidence remain incomplete. No production deployment or private-record migration is included.

## Quality contract

One local/CI entry point runs Dart analysis/tests, web build, SQL migration/RLS/concurrency suites, Auth/Storage HTTP checks when the local stack is available, and browser flows. It records each command and environment. Missing services/devices are incomplete, never green. Security and integrity checks are blocking SQA; usability defects are prioritized SQC findings. Map evidence to ISO 25010 functional suitability, security, reliability, usability, performance efficiency and maintainability. Use a small GQM metric set: unauthorized-read denials, idempotent handoff count, 100-cap enforcement, page read budget, task completion/error rate and build/test results.

## Human-facing verification

Use `verification-test` traceability, equivalence classes, boundary values, base paths and regression cases. Use `a11y-ethics` to check keyboard, screen reader, 200% text, reduced motion, contrast, privacy and consent at 360/768/1440. Use `apple-design` to assess feedback and motion without adding decorative motion. Run Chromium end-to-end and Firefox/WebKit smoke where available; document actual versions and limitations.

## Operations and migration

`cloud-deploy` records Supabase/static-host shared responsibilities, grants/IAM, encryption, backup and restore rehearsal, monitoring, outage behavior and Free-tier usage. Migration tooling performs synthetic dry runs with stable legacy IDs and reconciliation counts; a real export/import is separately authorized. Cutover and rollback must be written and reviewed before release, with the old data kept intact until reconciliation succeeds. Live OAuth/Storage HTTP, hosted deep links and on-device Android checks from the convert final report remain open release prerequisites.

## Completion

The app and local backend composition exist, and the executed local security/behavior evidence is reported separately from release checks. The current evidence does not establish the integrated Chromium registrar-to-attendance path or production readiness; do not mark this spec fully complete until the plan's Task 3 journey and accessibility/operations evidence are executed. The report clearly separates passing, failing, blocked and incomplete checks and never treats the completed convert unit suite as proof of the integrated app.
