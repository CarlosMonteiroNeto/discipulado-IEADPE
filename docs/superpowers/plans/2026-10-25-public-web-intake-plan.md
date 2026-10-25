# Public Web Intake Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Offer free-tier anonymous convert intake with scoped approval, retaining immediate authorized registration and adding camera/gallery square profile photos.

**Architecture:** Anonymous traffic uses a dedicated Edge Function and private pending tables; official records are created only by authenticated scoped commands. Flutter composes public intake and protected review repositories beside existing feature owners. Reuse image_picker, private Storage, unified person creation and existing deployment conventions.

**Tech Stack:** Flutter/Dart, PostgreSQL/Supabase Auth/Storage/Edge Functions (Deno TypeScript), Cloudflare Turnstile Free, existing static host (Cloudflare Pages convention).

**Spec:** `docs/superpowers/specs/2026-10-25-public-web-intake-design.md` (user approved 2026-10-25).

## Global Constraints

- Start from fetched `origin/main`, investigated at `846a320619d3d8240df391a8b218c713bcceedc3`; do not implement in the old `flutter-supabase` checkout. Carry this Spec and plan into the execution checkout first.
- Investigation precedes every change; classify and investigate every failing check before fixing or accepting it. Preserve unrelated changes. Read repository instructions and `C:/Users/Carlos_Neto/.codex/RTK.md` when available.
- User selected later implementation by a smaller model through SDD; this document does not start implementation. Controller selects a currently available smaller model; do not copy stale model names from historical plans.
- UI stays pt-BR; engineering documents are English. Reuse the established field masks, dates, canonical values, style and domain failures.
- Anonymous visitors can submit for any active congregation, without photos or protected reads. Logged-in accounts without matching authority also require approval. Existing scoped/global authority bypasses approval only inside its scope.
- Free services only, no Redis, new paid plan, SMS/email service, domain purchase, automatic billing, or new camera framework.
- Intake: maximum 16 KiB request body; 20 accepted pending submissions/network/rolling hour, 200/network/rolling day, 1,000 active pending globally; operator configurable.
- Pending expiry: 30 days. Erase rejected payloads immediately and approved payloads after promotion. Minimal decision metadata: 90 days. No PII in logs, receipts or rate counters.
- Photos: exactly 512x512 JPEG; target roughly 100 KiB, maximum 200 KiB; inputs at most 20 MiB/24MP. Preserve 192px legacy images and the existing 1 MiB Storage compatibility ceiling.
- SQL migrations are additive and later than `202610250001_storage_content_length_policy.sql`; never edit deployed migration history. New filenames below are reserved for this plan; recheck collisions before execution.
- Service credentials and Turnstile secrets stay server-only. No anonymous grants on official records, queue tables, private Storage or privileged intake RPC.
- Tests use owned disposable loopback services/synthetic data. Hosted changes and publication are final operator-authorized work, not implied by planning approval.

## Review Focus

1. A Google account with no grant calls official creation directly: server must deny it (T1).
2. Server committed but browser lost response; retry with a fresh bot token must not duplicate or consume another queue slot (T2/T3/T4).
3. Shared church Wi-Fi submits concurrently at limit boundaries; exact accepted count and useful retry response (T2/T8).
4. A congregation is archived or a grant revoked while review is open; approval must fail without partial official writes (T5/T6).
5. Camera is canceled/denied or session changes while cropping; preserve form/old photo and never upload stale work (T7/T8).

## File ownership and dependency map

| Task | New owner files | Existing owners changed | Depends on |
|---|---|---|---|
| T1 Direct-create security | migration `202610250002_public_registration_authority.sql` | SQL harness scenarios | baseline |
| T2 Pending SQL | migration `202610250003_public_intake.sql` | SQL harness concurrency hook | T1 |
| T3 Public function | `supabase/functions/public-intake/{index,handler,contracts}.ts` | `supabase/config.toml` | T2 |
| T4 Public app | `lib/features/intake/{intake_models,public_intake_repository,public_registration_page}.dart`, `turnstile_challenge*.dart` | app/router/shell/form | T3 |
| T5 Approval SQL | migration `202610250004_pending_review.sql` | SQL scenarios | T2 |
| T6 Review app | `lib/features/intake/{pending_submission_repository,pending_review_page}.dart` | app/router/shell/static route list | T4,T5 |
| T7 Photos | `lib/features/photos/{photo_crop,photo_crop_page,photo_picker}.dart` | processor/form/save/controller/card/app picker injection | T1 |
| T8 Journey checks | `integration_test/public_intake_journey_test.dart` | gate scripts/manifests and existing regressions as needed | T4,T6,T7 |
| T9 Free release runbook | `docs/operations/public-intake.md` | deployment/auth/backup instructions and preflight | T8 |

