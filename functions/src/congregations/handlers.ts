/**
 * Callable wrappers for congregation operations (S11).
 *
 * Thin transport layer: it extracts the authenticated UID and forwards the
 * payload to the injectable service. All business logic and authorization
 * live in the service, so the same operations are unit-testable without the
 * Functions runtime.
 */
import { defineCallable } from "../core/callable";
import { Clock } from "../core/clock";
import { Datastore } from "../core/datastore";
import { AppError } from "../core/errors";
import {
  SaveCongregationInput,
  SetCongregationArchivedInput,
  saveCongregation,
  setCongregationArchived,
} from "./service";

export interface CongregationHandlerDependencies {
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

export function saveCongregationCallable(
  deps: CongregationHandlerDependencies,
) {
  return defineCallable(async (data, request) =>
    saveCongregation(deps.datastore, deps.clock, {
      ...payloadOf(data),
      uid: requireUid(request),
    } as unknown as SaveCongregationInput),
  );
}

export function setCongregationArchivedCallable(
  deps: CongregationHandlerDependencies,
) {
  return defineCallable(async (data, request) =>
    setCongregationArchived(deps.datastore, deps.clock, {
      ...payloadOf(data),
      uid: requireUid(request),
    } as unknown as SetCongregationArchivedInput),
  );
}
