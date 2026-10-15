# Protected data gateway integration

Task 7 supplies injectable repositories; Task 19 mounts them with the application root.

```dart
final boundary = ProtectedDataBoundary();
final Gateway gateway = SupabaseGateway(auth.client, boundary);
final converts = ConvertRepository(gateway);
final accesses = AccessRepository(gateway);
final router = SessionRouter(
  auth,
  clearProtectedCaches: () {
    boundary.invalidate();
    // Synchronously clear every feature record, photo, page and pending UI owner.
    clearFeatureState();
  },
);
```

Use one boundary for all protected owners. `invalidate()` changes its generation synchronously. Each gateway attempt captures both generation and current SDK user ID, checks before sending, after receiving, after failure and before each retry. Changed context throws `DataFailure('stale')` for reads or returns a rejected mutation with `errorCode == 'stale'`. Requests already sent may finish on the server; invalidation suppresses their results and further retries, and does not undo a committed transaction. RLS and RPC authorization always remain authoritative.

Feature state owners must capture `gateway.context` before an async load and call `gateway.ensureCurrent(capturedContext)` immediately before publishing its results, including after any additional async processing. Clear collection state and discard its cursors on invalidation. Never persist records or photos. Task 19 must register *all* protected owners in the router's required callback; clearing only displayed collections is insufficient. No repository cache is introduced here.

## Reads and cursors

`ConvertRepository.list(ConvertQuery query, String? cursor)` returns `Future<Page<ConvertRecord>>`. `ConvertQuery` supports `congregationId` and literal case-insensitive name substring (`name`, default empty). SQL applies RLS first; the congregation filter only narrows server-authorized rows. Soft-deleted records are excluded. No client access snapshot grants permissions. Terminal records remain available for source Home totals; feature policy determines active displays.

`AccessRepository.list([String? cursor])` returns `Future<Page<UserAccess>>`. Access rows remain subject to server policies. `save(operationId, email: ..., role: ..., id: ..., congregationId: ...)` normalizes email and sends only editable access fields. `revoke(operationId, id)` sends only the ID. After a successful grant change, refresh the session guard and invalidate relevant feature state before loading current access.

Pages contain at most 100 rows ordered by ascending immutable UUID. Request each `nextCursor` until null. Exact multiples of 100 require a final empty request. The opaque versioned cursor binds its last ID to the query, identity and invalidation generation; malformed or mismatched cursors fail before network access. Repositories reject duplicate, backwards or oversized pages. UUID keyset traversal avoids offset shifting on deletion and handles 1,205 fixed permitted rows exactly once. This is not a database snapshot across concurrent inserts/edits; restart traversal for a fresh view. Feature display sorting and derived visit/status filtering must operate over the complete relevant traversal rather than assume a single page contains all rows.

## Commands and failures

`Gateway.command(String command, String operationId, Map<String,Object?> payload)` returns `Future<MutationResult<String>>`; applied `value` is the server's minimal UUID ID. The caller creates one UUID operation ID per logical action and retains it when offering a retry. Never serialize a read DTO as an edit request. Current supported commands match existing migrations: `create_convert`, `edit_convert`, `delete_convert`, `transition_convert`, `confirm_zero`, `save_access`, `revoke_access`. Other commands must be added alongside their server contracts. The gateway rejects non-editable keys; SQL validates values and invariants. Lifecycle payload is exactly `{id, action}` with SQL actions `visit`, `start`, `stop`, `complete`, `deviate`. Server actor/time/event/counter fields are never sent. Mutations snapshot the payload before the first request.

The installed SDK's built-in retries are disabled per request. The gateway makes at most three total attempts for timeouts, SQL serialization/deadlock (`40001`, `40P01`) and temporary HTTP gateway/service failures (`502`, `503`, `504`). Attempts use the same operation ID and payload, with short bounded backoff. Ordinary permission/validation/backend failures do not retry. Default timeout is 15 seconds per attempt. Failed mutations return rejected results; failed reads throw `DataFailure`. Local invalid inputs/unsupported commands fail before issuing requests. Failure codes contain no SQL/provider text:

| Code | Feature action |
| --- | --- |
| `stale` | Silently discard the obsolete completion; current guard owns navigation. |
| `permission` | Remove inaccessible state and refresh scope; show plain access guidance. |
| `invalid` | Show a plain validation message and allow correction. |
| `invalid_cursor` | Clear pages and restart the current query. |
| `invalid_response` | Show a recoverable failure and retry action; never fabricate rows or success. |
| `unavailable`, `backend` | Show a plain pt-BR retry state; preserve the logical operation ID for mutations. |

A successful empty `Page` is distinct from a failure. Never catch a read failure and turn it into an empty list. Raw backend exception details must not reach ordinary UI. No mock transport or network fallback exists in production.

## Evidence boundaries

Loopback HTTP fixtures use the actual locked Supabase/PostgREST SDK and verify RPC envelopes, ordering/filters, bounded pagination, timeout behavior, same-operation retry and invalidation. Native PostgreSQL fixtures verify server RLS and transactional behavior separately. Neither establishes live PostgREST/Auth service integration. Before release, verify against operator-provisioned services: actual RLS with registrar/direction/global accounts, grant loss and user switching during requests, duplicate mutation delivery after timeout, Google OAuth/browser/Android behavior and private Storage HTTP enforcement. No production or external-provider checks were run for Task 7.