All paths are repository-relative. Task sections below are the implementer briefs: hand a worker the selected complete section, this header/global constraints/contracts, the Spec and dependency receipts. No need to re-explore all historical plans. New source files must stay focused; do not restructure the whole app.

## Shared contracts (locked between tasks)

**Official draft:** current `ConvertDraft.payload()` produces `{congregation_id,person,convert}`. Public serialization uses the same field types but omits `convert.photo_asset_id`; neither an ID nor bytes may be supplied. Server injects null when forwarding approved data to the canonical create function. Preserve validated canonical phone/date/address behavior.

**Function:** `POST /functions/v1/public-intake`, JSON `{submission_id: UUID, turnstile_token: string, draft: OfficialDraftWithoutPhoto}`. Success HTTP 202 `{status:'received'}` for both first acceptance and same-payload retry; no queue/person IDs. Errors `{error: 'validation'|'conflict'|'rate_limited'|'unavailable'|'bot_check_failed'}` with HTTP 400/409/429/503/400. A rate-limited response includes integer `Retry-After` seconds, never other submitters' data. OPTIONS handles only configured allowed origins; disallowed Origin fails before provider/database calls. Origin is browser policy, not authentication.

**Catalog:** `public.ieadpe_public_congregations(request jsonb) -> jsonb`, request `{limit: 1..100, cursor: UUID|null}`, response `{items:[{id:UUID,name:string}],next_cursor:UUID|null}` ordered by UUID. Grant execute to anon/authenticated, no table grants. Catalog pagination is public names/IDs only; no counts/contacts/addresses. Reuse current client-side name ordering after fetching bounded pages for a form session; stop repeated cursors/duplicates as invalid responses.

**Intake SQL:** `public.ieadpe_receive_public_intake(request jsonb) -> jsonb`, fixed server-only request `{submission_id:UUID,network_hash:string,draft:OfficialDraftWithoutPhoto}`; response `{status:'received'}`. Use private typed failure internally mapped by T3; never accept a client timestamp, rate value or arbitrary actor. Grant only server role, not PUBLIC/anon/authenticated. Idempotency retained at least 30 days without PII; key binds canonical draft digest. Source key does not prove identity.

**Review SQL:** public authenticated RPCs `ieadpe_list_pending_intake(request jsonb)`, `ieadpe_get_pending_intake(request jsonb)`, `ieadpe_review_pending_intake(operation_id uuid,payload jsonb)`. List request `{congregation_id:UUID|null,limit:1..100,cursor:opaque|null}`; response `{items:[PendingSummary],next_cursor:string|null}`. Summary `{id,congregation_id,congregation_name,submitted_at,expires_at,name,revision}`. Detail adds `{draft}`. Ordering `(submitted_at,id)` oldest first; cursor binds selected congregation/current caller. Global null scope lists all; ordinary reviewers specify an allowed congregation.

Review payload `{id:UUID,expected_revision:int,decision:'approve'|'reject',draft?:OfficialDraftWithoutPhoto}`; draft required only for approval and cannot change congregation. Response `{id,status:'approved'|'rejected',official_convert_id:UUID|null}`. Use current safe typed failure mapping; preserve existing official-create result contract. Recheck permission even on replay. Same operation/same payload yields same result; conflicting reuse fails. Another approval operation on an already approved item returns the existing authorized result only if it is not attempting a different corrected draft; never overwrites a decision. Store corrected-draft digest with decision metadata to enforce this rule.

