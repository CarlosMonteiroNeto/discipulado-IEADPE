/**
 * Callable wrappers for contact and role operations (S11).
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
  ReplaceRoleHolderInput,
  SaveContactInput,
  SetContactArchivedInput,
  replaceRoleHolder,
  saveContact,
  setContactArchived,
} from "./service";

export interface ContactHandlerDependencies {
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

export function saveContactCallable(deps: ContactHandlerDependencies) {
  return defineCallable(async (data, request) =>
    saveContact(deps.datastore, deps.clock, {
      ...payloadOf(data),
      uid: requireUid(request),
    } as unknown as SaveContactInput),
  );
}

export function replaceRoleHolderCallable(deps: ContactHandlerDependencies) {
  return defineCallable(async (data, request) =>
    replaceRoleHolder(deps.datastore, deps.clock, {
      ...payloadOf(data),
      uid: requireUid(request),
    } as unknown as ReplaceRoleHolderInput),
  );
}

export function setContactArchivedCallable(deps: ContactHandlerDependencies) {
  return defineCallable(async (data, request) =>
    setContactArchived(deps.datastore, deps.clock, {
      ...payloadOf(data),
      uid: requireUid(request),
    } as unknown as SetContactArchivedInput),
  );
}
