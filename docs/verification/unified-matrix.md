# Unified verification matrix

This matrix defines the local gate (`scripts/verify_unified.ps1` on Windows, `scripts/verify_unified.sh` on macOS/Linux) and CI job (`.github/workflows/verify-unified.yml`). Both invoke the same Flutter, PostgreSQL harness, SQL scenarios, concurrency checks, guarded local HTTP health probes, browser adapter smokes, and `scripts/run_unified_journey.py`. Each invocation writes `build/verification/unified-report.md` and `build/verification/unified-commands.log`.

## Result contract

| State | Meaning | Gate result |
|---|---|---|
| PASS | Command ran and returned zero. | Can contribute to a green run. |
| FAIL | Command ran and returned nonzero. | Blocking; process exits 1. |
| BLOCKED | A required executable, local service, database, or browser prerequisite was absent; the integrated runner also returns exit 2 for this state. | Overall **INCOMPLETE**; process exits 2. |
| INCOMPLETE | An optional tool/version probe was unavailable. | Overall **INCOMPLETE**; process exits 2. |

The workflow starts a PostgreSQL 17 service at loopback port 54329 and a local Supabase stack. Locally, the operator must start those services and set `IEADPE_DATABASE_URL` to a loopback database. `SUPABASE_URL` and `SUPABASE_ANON_KEY` are not required to launch the scripts; if unset, the separate health probes are recorded as `BLOCKED`, so the overall result remains **INCOMPLETE**. When set, the shared Python guard accepts only localhost or a literal loopback address before either probe. The integrated runner reads API and database credentials from local `supabase status`, never from hosted environment fallbacks. CI exports only its local API URL and anon key to the gate process. No cloud endpoint, production account, migration, or record is targeted. Missing local service prerequisites never become a successful release check.

## Executed command inventory

| Gate | Command | SQA/SQC | Result evidence |
|---|---|---|---|
| Static analysis | `flutter analyze` | SQA | Exit code and analyzer output in command log. |
| Unit/widget tests | `flutter test` | SQA | Exit code and test counts/output in command log. |
| Web artifact | `flutter build web` | SQA | Exit code and build output in command log. |
| Static artifact routing/size | `python scripts/web_preflight.py build/web` | SQA | Exact routes, symlinks, file size/count checks. |
| Database scenarios | `python scripts/test_database.py <scenario>` for every SQL file below | SQA | Every invocation creates a uniquely named disposable loopback database, loads `local_auth_storage.sql` and **all checked-in migration files in lexical order**, runs one exact SQL file, then drops the database. |
| Synthetic migration rehearsal | `python -m unittest discover -s test/migration -p '*_test.py'` | SQA | Deterministic synthetic source rows only; no live export/import. |
| Auth HTTP health | `GET $SUPABASE_URL/auth/v1/health` with local anon API key after `require_loopback_url` | SQA prerequisite | Unsafe or unset URLs are `BLOCKED` before curl runs; response bodies are discarded. Service health only; this does not prove sign-in, grants, or policy enforcement through HTTP. |
| Storage HTTP health | `GET $SUPABASE_URL/storage/v1/status` with local anon API key after `require_loopback_url` | SQA prerequisite | Unsafe or unset URLs are `BLOCKED` before curl runs; response bodies are discarded. Service health only; SQL RLS fixtures are not an HTTP Storage emulator. |
| Integrated Chromium journey | `python scripts/run_unified_journey.py` | SQA | Exit 0 is PASS, exit 1 is FAIL, and exit 2 is BLOCKED; blocked execution makes the overall gate INCOMPLETE. The runner reads local Supabase status and performs the app HTTP journey only with loopback services. |
| Browser locale smoke | `python test/platform/run_collation_browser.py` | SQA for adapter contract | Compiles the production locale adapter and runs it in headless Chrome/Chromium. |
| Browser export smoke | `python test/platform/run_export_browser.py` | SQA for adapter contract | Compiles the production export adapter and runs the synthetic browser protocol. It does not verify a real file chooser. |
| Local route/asset fixture | `python -m unittest scripts.test_release_operations` | SQA for static rewrite behavior | Synthetic loopback routes, existing JS/WASM/image bytes, missing artifact, and size boundary. |

Exact database files, one process each:

