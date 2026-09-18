/**
 * Trusted access-profile provisioning utility (S04).
 *
 * Accepts an existing Auth UID, access role, active flag and congregation
 * binding, validates the target congregation, and writes the `users/{uid}`
 * profile. It is a plain Admin SDK utility invoked by an operator; it is never
 * registered as a callable endpoint.
 */
import { Datastore, paths } from "../src/core/datastore";
import { notFoundError, validationError } from "../src/core/errors";
import { AccessRole } from "../src/core/models";

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

  const congregationId =
    typeof request.congregationId === "string" && request.congregationId.length > 0
      ? request.congregationId
      : null;

  if (accessRole === AccessRole.congregationStaff && congregationId === null) {
    throw validationError("Staff must be bound to a congregation.", {
      congregationId: "Staff must be bound to a congregation.",
    });
  }

  if (congregationId !== null) {
    const congregation = await datastore.read(paths.congregation(congregationId));
    if (congregation === null) {
      throw notFoundError("Congregation not found.");
    }
    if (congregation.active !== true) {
      throw validationError("Congregation is inactive.", {
        congregationId: "Congregation is inactive.",
      });
    }
  }

  const existing = await datastore.read(paths.user(request.uid));
  const revision =
    existing === null ? 1 : Number(existing.revision ?? 0) + 1;
  const updatedAt = (request.now ?? new Date()).toISOString();

  await datastore.write(paths.user(request.uid), {
    accessRole,
    congregationId,
    active: request.active,
    revision,
    updatedAt,
  });

  return {
    uid: request.uid,
    accessRole,
    congregationId,
    active: request.active,
  };
}