**Dart:** `PublicIntakeDraft.fromConvertDraft(ConvertDraft)` rejects photos; immutable `PublicCongregation(id,name)`, `PendingSummary`, `PendingDetail`, `ReviewDecision`, `ReviewResult`. `PublicIntakeRepository.listCongregations({String? cursor,int limit=100}) -> Future<Page<PublicCongregation>>`; `submit({required String submissionId,required PublicIntakeDraft draft,required String turnstileToken}) -> Future<void>`. Repository uses a narrowly scoped HTTP client, not authenticated `Gateway` or caches. `PendingSubmissionRepository.list({required String? congregationId,String? cursor,int limit=50}) -> Future<Page<PendingSummary>>`, `get(String id) -> Future<PendingDetail>`, `review({required String operationId,required String id,required int expectedRevision,required ReviewDecision decision,PublicIntakeDraft? draft}) -> Future<ReviewResult>` uses the existing protected gateway/context boundary. If `Page<T>` cannot carry the catalog's validated cursor without change, use a feature-local equivalent; do not alter global pagination semantics.

**Photo:** immutable `NormalizedPhotoCrop(left,top,size)` with `left=x/orientedWidth`, `top=y/orientedHeight`, and `size=squareSide/min(orientedWidth,orientedHeight)`; all are finite doubles, left/top >=0, 0<size<=1. Validate `x+squareSide<=width` and `y+squareSide<=height` after orientation, with deterministic pixel rounding. `Future<Uint8List?> pickProfilePhoto(ImageSource source)` handles acquisition/input bounds. `Future<NormalizedPhotoCrop?> showPhotoCrop(BuildContext context,Uint8List source)` provides cancel/confirm. `Future<Uint8List> processPhoto(Uint8List bytes,{NormalizedPhotoCrop? crop})` preserves center-crop default for existing callers; new UI passes its confirmed crop. Keep a wrapper/closure for `PhotoRepository.processor` rather than breaking its existing positional injectable signature. Crop coordinates are applied once, before encoding, not once to a thumbnail and again during upload.

## Execution discipline for every task

Begin with current instructions/branch/files/history and narrow reproduction; write a short evidence note naming cause/extension point. Use Entry -> Process -> Exit pseudocode (3–6 lines) before coding. Locals initialized, bounded input, pure transforms and explicit state lifetimes; no recursion or mutable globals. Start with one meaningful failing FIRST assertion, confirm the expected failure, implement minimally, refactor, and rerun. A disposable reverse-patch/revert check on the changed behavior should show the regression test fails when the behavior is removed; never revert unrelated user changes. Keep evidence to command/result/root-cause notes, not huge logs.

### T1 — Enforce authority for immediate official registration

**Files:** create `supabase/migrations/202610250002_public_registration_authority.sql`, `supabase/tests/database/public_registration_authority_test.sql`; modify existing fixture expectations only where unrestricted authenticated create was intentional old behavior. Inspect `202610190002_ministry_student_registration.sql`, `202610180003_base44_unified_access.sql`, latest access helpers and photo-draft creation before edits.

**Consumes:** existing `private.convert_registration_command`, `public.ieadpe_create_convert`, congregation grants/global-manager predicates. **Produces:** same official RPC signature/result, but create requires active scoped/global permission; no change to edit/read or canonical unified-person logic. Photo draft/create/upload must independently require authorized profile scope; do not rely on UI hiding.

- [ ] Write `official_create_requires_matching_grant`: anonymous/no-grant/cross-congregation actors are denied with unchanged person/convert/weekly counts; own-congregation/global creation succeeds and retains exact unified return fields. Add no-grant photo-draft/upload denial.
- [ ] Run `python scripts/test_database.py public_registration_authority_test.sql`; confirm RED occurs because current authenticated no-grant official creation succeeds, not from missing services/fixtures.
- [ ] Add migration replacing the latest create guard with canonical scoped/global predicate and active congregation check, preserving lock order and replay permission checks; tighten photo grants/ownership where evidence shows a bypass.
- [ ] Rerun the scenario and affected existing registration/photo SQL tests; expected exit 0, no unauthorized writes. Classify and update stale registrar tests with this approved policy as evidence.
- [ ] Commit only T1 files: `fix: require scoped authority for official registration`.

