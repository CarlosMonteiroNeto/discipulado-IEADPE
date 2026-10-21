# APK identity and access recovery — design draft

Status: bounded correction, pending user design review. Author: Sol 6.1 / low, using `brainstorming`. The user selected Luna/medium in coder role, delegating edits to OpenCode CLI, with this Sol/low reviewer. This draft preserves the current uncommitted L1 work.

## Intended result and evidence

The signed-in Google administrator should see an appropriate greeting, load authorized converts, and reach Team through Admin. Success requires a compatible server contract as well as the corrected APK; a new APK alone cannot establish hosted readiness.

Proven locally: `HomePage.name` defaults to `Visitante` (`lib/features/home/home_page.dart:17`) and `lib/app.dart:549` does not supply a name. This is greeting text, not an authorization role. `routesFor` permits `/admin` for a global manager but permits `/ministry/team` only with Ministry scope; `SessionRouter.go` sends a disallowed route to `/register`. The Admin Team button invokes that navigation unconditionally.

The current SQL contract makes `is_admin=true` imply `ministry_supervision=true`: migration `202610190003_ministry_team_access.sql` derives both from the global-manager predicates. The client currently accepts an inconsistent snapshot with admin true and Ministry false. Whether the APK actually received that snapshot is unproven. Convert reads now require `ieadpe_ministry_list_converts` (migration 002) and its strict projection, including effective follow-up fields from migration 008. Missing/older hosted functions, a different APK/backend, permission denial and malformed records remain hypotheses until observed.

## Proposed bounded design

1. Resolve the greeting from existing Google session metadata: first nonblank string `full_name`, then `name`, trimmed. Missing or malformed metadata renders `Olá!`; a name renders `Olá, <name>!`. Do not use email as an implicit public display name. Presentation metadata never changes authority.
2. Keep scope flags and SQL authority unchanged. Admin's Team entry receives `scope.hasMinistryAccess`. When false, keep the operator in Admin, show `O servidor não confirmou acesso à equipe. Atualize seu acesso para tentar novamente.` and an `Atualizar acesso` action using the existing scope-refresh callback. Do not call the router with a disallowed Team route or manufacture Ministry flags from admin/name/email.
3. Diagnose convert/backend compatibility before selecting a data fix. Preserve failures as failures; do not replace them with empty data, relax strict decoders, fall back to unrestricted table reads, or bypass RLS. A confirmed hosted mismatch requires a separate concrete alignment proposal before any hosted write.

The chosen approach is evidence-led UI correction plus contract diagnosis. A UI-only change cannot promise data recovery; inferring permissions in the client would hide the server discrepancy and still cannot authorize SQL reads.

## Read-only diagnostic boundary

Inspect function definitions/signatures/privileges through `pg_catalog`, column names/types, migration version inventory when its ledger exists, and non-identifying aggregate counts only when needed. Compare `ieadpe_get_scope`, `private.is_global_manager`, `private.ministry_supervisor`, convert list/get/projection and directory RPC definitions with the checked-out migrations. Record APK version/source and backend project identity without keys or tokens.

Do **not** call `ieadpe_get_scope()` as a read-only probe: it can bind `user_access.user_id` and update access versions. A scope snapshot may be observed from an already occurring real application request, with only booleans/list counts and error codes retained. Do not invoke mutations, apply migrations, import records, or expose personal rows/credentials. If no authorized diagnostic connection exists, record hosted state as unknown and continue the independent UI work.

## Acceptance and limits

Regressions cover named/missing/malformed metadata, valid admin+Ministry navigation, inconsistent admin-only scope without redirect or privilege escalation, ordinary registrar access remaining denied, and existing convert RPC envelope/error handling. Test the actual app wiring as well as the small display helper; preserve phone/200% text layout.

Build a local Android APK from the reviewed source with the existing approved configuration process; record source SHA plus working-tree changes, version and SHA-256. Never embed service credentials. Real Google-admin verification must confirm the intended backend, greeting, convert read result and Team entry. Until that and the hosted contract gate succeed, label the APK a local candidate and retain the existing L1 release blockers. No publish, signing-policy change or hosted rollout is included.

Self-review: no product-policy or permission expansion; source facts and hosted hypotheses are separated; the independent UI change is executable while diagnostic access is unavailable. The remaining decision is user review of this bounded design.


## 2026-10-20 ownership clarification

This bounded draft remains historical diagnosis and a valid reference for the greeting/Team contract. Its implementation is owned by Task 8 of the in-flight [corrective plan](../plans/2026-10-20-ministry-corrective-release-plan.md); do not execute it as a parallel workstream or regenerate its completed code. The corrective plan's completion assessment and delivery addendum govern complete functional-APK work. Its former OpenCode method/build suggestion is superseded by the user's native Luna Medium implementer / Sol 6.1 low task-review method and explicit no-build-now instruction. No APK was produced by the interrupted debug build (exit 143); it was aborted, not a failed build/test.