`access_test.sql`, `base44_unified_access_test.sql`, `catalog_test.sql`, `convert_commands_test.sql`, `convert_student_link_test.sql`, `feedback_test.sql`, `import_test.sql`, `lifecycle_test.sql`, `ministry_academic_test.sql`, `ministry_access_test.sql`, `ministry_congregations_test.sql`, `ministry_registry_test.sql`, `ministry_ui_reads_test.sql`, `photos_test.sql`, `unified_scope_test.sql`, and `weekly_test.sql`.

Exact independent-session race checks, one process each:

`--catalog-concurrency`, `--access-concurrency`, `--convert-concurrency`, `--convert-student-concurrency`, `--import-concurrency`, `--lifecycle-concurrency`, `--ministry-registry-concurrency`, and `--ministry-academic-concurrency`.

The matrix intentionally names files and flags instead of using a broad discovery command: the report can therefore show which security scenario ran or failed. The SQL harness applies current migration files and synthetic fixtures; these checks are local PostgreSQL evidence, not a hosted Supabase migration rehearsal.

## Traceability, partitions, and boundaries

| Requirement / partition | Evidence path | Expected denial or boundary |
|---|---|---|
| Anonymous and unrelated congregation reads; inactive/revoked grant; campaign-only role | `ministry_access_test.sql`, `ministry_ui_reads_test.sql`, `access_test.sql`, `unified_scope_test.sql` | `insufficient_privilege` or empty scoped projection; revoked scope is absent on the next read. |
| Forged cross-congregation create/read/write; direct table access | `ministry_access_test.sql`, `convert_student_link_test.sql`, `ministry_ui_reads_test.sql` | RPC rejects unauthorized scope; authenticated/anonymous table access remains revoked. |
| Valid role, staff, supervisor, and registrar access partitions | `ministry_access_test.sql`, `ministry_registry_test.sql`, `access_test.sql`, `convert_commands_test.sql` | Authorized role can use only its defined projection and mutation command. |
| Idempotency / uncertain retry | All mutation-oriented scenarios; especially `access_test.sql`, `convert_commands_test.sql`, `ministry_academic_test.sql`, `photos_test.sql`, and `import_test.sql` | Same operation returns its original receipt; rejected operation leaves no new receipt. Race reports also assert receipt counts. |
| Input `limit: 0` boundary | Flutter test `zero page limit is rejected before protected transport` in `test/features/ministry/ui/ministry_browser_repository_test.dart`; SQL scenario `ministry_ui_reads_test.sql`, assertion `zero-sized student page accepted` | Flutter rejects before HTTP; PostgreSQL rejects `page_size` outside `1..100` with `invalid_parameter_value`. |
| Input `limit: 1` boundary | `ministry_ui_reads_test.sql`: assertions `student page is scoped, minimal, stable and bounded`, `student cursor advances exactly once`, `class page filters status before paging`, and `class cursor advances in stable name order`; `ministry_access_test.sql`: `directory projects allowed contact and page one` | One-row page succeeds and continuation cursor is exercised. |
| Capacity boundary 99 / 100 / 101 | `ministry_academic_test.sql`: assertions `99 to 100 historical enrollments allowed`, `enrollment 101 exceeded capacity`, and `capacity rejection left no enrollment`; `database_ministry_academic_concurrency.py`: `class cap race and both enrollment/roster-freeze serialization orders` | Seed 99 active historical enrollments; 100th succeeds; 101st is rejected and count remains 100. Concurrency companion races two claims; exactly one reaches 100. |
| Page boundary 100 / 101 | `ministry_access_test.sql`: `supervisor all-scope directory bounded projection`, `oversized page accepted`; `convert_student_link_test.sql`: `referrals include assigned nondeleted converts only`; 101 page denials in `ministry_access_test.sql`, `ministry_ui_reads_test.sql` | Requests of 100 are accepted; 101 is rejected. |
| Revision / stale write and finalized attendance | `ministry_academic_test.sql`, `ministry_access_test.sql` | Stale revision and edit-after-finalize are rejected; replay is stable. |
| Ministry congregation registry | `ministry_congregations_test.sql` | New migration 018: verify server-derived scoped congregation choices and grant restrictions against the actual migration set. |
| Critical races | `database_*_concurrency.py` invoked by exact flags | `database_access_concurrency.py` protects access mutation races; `database_convert_student_concurrency.py` covers duplicate handoff; `database_import_concurrency.py` covers import replay; `database_catalog_concurrency.py` covers archive/create/grant; `database_ministry_academic_concurrency.py` covers class cap and roster freeze; `database_ministry_registry_concurrency.py` covers role-slot claims. Each script asserts final database state. |