### T2 — Private pending intake, catalog and atomic limits

**Files:** create `supabase/migrations/202610250003_public_intake.sql`, `supabase/tests/database/public_intake_test.sql`, `scripts/database_public_intake_concurrency.py`; extend `scripts/test_database.py` with `--public-intake-concurrency`. No public UI yet.

**Consumes:** T1 constraints and shared intake/catalog contracts. **Produces:** pending table, separate decision metadata, expiring digest receipts, accepted-event network hashes, private operator settings (`enabled`, limits, retention) and shared RPCs. Use advisory/global capacity lock plus stable key/network locks, unique submission ID, and server `now()` for exact rolling windows. Count accepted submissions, not retries or failed bot attempts. A 60-minute bucket is not a rolling hour.

- [ ] Write `catalog_is_names_only` and `pending_intake_is_private`; assert exact keys, active-only pagination, no direct anon/authenticated queue access, reject unknown/photo fields and invalid canonical draft fields.
- [ ] Write boundaries: accept 20 then reject 21 in one hour; rolling hour at -1/0/+1 second; daily 199/200/201; global 999/1000/1001; zero/negative configured limits rejected. Same key/payload replay creates one item; changed payload conflicts; pause rejects; 30-day expiry stops action/capacity counting.
- [ ] Run `python scripts/test_database.py public_intake_test.sql`; confirm missing-feature RED at the new assertions after valid harness setup.
- [ ] Implement SQL and bounded opportunistic cleanup. Use canonical field validation through a private shared validator extracted without behavior change if necessary; no fake authenticated identity or direct official inserts. Erase rejected/approved payloads in T5, retain digest-only receipts for retry safety. Document that SHA digests are server-private metadata, not anonymized public data.
- [ ] Implement concurrency entrypoint `check_public_intake_concurrency(database_url: str) -> None` following existing scripts: race last global slot, 21 same-network inserts and identical key retries; assert exact row totals and no overshoot. Test with server-controlled fixture clock/fixtures, no real sleeps.
- [ ] Run `python scripts/test_database.py public_intake_test.sql --public-intake-concurrency`; expected all assertions pass, exit 0. Commit `feat: add private public-intake queue and limits`.

### T3 — Free bot-validated submission function

**Files:** create `supabase/functions/public-intake/{index.ts,handler.ts,contracts.ts,handler_test.ts}`; modify `supabase/config.toml` for this function only. Keep dependencies to Deno/Web APIs and existing Supabase REST endpoints, no Redis SDK.

**Consumes:** T2 intake RPC/catalog. **Produces:** public POST endpoint with shared wire contract. Handler factory `createIntakeHandler(deps: IntakeDependencies): (request: Request) => Promise<Response>` injects fetch/token verifier, RPC caller, HMAC and trusted-address resolver for tests; `index.ts` binds env/runtime only.

- [ ] Test `invalid_bot_never_reaches_database`, `payload_limit_rejects_before_decode`, `origin_is_not_identity`, `lost_response_retry_uses_same_key`, `trusted_ip_cannot_be_spoofed`. Include 16KiB±1, malformed JSON/unknown keys, wrong hostname/action, expired/replayed/missing token, token-provider timeout, SQL 429 and safe error mapping; assert zero secret/body logging and correct OPTIONS behavior.
- [ ] Run `deno test --allow-env supabase/functions/public-intake/handler_test.ts`; expect the new behavior assertion to fail before implementation; environment/command absence is a prerequisite issue to resolve, never RED evidence.
- [ ] Implement mandatory server Siteverify, exact hostname/action `public_intake`, bounded provider/DB timeouts, no permissive success fallback, 16KiB streamed-body cap (not Content-Length alone), HMAC-SHA256 network identifier and fixed RPC request. Require `SUPABASE_URL`, server credential, `TURNSTILE_SECRET_KEY`, `INTAKE_NETWORK_HASH_SECRET`, `INTAKE_ALLOWED_ORIGINS` and `INTAKE_ALLOWED_HOSTNAMES`; secrets fail closed when missing. Public site key is separate build config.
- [ ] Verify authoritative hosted client-address semantics against current provider documentation before activating the network limiter. Record header trust chain/evidence in operations notes. Do not parse arbitrary leftmost X-Forwarded-For as a proven client. If unresolved, mark limiter/release BLOCKED and continue independent tasks; no unapproved proxy infrastructure.
- [ ] Run `deno check supabase/functions/public-intake/index.ts` and the Deno tests; expected exit 0. Commit `feat: validate anonymous intake before persistence`.

