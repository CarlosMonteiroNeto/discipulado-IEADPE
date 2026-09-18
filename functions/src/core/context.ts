/**
 * Server-authoritative authorization context (S04).
 *
 * The current `users/{uid}` profile is read on every callable operation, the
 * bound congregation is resolved, and inactive or missing profiles are
 * rejected. Caller-supplied role or congregation claims never grant access:
 * this module only reads the stored profile.
 */
import { Datastore, JsonMap, paths } from "./datastore";
import { forbiddenError, notFoundError } from "./errors";
import { AccessProfileRecord, AccessRole, parseAccessRole } from "./models";

export interface AuthorizedContext {
  uid: string;
  profile: AccessProfileRecord;
  congregation: JsonMap | null;
  congregationId: string | null;
}

export interface AuthorizeInput {
  datastore: Datastore;
  uid: string;
  requestedCongregationId?: string | null;
  /** Accepted for interface parity; never consulted for privileges. */
  payload?: JsonMap;
}

function nonEmpty(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value : null;
}

export async function authorizeContext(
  input: AuthorizeInput,
): Promise<AuthorizedContext> {
  const stored = await input.datastore.read(paths.user(input.uid));
  if (stored === null) {
    throw forbiddenError("Access profile not found.");
  }
  if (stored.active !== true) {
    throw forbiddenError("Access profile is inactive.");
  }

  const accessRole: AccessRole = parseAccessRole(stored.accessRole);
  const boundCongregationId = nonEmpty(stored.congregationId);

  if (accessRole === AccessRole.congregationStaff && boundCongregationId === null) {
    throw forbiddenError("Staff must be bound to a congregation.");
  }

  const requested = nonEmpty(input.requestedCongregationId);
  if (
    accessRole === AccessRole.congregationStaff &&
    requested !== null &&
    requested !== boundCongregationId
  ) {
    throw forbiddenError("Cross-congregation access is denied.");
  }

  const targetCongregationId =
    accessRole === AccessRole.supervisor ? (requested ?? boundCongregationId) : boundCongregationId;

  let congregation: JsonMap | null = null;
  if (targetCongregationId !== null) {
    congregation = await input.datastore.read(paths.congregation(targetCongregationId));
    if (congregation === null) {
      if (accessRole === AccessRole.congregationStaff) {
        // The caller's assigned scope is invalid; do not leak whether the
        // congregation exists.
        throw forbiddenError("Bound congregation is unavailable.");
      }
      throw notFoundError("Congregation not found.");
    }
    if (
      accessRole === AccessRole.congregationStaff &&
      congregation.active !== true
    ) {
      throw forbiddenError("Congregation is inactive.");
    }
  }

  const profile: AccessProfileRecord = {
    accessRole,
    congregationId: boundCongregationId,
    active: true,
    revision: Number(stored.revision),
    updatedAt: String(stored.updatedAt ?? ""),
  };

  return {
    uid: input.uid,
    profile,
    congregation,
    congregationId: targetCongregationId,
  };
}

/** Supervisors read every scope; staff only their assigned congregation. */
export function assertCongregationAccess(
  context: AuthorizedContext,
  congregationId: string | null,
): void {
  if (congregationId === null || congregationId.length === 0) return;
  if (context.profile.accessRole === AccessRole.supervisor) return;
  if (context.profile.congregationId !== congregationId) {
    throw forbiddenError("Cross-congregation access is denied.");
  }
}
