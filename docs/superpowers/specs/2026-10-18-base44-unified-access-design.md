# Base44 Unified Access Design

Date: 2026-10-18
Status: Design approved in conversation; awaiting written-spec review.

## Goal

Use the Base44 access assignments already activated in Supabase as the single authority for both the converts app and the discipleship-class module. A global administrator or supervision account can access all congregations. A congregation-assigned email can access discipleship students and related records only for its assigned congregation.

## Current behavior

The Base44 export contained 30 `UserAccess` records. They were activated in `public.user_access` as 28 congregation-scoped direction assignments and 2 global supervision assignments; the original import records remain in `private.base44_user_access_pending` for audit. The app's converts permissions read `public.user_access`, while ministry routes and database guards currently read `public.ministry_grants`. Thus an imported account can have valid app access without ministry access.

## Authorization rules

- `private.admin_allowlist` users have global ministry access, even without a `user_access` row.
- A user with the Base44 role `Membro da supervisão das campanhas` has global ministry access.
- A user with the Base44 role `Membro da direção da campanha` has ministry access only to the assigned `congregation_id`.
- `public.user_access` is the active permission source. The private pending import table is audit data and never grants access.
- `public.ministry_grants` is retained for compatibility and historical traceability but no longer grants or revokes effective ministry access.
- Existing email-to-Auth binding remains based on confirmed sign-in. Removing or changing an active `user_access` assignment must affect subsequent scope refreshes and server authorization checks.

## Design

Reuse the existing campaign authorization helpers `private.is_global_manager()` and `private.can_access_congregation(uuid)` as the authority for ministry access. Update the ministry helper functions to delegate to those helpers, keeping the existing ministry RPC and RLS policy call sites intact. This applies the same rule to reads, writes, attendance, class enrollment, session operations, handoff, and congregation directory RPCs rather than relying only on Flutter route visibility.

Update `public.ieadpe_get_scope()` so its ministry fields are derived from the same authority: global administrators and supervisors receive ministry-wide scope; congregation assignments populate the ministry congregation IDs. Preserve the response shape for the Flutter client during this migration. Routes and the section selector will then expose ministry pages to the same accounts without any separate ministry grant.

Keep the migration additive and non-destructive. Do not delete `ministry_grants` rows or the private Base44 audit rows. Do not copy ministry-only grants into `user_access`; access must correspond to the existing Base44 email, role, and congregation assignments requested by the user.

## Security and consistency

- Each helper must fail closed when there is no authenticated user or when a congregation ID is null.
- Global authority is limited to the technical admin allowlist and Base44 supervision role.
- A congregation assignment must not reveal another congregation's students, classes, sessions, roster, attendance, or handoff data.
- Existing server-side RLS and RPC authorization checks remain mandatory; Flutter scope only controls navigation and presentation.
- Removing an access assignment must remove its effective ministry scope on the next scope load without waiting for a ministry grant update.

## Verification

Database regression coverage must verify:

1. An admin-allowlisted account without `user_access` or `ministry_grants` receives global ministry scope and can pass ministry authorization for every congregation.
2. A Base44 supervision assignment receives global scope without `ministry_grants`.
3. A Base44 congregation assignment receives access only to that congregation, without `ministry_grants`.
4. A congregation account is denied access to another congregation through the helpers and representative ministry RPCs.
5. Revoking the active `user_access` row removes ministry access; stale active `ministry_grants` must not restore it.
6. Private pending Base44 import records do not grant access by themselves.
7. Existing converts scope, admin route access, and ministry route availability remain consistent with the server-derived scope.

No hosted permission migration is applied as part of the design or implementation-plan review. Applying the resulting SQL migration to the hosted Supabase project is a separate operational step after local verification.