### T4 — Public registration and login-on-demand

**Files:** create feature-local models/repository/page and `turnstile_challenge.dart`, `turnstile_challenge_web.dart`, `turnstile_challenge_stub.dart` under `lib/features/intake/`; tests `test/features/intake/{public_intake_repository_test,public_registration_page_test}.dart`. Modify `lib/app.dart`, `lib/routing/router.dart`, `lib/widgets/app_shell.dart`, `lib/features/converts/convert_form.dart`; preserve existing picker APIs until T7.

**Consumes:** T3 wire endpoint/T2 catalog and existing `ConvertDraft`. **Produces:** public `/` and `/register`, Google login on other destinations, typed public repository and form policy. Add explicit `allowPhotos`/required-congregation policy to shared form with secure caller values; no auth gateway on public form. Turnstile abstraction `Future<String> acquireToken()` / `void reset()` / `void dispose()` is page-owned, web implementation uses supported platform view/JS interop; non-web stub reports unsupported rather than silently omitting bot protection.

- [ ] Test `anonymous_register_does_not_initialize_protected_reads`: opening `/` or `/register` renders form, zero official/home/photo reads, only names/IDs fetched; selecting another route invokes login then normal authorization. Anonymous/no-grant photo controls absent, server remains T1 authority.
- [ ] Test canonical draft/required congregation, inline blur/submit errors, first-invalid focus, denied response preserving input, and double click producing one in-flight request. Test request timeout after server acceptance freezes payload/key for retry; edits are enabled only after definitive validation rejection or success. Retry acquires a new token but keeps key. This avoids submitting edited data under a committed unknown outcome.
- [ ] Run `flutter test test/features/intake/public_intake_repository_test.dart test/features/intake/public_registration_page_test.dart`; confirm narrow RED; implement feature and router integration. Catalog loads bounded pages once per form session, detects cursor loops/duplicates; exact response-key validation prevents accidental private projection acceptance.
- [ ] Keep authorized own-scope registration on the existing official save controller; out-of-scope/no-grant uses pending path without photo. Revalidate selected scope before allowing photo acquisition; authority change clears protected photo state. Sign-out returns to registration and invalidates protected subtree/caches; do not keep old PII across account switches.
- [ ] Run those tests plus `flutter test test/features/auth test/widgets/unified_navigation_test.dart test/features/converts/form_test.dart`; expect pass. Commit `feat: open public registration with protected navigation`.

### T5 — Scoped approval and rejection transaction

**Files:** create `supabase/migrations/202610250004_pending_review.sql`, `supabase/tests/database/pending_review_test.sql`; extend `scripts/database_public_intake_concurrency.py` and the existing T2 hook.

**Consumes:** T2 pending state, T1 canonical official RPC, shared review contracts. **Produces:** three authenticated RPCs, active scope checks, revision/decision metadata and one official convert/person pair per approved submission. Use existing actor access lock first, pending row lock and canonical create lock order; test contention against grant revocation and normal registration.

- [ ] Write `approval_is_scoped_atomic_and_once`: anon/no-grant/other congregation denied; local/global permitted; pending absent from official reports; corrected approval calls canonical `ieadpe_create_convert` with reviewer `auth.uid()`, fixed derived operation UUID and null photo, then clears pending payload and records result atomically.
- [ ] Add two-reviewer race, conflicting corrected draft, reject/approve race, expired item, stale revision, archived congregation, revoke-while-open, injected canonical-create failure and same-operation replay after lost response. Assert official person/link/weekly counts and zero partial writes. Decision payload/receipts must not retain PII.
- [ ] Run `python scripts/test_database.py pending_review_test.sql`; confirm new-assertion RED; implement contracts including cursor scope binding and exact allowlists. Do not widen official-create permissions to make approval work.
- [ ] Run `python scripts/test_database.py pending_review_test.sql --public-intake-concurrency`; expected one official result under concurrent approval, all assertions pass. Include existing canonical registration/follow-up SQL regression.
- [ ] Commit `feat: approve anonymous submissions within congregation scope`.