For row-limit evidence, the API budget is **at most 100 returned records per paginated RPC request**. This is a per-request bound, not a bound on how many pages a user can fetch over time. The SQL checks include valid and invalid scope/role partitions described above. Full valid/invalid partitions across every RPC argument are not currently enumerated, so this matrix does not claim exhaustive API partition coverage.

## ISO/IEC 25010 and GQM

| Quality area | SQA blocking evidence | SQC / release review |
|---|---|---|
| Functional suitability | SQL command contracts, app `flutter test`, web build, exact handoff and attendance assertions | Registrar-to-attendance end-to-end success and usability review remain unexecuted. |
| Security | Cross-scope/role/revocation denials, private table grants, photo metadata/ownership, auth/storage service availability | Live Auth sign-in, HTTP authorization denials, hosted OAuth settings, and Storage object policy behavior remain release blockers. Health-only HTTP probes do not close them. |
| Reliability | Idempotency and concurrency final-state assertions; build/test exit status | Device, browser engine breadth, outage/restart, and restore rehearsal remain open. |
| Usability | Current widget/unit tests are regression evidence only | Keyboard, screen reader, 200% text, reduced motion, contrast, feedback, and completion/error rates at 360/768/1440 remain unreviewed. |
| Performance efficiency | Bounded list RPC response of at most 100 rows; weekly counts have a large synthetic set | No latency/load budget or measurement is defined yet; SQA performance claim is incomplete. |
| Maintainability | Analyzer, exact gate command log, migration replay against disposable PG | Browser/version and release operations evidence must accompany release review. |

The bounded GQM set for the release report is:

| Goal / question | Metric | Current evidence source |
|---|---|---|
| Prevent unauthorized disclosure | Count of unauthorized read/write assertions that are denied; any accepted forged scope is a release blocker. | Named SQL assertions and command exits; numeric extraction is not yet automated. |
| Preserve retry safety | Number of idempotent handoff/mutation replays returning the same receipt/result. | Exact SQL plus concurrency assertions; numeric extraction is not yet automated. |
| Enforce class capacity | Final active enrollment count and rejected attempt at 101. | Academic SQL and race script assert 100 and one loser. |
| Bound list reads | Maximum rows returned by one page request. | **100 rows/RPC**; explicit 101 rejection. |
| Complete the user journey | Registrar-to-attendance browser result and error count. | Recorded only when the integrated runner completes; the current local run is BLOCKED until local Supabase is available. |
| Protect build/test quality | Analyze/test/build pass and failure counts. | Unified command log and per-command exit code. |

These metrics describe what the suite can evidence now. Missing numeric aggregation, application journey, HTTP policy checks, and performance measurements stay visible as open work; they are not scored as zero defects or 100% completion.

## Human-facing and release-only prerequisites

The following checks are not represented by the current unit/database suite and must stay **INCOMPLETE** until actual evidence is attached:

- Integrated Chromium registrar → authorized convert follow-up → explicit student link → class enrollment → finalized attendance → progress, including forged cross-scope operations and grant revocation over the HTTP application path.
- Firefox and WebKit smoke, and recorded actual browser versions.
- 360/768/1440 layouts, 200% text, keyboard, screen reader, reduced motion, contrast, privacy and consent review.
- Auth sign-in/denial and Storage upload/read denial over local HTTP using synthetic users/objects. Current endpoints check health only.
- Hosted deep links, OAuth provider and redirect configuration, and live Storage HTTP checks.
- Android install/device workflows, OS picker/resume, signing/certificate validation.
- Supabase/static host responsibilities, least-privilege grants/IAM, encryption, monitoring and Free-tier budget, database **and Storage** backup, restore rehearsal, outage behavior, reviewed cutover and rollback.
- A real legacy export/import remains separately authorized. Task 1 performs no export/import and never targets production data.

`docs/verification/final-report.md` is historical convert-only baseline context, not a run of this gate. The latest completed run is summarized in `docs/verification/unified-final-report.md`; for future runs, use the generated report and command log. A green process exit is possible only when every recorded required check ran and passed; unresolved Task 3 release prerequisites still prevent release approval.
