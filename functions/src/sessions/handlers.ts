/**
 * Callable wrappers for session operations (S11).
 *
 * Thin transport layer: it extracts the authenticated UID and forwards the
 * payload to the injectable service. Scope authorization, validation and
 * transactional writes stay in the service.
 */
import { defineCallable } from "../core/callable";
import { Clock } from "../core/clock";
import { Datastore } from "../core/datastore";
import { AppError } from "../core/errors";
import {
  CancelSessionInput,
  CreateSessionInput,
  cancelSession,
  createSession,
} from "./service";

export interface SessionHandlerDependencies {
  datastore: Datastore;
  clock: Clock;
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

export function createSessionCallable(deps: SessionHandlerDependencies) {
  return defineCallable(async (data, request) =>
    createSession(deps.datastore, deps.clock, {
      ...payloadOf(data),
      uid: requireUid(request),
    } as unknown as CreateSessionInput),
  );
}

export function cancelSessionCallable(deps: SessionHandlerDependencies) {
  return defineCallable(async (data, request) =>
    cancelSession(deps.datastore, deps.clock, {
      ...payloadOf(data),
      uid: requireUid(request),
    } as unknown as CancelSessionInput),
  );
}
