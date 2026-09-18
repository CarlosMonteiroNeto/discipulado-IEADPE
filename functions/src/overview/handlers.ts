/**
 * Callable wrappers for overview reads (S11).
 *
 * Thin transport layer: it extracts the authenticated UID and forwards the
 * payload to the injectable service. Scope authorization and query validation
 * stay in `service.ts`.
 */
import { defineCallable } from "../core/callable";
import { Clock } from "../core/clock";
import { Datastore } from "../core/datastore";
import { AppError } from "../core/errors";
import {
  GetOverviewInput,
  ListPendingSessionsInput,
  OverviewQueryReader,
  getOverview,
  listPendingSessions,
} from "./service";

export interface OverviewHandlerDependencies {
  datastore: Datastore;
  clock: Clock;
  reader: OverviewQueryReader;
}

function requireUid(request: unknown): string {
  const uid = (request as { auth?: { uid?: unknown } } | null)?.auth?.uid;
  if (typeof uid !== "string" || uid.length === 0) {
    throw new AppError("unauthenticated", "Authentication is required.");
  }
  return uid;
}

function payloadOf(data: unknown): Record<string, unknown> {
  if (data === null || typeof data !== "object" || Array.isArray(data)) {
    return {};
  }
  return data as Record<string, unknown>;
}

/**
 * Drops any caller-supplied `uid` so the service only ever sees the
 * authenticated identity from `request.auth.uid` (S04). A forged payload UID
 * can never expand or change the caller's scope.
 */
function payloadWithoutUid(data: unknown): Record<string, unknown> {
  const payload = payloadOf(data);
  delete payload.uid;
  return payload;
}

export function getOverviewCallable(deps: OverviewHandlerDependencies) {
  return defineCallable(async (data, request) =>
    getOverview(deps.datastore, deps.reader, deps.clock, {
      ...payloadWithoutUid(data),
      uid: requireUid(request),
    } as unknown as GetOverviewInput),
  );
}

export function listPendingSessionsCallable(deps: OverviewHandlerDependencies) {
  return defineCallable(async (data, request) =>
    listPendingSessions(deps.datastore, deps.reader, deps.clock, {
      ...payloadWithoutUid(data),
      uid: requireUid(request),
    } as unknown as ListPendingSessionsInput),
  );
}