### T6 — Reviewer queue and editable approval form

**Files:** create review repository/page and `test/features/intake/{pending_submission_repository_test,pending_review_page_test}.dart`; modify app/router/shell, `web/_redirects`, `scripts/web_preflight.py` and corresponding `scripts/test_release_operations.py` route fixtures together.

**Consumes:** T5 RPCs, T4 feature models/form. **Produces:** protected `/pending` route labeled `Pendentes` for existing campaign reviewers/global managers only; page-owned protected repository. UI filters local users to allowed congregations and global managers to all/selected; fetched scope remains authoritative. Review displays pending count and expiry, list page size 50, details + editable form, approve/reject, no bulk action.

- [ ] Test `review_never_exposes_other_scope`: forged route/filter, malformed cursor and revoked session cannot show stale details; no-grant menu and direct route blocked; canonical corrected approval and rejection use stable operation IDs, expected revision and unchanged congregation.
- [ ] Test success removes item, retry after unknown outcome keeps immutable decision/draft/key, definitive error permits correction, cancel preserves pending server data, empty/loading/error states and double clicks. Reviewers can use existing scoped official search separately; no new name-only merge.
- [ ] Run `flutter test test/features/intake/pending_submission_repository_test.dart test/features/intake/pending_review_page_test.dart`; confirm RED, implement, then rerun plus navigation/form regressions and `python scripts/test_release_operations.py` (expected pass). Test new `/pending` exact proxy; never broaden to wildcard asset rewrite.
- [ ] Commit `feat: add protected pending-registration review`.

### T7 — Standardized camera/gallery profile photos

**Files:** create photo crop/model/page/picker owners and `test/features/photos/{photo_crop_test,photo_crop_page_test,photo_picker_test}.dart`; modify `photo_processor.dart`, `photo_repository.dart` only as needed for processor closure, existing form/picker injection in `lib/app.dart` and register/save owners, `convert_card.dart` only if enlargement needs adjustment; extend `photo_test.dart`, `photo_repository_test.dart`, `test/features/converts/photo_save_test.dart`.

**Consumes:** shared photo contract, existing private pipeline and T1 permissions. **Produces:** camera/gallery chooser, confirmed crop coordinates, 512px metadata-free bounded JPEG; existing full-image display remains private. Use existing image_picker; no new camera framework. Native selection should recover/explicitly handle picker lost-data behavior if required by current Android plugin, without making an Android release a dependency for Web.

- [ ] Write `confirmed_crop_is_applied_once`: landscape/portrait/orientation6/transparency fixtures yield 512x512 JPEG, correct selected face-region pixels, no metadata, <=204800 bytes. Test centered default compatibility; tiny/corrupt/empty/oversize input; 20MiB/24MP edges and crop bounds/aspect including non-square source. Encoder uses bounded quality attempts targeting 102400 bytes; minimum quality 55, reject recoverably if still >204800. Do not upscale/downscale again after user-selected crop.
- [ ] Run `flutter test test/features/photos/photo_crop_test.dart test/features/photos/photo_test.dart`; confirm 192-vs-512/missing-crop assertion RED. Implement pure geometry and processing before UI. The output coordinate contract describes the oriented source; make orientation order explicit in both tests and UI.
- [ ] Write camera/gallery/cancel/denial/stale-session tests and crop page tests: drag uses original grab offset, zoom preserves framing, confirm/cancel/reset, keyboard zoom/position alternatives, 360px/200% text and reduced motion. No photo selection or upload when authority is missing; dismiss during logout without publishing bytes. Use disposable preview as layout reference only.
- [ ] Implement `pickProfilePhoto`, `showPhotoCrop`, processor closure and form integration. Preserve original bytes in memory until confirm, upload only the processed JPEG. Clear temporary bytes on cancel/dispose/scope loss. Keep current old-photo preview until replacement has succeeded; label image actions distinctly in pt-BR.
- [ ] Run `flutter test test/features/photos test/features/converts/photo_save_test.dart test/features/converts/stale_save_test.dart`; expected pass. Verify 192px legacy download still accepted; no tightening of Storage incompatible with existing objects. Commit `feat: capture and frame standardized profile photos`.

