# Convert alignment results and gap disposition

<!-- canonical-document-authority -->
> **Dated candidate record.** The [current spec](../superpowers/specs/2026-10-20-ministry-corrective-release-design.md), [current plan](../superpowers/plans/2026-10-20-ministry-corrective-release-plan.md) and [JSON mirror](../superpowers/plans/2026-10-20-ministry-corrective-release-plan.json) govern current requirements, status, task order and authorization. The body preserves original candidate observations and scoped outcomes; retained next-step/model/workspace/push instructions belong to that historical context and do not redirect future execution.

This report records the documentation audit of completed baseline `implementation/supabase-free` at `642047f`. It does not rerun product suites. Evidence claims below are taken from `docs/verification/final-report.md`, source specs, existing test files and implementation paths. “Covered” means the final report records executed local evidence; it does not extend that evidence to hosted Supabase, browser hosting or physical devices.

## Evidence disposition

| Finding / requirement | Current evidence | Disposition and owner | Checkable assertion / gate |
|---|---|---|---|
| Functional/domain requirements and NFRs lack a consolidated trace. | `docs/verification/convert-requirements-trace.md` maps functions, domain rules, NFRs and evidence. | Covered by this alignment documentation. | Keep row-level evidence and release-only flags current when integration changes. |
| No project skill routing or INVEST DoR/DoD record. | `docs/superpowers/skills-routing.md` routes stage/domain skills and integration stories. | Covered by this alignment documentation. | Each plan task identifies stage, overlays, entry contract and executable exit assertion. |
| No per-screen heuristic/privacy audit. | `docs/verification/convert-ui-audit.md` records source-backed review and explicitly incomplete manual evidence. | Covered as a documentary baseline; no verified UI defect raised. | Future theme work records actual 360/768/1440, 200%, keyboard, screen reader, reduced-motion and contrast evidence. Owner: Plan 4 final gate. |
| Conversion-to-student boundary policy and UI privacy assertion. | Unified journey spec defines minimal referral, ownership snapshots, explicit match, terminal/archived rules and deliberate contact. Audit maps owner files. | Journey-plan action; Plan 3 tasks 1–3. | `ieadpe_promote_convert_to_student` permits one scoped link, rejects unassigned/revoked/out-of-scope cases, and does not auto-enroll or prefill religious content. |
| Handoff schema/RPC/RLS and race coverage do not exist yet. | Inspection found no `ministry_students.convert_id` migration or promotion RPC in completed convert baseline. | Journey-plan action; Plan 3 task 2 owns exact migration and SQL/Dart race files. | Unique nullable link; valid/invalid/boundary/retry/lost-response and both lock commit orders; unauthorized direct referral read denied; existing SQL suites pass. |
| Ministry pages and unified route/theme are not in completed convert app. | Baseline contains convert `App`, `SessionRouter`, and `AppShell`; no `lib/features/ministry` implementation at the audit baseline. | Journey-plan action; Plan 3 tasks 3–4. | One root session guard; 360/768/1440 and 200% text; denied user sees no hidden data/action; identity switch/revocation clears protected cache. |
| Real OAuth provider, Storage HTTP, hosted route refresh/callback and physical-device checks are not proven. | Final report explicitly marks them unrun; SQL/SDK fixtures are not service checks. | Release-only prerequisite; Plan 4 quality/release task. | Attach dated nonproduction provider/browser/device evidence; until then these checks remain open and release-blocking. |
| Full backend backup restore has no rehearsal evidence. | Operations docs describe separate DB and Storage-byte backups; current report records no production data activity. | Release-only prerequisite; Plan 4 operations/release task. | Restore isolated target, reconcile object counts/checksums, and validate login, RLS and real photo retrieval. |
| Automated local verification and source integrity. | Final report: 240 Flutter tests pass; 13 native-PG scenarios pass; analyzer clean; web build/preflight pass; debug APK build pass; 101/101 source hashes unchanged. | Already covered by completed Plan 19 report (not rerun here). | Retain as baseline evidence only. The debug APK is packaging evidence, not release signing/device evidence. |
| Route/cache session boundary. | `lib/routing/router.dart`; `test/workflows_test.dart` covers identity switch, resume failure/scope change and protected ownership journeys per final report. | Already covered for convert baseline; integration regression belongs to Plan 3 task 4. | On logout, identity change, failed validation or scope loss, no previous owner's protected data or route remains visible. |
| Breakpoint, 200% text and reduced-motion widget configuration. | `test/widgets/app_shell_test.dart`, `test/app_smoke_test.dart` and feature widgets exercise selected dimensions/scaling/disableAnimations; final report records full suite passed. | Covered as selected automation; fuller cross-screen manual assessment belongs to Plan 4. | No assertion beyond actual tested surfaces; do not mark manual review complete. |
| WhatsApp outbound behavior. | `convert_card.dart` has user-triggered handler; `convert_actions.dart` normalizes number; list tests verify URI/invalid disablement. | Current deliberate tap behavior covered locally; referral contact UX belongs to Plan 3 task 3. | Never auto-open or prefill religious/conversion data; tap is required. |
| Shared hosting/cloud responsibility and future command boundaries. | `docs/operations/unified-responsibility.md` and current Free operations docs. | Covered as operational documentation; actual host/provider checks remain release-only. | Any adopted VM/function changes applicability; until then VM/serverless triad remains not applicable. |

No finding in this documentary pass justifies a production code change. Future integration tasks above include concrete file owners and assertions; do not treat documentation gaps as proof of broken convert behavior.

## Reported verification evidence

| Layer | Recorded outcome | Source and limit |
|---|---|---|
| Flutter | `flutter test`: 240 passed, 0 failed. | `docs/verification/final-report.md`; prior Task 19 run. |
| Database | Native PostgreSQL 17.11 loopback: all 13 scenarios pass, including independent-session race orders. | Final report; synthetic fixture executes exact migration files with local Auth/Storage contracts. `supabase test db` was unavailable without CLI/Docker. |
| Static analysis | `flutter analyze`: no issues. | Final report. |
| Web | `flutter build web` and web preflight passed; 42 files, route proxy artifact. | Final report; build/preflight are not hosted route/OAuth checks. |
| Android | `flutter build apk --debug` passed. | Final report; debug-signed packaging only, not signed distribution/install/device QA. |
| Source parity | 101/101 Base44 manifest hashes unchanged. | Final report. |
| Live and physical checks | Not run. | Google OAuth provider, real Storage HTTP, hosted refresh/callback and device installation/pickers/export remain release-only prerequisites. |

## Handoff boundary validation

For the future command, Entry validation must reject unauthenticated actors, malformed UUID/envelope, missing congregation assignment, invalid/inaccessible convert, revoked grant and invalid selected student. Process must enforce actor/record scope, documented lock order, unique `convert_id`, payload-bound idempotency receipt and explicit candidate selection. Exit must return minimal IDs/status only, preserve retry ID on recoverable loss, leave no partial state on failure and expose no full conversion history to ministry-only scope. This validation plan is assigned to Plan 3 task 2 and the contract/sequence to Plan 3 task 1; it is not evidence that a command is already implemented.
