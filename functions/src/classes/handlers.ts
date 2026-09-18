/**
 * Callable wrappers for class operations (S11).
 *
 * Thin transport layer: it extracts the authenticated UID and forwards the
 * payload to the injectable service. Scope authorization, validation and
 * transactional writes stay in the service and session reader port.
 */
import { defineCallable } from "../core/callable";
import { Clock } from "../core/clock";
import { Datastore } from "../core/datastore";
import { AppError } from "../core/errors";
import {
  ClassSessionReader,
  SaveClassInput,
  SetClassStatusInput,
  saveClass,
  setClassStatus,
} from "./service";

export interface ClassHandlerDependencies {
  datastore: Datastore;
  clock: Clock;
  sessions: ClassSessionReader;
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

export function saveClassCallable(deps: ClassHandlerDependencies) {
  return defineCallable(async (data, request) =>
    saveClass(
      deps.datastore,
      deps.clock,
      {
        ...payloadOf(data),
        uid: requireUid(request),
      } as unknown as SaveClassInput,
      deps.sessions,
    ),
  );
}

export function setClassStatusCallable(deps: ClassHandlerDependencies) {
  return defineCallable(async (data, request) =>
    setClassStatus(
      deps.datastore,
      deps.clock,
      {
        ...payloadOf(data),
        uid: requireUid(request),
      } as unknown as SetClassStatusInput,
      deps.sessions,
    ),
  );
}