### T8 — Integrated verification and usability evidence

**Files:** create `integration_test/public_intake_journey_test.dart`, `docs/verification/public-intake-acceptance.md`; extend existing journey runner/verification manifest and `scripts/verify_unified.ps1` / `.sh` only where needed to include the new scenarios. Add/update local guard tests if the runner changes; do not create another competing gate system.

**Consumes:** T1–T7. **Produces:** source-bound pass/fail/blocked evidence, synthetic anonymous-to-approved journey and scoped security regression. Preserve existing localhost-only guards. Bot verifier is injected with deterministic test doubles locally; real Turnstile validation remains a separate hosted smoke.

- [ ] Add journey assertions: anonymous submit -> absent from official lists/reports -> wrong reviewer denied -> correct reviewer edits/approves -> exactly one unified official record -> sign-out no protected data; authorized direct create immediate; unsigned upload/direct RPC bypass denied. Include shared-network limit boundary and lost-response replay.
- [ ] Run focused local journey using the existing runner invocation inspected at execution time; expected RED only for missing integrated behavior, then fix in owning task scope and run green. Do not fabricate runner flags; record the actual inspected command in the evidence file.
- [ ] Run pinned `flutter analyze --no-pub`, `flutter test --no-pub --concurrency=1`, both new SQL scenarios/concurrency, Deno check/test and affected Python gate/route tests. Current inherited SDK evidence pins Flutter 3.47.7/Dart 3.13.5; verify current CI/toolchain before use. Known old 572/572 is historical evidence, not this increment's result.
- [ ] Audit new form/review/crop with a navigation/legibility/feedback findings table: blocking/follow-up/out-of-scope + reason/owner. Verify labels/errors/required cues, logical focus/48dp targets, 360/768/1440 and 200% text, screen-reader status, reduced motion/contrast. Observe one public completion and one reviewer completion; record success/time/error/brief impression without analytics. Automated checks supplement, never claim real disability-user testing when unavailable.
- [ ] Record test design: equivalence partitions (valid/two invalid per bounded input), exact boundaries and representative control-flow base paths for intake/review/crop loops; retain RED/green receipt and one safe behavior-removal check per security boundary. Planning/design/execution/delivery effort uses 10/40/45/5 as guidance, not runtime quota. Camera/browser-device evidence is carried to T9 if hosted prerequisites are missing.
- [ ] Commit `test: verify public intake and approval boundaries` after narrow/broad checks have passed or exact external blockers are recorded. Critical security failures block release; don't mark incomplete checks green.

### T9 — Free-tier operations and release handoff

**Files:** create `docs/operations/public-intake.md`; update applicable existing release/auth/backup docs, acceptance report and static preflight only if changed contracts require it. No new paid hosting or IaC platform.

**Consumes:** verified candidate, T3 trusted-address decision and all previous receipts. **Produces:** versioned deployment/configuration checklist, quota/pause/retention/backup/restore/rollback instructions, actual operator dependencies and reviewed candidate manifest. Source of truth: this plan and approved Spec; add links to new work without promoting old closed plans.

