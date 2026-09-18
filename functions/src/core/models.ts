/**
 * Shared backend wire types and the minimal directory projection (S04, S05).
 *
 * The Dart domain layer in `lib/domain/` is the mirror of these wire values;
 * change one only with the other.
 */
import { AppError } from "./errors";

export enum AccessRole {
  supervisor = "supervisor",
  congregationStaff = "congregationStaff",
}

export enum ContactScope {
  congregation = "congregation",
  supervision = "supervision",
}

export enum ClassStatus {
  active = "active",
  completed = "completed",
  archived = "archived",
}

export enum EnrollmentStatus {
  active = "active",
  completed = "completed",
  withdrawn = "withdrawn",
}

export enum SessionStatus {
  open = "open",
  finalized = "finalized",
  canceled = "canceled",
}

export enum AttendanceStatus {
  present = "present",
  absent = "absent",
  excused = "excused",
  unmarked = "unmarked",
}

/** The twelve stable role codes with their owning scope (S06). */
export const ROLE_CODES = {
  campaignSupervisor: ContactScope.supervision,
  campaignDeputy: ContactScope.supervision,
  discipleshipCoordinator: ContactScope.supervision,
  discipleshipDeputy: ContactScope.supervision,
  coordinationSecretary: ContactScope.supervision,
  coordinationDeputySecretary: ContactScope.supervision,
  congregationAssistant: ContactScope.congregation,
  campaignLeader: ContactScope.congregation,
  campaignDeputyLeader: ContactScope.congregation,
  teacher: ContactScope.congregation,
  discipleshipSecretary: ContactScope.congregation,
  discipleshipDeputySecretary: ContactScope.congregation,
} as const;

export type RoleCode = keyof typeof ROLE_CODES;

export function isRoleCode(value: unknown): value is RoleCode {
  return typeof value === "string" && Object.prototype.hasOwnProperty.call(ROLE_CODES, value);
}

export function roleScope(code: RoleCode): ContactScope {
  return ROLE_CODES[code];
}

export function parseAccessRole(value: unknown): AccessRole {
  if (
    value === AccessRole.supervisor ||
    value === AccessRole.congregationStaff
  ) {
    return value;
  }
  throw new AppError("validation", "Unknown access role.", {
    accessRole: "Unknown access role.",
  });
}

/** The validated `users/{uid}` profile fields the backend reasons about. */
export interface AccessProfileRecord {
  accessRole: AccessRole;
  congregationId: string | null;
  active: boolean;
  revision: number;
  updatedAt: string;
}

/** Fields allowed in the authenticated directory projection (S04). */
export const DIRECTORY_PROJECTION_FIELDS = [
  "id",
  "name",
  "normalizedName",
  "roleCode",
  "scope",
  "congregationId",
  "phoneE164",
] as const;

/**
 * Reduce a contact to the minimal authenticated directory projection. Birth
 * date, address and every student/religious field never appear here.
 */
export function toDirectoryProjection(
  contact: Record<string, unknown>,
): Record<string, unknown> {
  const projection: Record<string, unknown> = {};
  for (const field of DIRECTORY_PROJECTION_FIELDS) {
    if (Object.prototype.hasOwnProperty.call(contact, field)) {
      projection[field] = contact[field];
    }
  }
  return projection;
}
