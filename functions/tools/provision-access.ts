/**
 * Trusted access-profile provisioning utility (S04, S06).
 *
 * Accepts an existing Auth UID, access role, active flag and congregation
 * binding, validates the target congregation, and writes the `users/{uid}`
 * profile. It is a plain Admin SDK utility invoked by an operator; it is never
 * registered as a callable endpoint.
 *
 * The profile write and the congregation archive-dependency counter run in one
 * datastore transaction: an active profile bound to a congregation is a
 * dependency, so creating, deactivating or rebinding it keeps
 * `congregations/{id}/internal/references.activeUsers` consistent without a
 * second, non-atomic write.
 */
import { Datastore, JsonMap, Transaction, paths } from "../src/core/datastore";
import { notFoundError, validationError } from "../src/core/errors";
import { AccessRole } from "../src/core/models";
import { adjustScopeReference } from "../src/congregations/service";

export interface ProvisionRequest {
  uid: string;
  accessRole: string;
  active: boolean;
  congregationId?: string | null;
  now?: Date;
}

export interface ProvisionOutcome {
  uid: string;
  accessRole: AccessRole;
  congregationId: string | null;
  active: boolean;
}

function boundCongregationId(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value : null;
}

/**
 * Adjusts the active-user dependency counts for the congregation(s) affected by
 * this profile write. A profile counts only while it is active and bound.
 */
async function reconcileActiveUserReferences(
  tx: Transaction,
  existing: JsonMap | null,
  congregationId: string | null,
  active: boolean,
): Promise<void> {
  const previousCongregationId = boundCongregationId(existing?.congregationId);
  const wasActive = existing?.active === true;

  if (
    wasActive &&
    previousCongregationId !== null &&
    (previousCongregationId !== congregationId || !active)
  ) {
    await adjustScopeReference(tx, previousCongregationId, "activeUsers", -1);
  }
  if (
    active &&
    congregationId !== null &&
    (!wasActive || previousCongregationId !== congregationId)
  ) {
    await adjustScopeReference(tx, congregationId, "activeUsers", 1);
  }
}

export async function provisionAccess(
  datastore: Datastore,
  request: ProvisionRequest,
): Promise<ProvisionOutcome> {
  if (typeof request.uid !== "string" || request.uid.trim().length === 0) {
    throw validationError("An existing Auth UID is required.", {
      uid: "An existing Auth UID is required.",
    });
  }
  if (typeof request.active !== "boolean") {
    throw validationError("active must be a boolean.", {
      active: "active must be a boolean.",
    });
  }

  let accessRole: AccessRole;
  if (request.accessRole === AccessRole.supervisor) {
    accessRole = AccessRole.supervisor;
  } else if (request.accessRole === AccessRole.congregationStaff) {
    accessRole = AccessRole.congregationStaff;
  } else {
    throw validationError("Unknown access role.", {
      accessRole: "Unknown access role.",
    });
  }

  const congregationId = boundCongregationId(request.congregationId);

  if (accessRole === AccessRole.congregationStaff && congregationId === null) {
    throw validationError("Staff must be bound to a congregation.", {
      congregationId: "Staff must be bound to a congregation.",
    });
  }

  return datastore.runTransaction(async (tx) => {
    if (congregationId !== null) {
      const congregation = await tx.read(paths.congregation(congregationId));
      if (congregation === null) {
        throw notFoundError("Congregation not found.");
      }
      if (congregation.active !== true) {
        throw validationError("Congregation is inactive.", {
          congregationId: "Congregation is inactive.",
        });
      }
    }

    const existing = await tx.read(paths.user(request.uid));
    const revision = existing === null ? 1 : Number(existing.revision ?? 0) + 1;
    const updatedAt = (request.now ?? new Date()).toISOString();

    await tx.write(paths.user(request.uid), {
      accessRole,
      congregationId,
      active: request.active,
      revision,
      updatedAt,
    });
    await reconcileActiveUserReferences(
      tx,
      existing,
      congregationId,
      request.active,
    );

    return {
      uid: request.uid,
      accessRole,
      congregationId,
      active: request.active,
    };
  });
}