- [ ] Document service map: no VM; existing static host; Supabase database/Auth/private Storage/Edge; Turnstile. Specify developer vs provider responsibilities for IAM/secrets/HTTPS/at-rest encryption, quota monitoring/patching, account recovery, no free SLA/geo-DR promise. Inventory actual existing deployment before deciding new setup is needed.
- [ ] Document public build defines `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `AUTH_CALLBACK_URL`, new `TURNSTILE_SITE_KEY`; private function values from T3 never enter bundle. Include exact allowed hostnames/origins/callback, `verify_jwt=false` for public-intake only, server RPC grants, settings pause/unpause and bounded cleanup command. No raw service secrets in terminal evidence. No automatic billing.
- [ ] Rehearse versioned migrations and queue retention/backup restore in disposable local database. Verify expired/rejected/approved payload removal and official record persistence; restore private intake tables/decisions/receipts consistently or document rebuild without duplicating official approvals. Re-run local artifact-route test and `python scripts/web_preflight.py build/web` after a configured `flutter build web --release --dart-define-from-file=<operator-public-defines.json>`; placeholders must be replaced by an operator-owned file, not copied literally.
- [ ] Produce concrete publication proposal: candidate commit/hash, existing/proposed free hostname, migrations/function/config changes, synthetic test cleanup, rollback and verification checklist. Stop hosted mutations/publication until separately authorized; do all local reviewable work first. Rollback disables public intake, keeps pending/official data, and deploys compatible prior app; never drop approved data or blindly reverse migrations.
- [ ] After that authorization, publish only reviewed artifact and run actual HTTPS direct-route/reload/assets/OAuth/Turnstile/anonymous submission/reviewer approval/security denial/photo lifecycle checks. Use synthetic records with exact cleanup; test camera + gallery on mobile Chrome and iOS Safari when available, denial/cancel/rotation/large-photo/enlargement. Record unsupported/unavailable devices as incomplete, not simulated passes. No Android APK/signing is required by this Web launch.
- [ ] Record actual free-tier utilization and retained limitations. Commit docs/evidence `docs: record public web intake release readiness`; never claim published until URL and end-to-end checks are confirmed.

## Skill requirement coverage and release gates

| Overlay | Spec evidence | Owning tasks / acceptance |
|---|---|---|
| cloud-deploy | Free hosting/services/operations | T3/T9: managed-vs-VM decision, service mapping, IAM, encryption, shared responsibility, quota, unavailable-service behavior, backups/restore/rollback, versioned migration/function/static configuration; free resilience limits stated |
| quality-gate | Definition of Done | T8/T9: SQA contract/review vs SQC executed checks, ISO25010 quality goals without certification claim, prevention/appraisal focus and static/dynamic GQM metrics |
| design-oo-ux | Structure/UML/UP and photo/UX sections | T4/T6/T7: composition/types, sequence diagram, conception approved; elaboration T1–T3 proof before UI, wireframe->working prototype->real device; pointer response/1:1/interruptibility/spring/momentum behavior and reduced motion; no custom decorative animations |
| verification-test | Done / form contract | T1–T8: test plan/scenarios, valid+invalid partitions/BVA/base paths, expected RED/green/revert checks, isolated services, automation/regression and actual device scope |
| coding-standards | Structure/coding brief | Every task evidence note: Entry/Process/Exit pseudocode, initialized locals/types, bounded input, pure transforms/state ownership, no recursive processing; T2/T3/T7 focus |
| a11y-ethics | UX / privacy | T4/T6/T7/T8: POUR, heuristic findings by severity, completion/time/error/impression, consent, no fingerprinting/personalization/auto-approval, accessible form contract; 48dp targets and real-test limitations |

Form applicability: required labels/masks/blur+submit/errors/canonical payloads apply; calendar mode inherits the existing product contract rather than adding typed fallback; legacy unchanged preservation applies to official edits/old photos, not new anonymous drafts. Whole-app redesign, personalization/gamification, formal ISO certification and Android release are outside the approved increment. No Scrum/ceremony overlay is needed.

Release gates: conception (approved Spec); elaboration (T1–T3 invariants and trusted address proven); product (T4–T8 pass, no critical permission/integrity defects); operations (T9 reviewed configuration, free quotas, restore/rollback and separate hosted authorization); final acceptance (actual source-bound hosted journey and listed phone evidence, with remaining limitations stated). Mark missing prerequisites BLOCKED, assertion failures FAIL, and genuine successful checks PASS.

## Self-review receipt

Plan checked against all Spec sections and loaded overlay checklists; each requirement maps above. Shared RPC/Dart/photo signatures are defined once; each owning task names files, dependencies, RED behavior, verification and commit. The five Review Focus cases have tests in their owners. No product code was written. Plan ready for user review; implementation is still deferred.
