/**
 * Scoped query validation, opaque cursors and the declared query matrix (S09).
 *
 * Only the shipped filter/sort combinations are accepted; the companion
 * `firestore.indexes.json` declares one composite index per matrix entry and
 * the query matrix test proves the two stay in sync.
 */
import type { AuthorizedContext } from "./context";
import { AppError, conflictError, validationError } from "./errors";
import { AccessRole } from "./models";
import { normalizeName } from "./validation";

export const DEFAULT_PAGE_SIZE = 50;
export const MAX_PAGE_SIZE = 100;

export type Resource =
  | "directory"
  | "congregations"
  | "contacts"
  | "students"
  | "classes"
  | "enrollments"
  | "sessions";

export const SUPPORTED_RESOURCES: readonly Resource[] = [
  "directory",
  "congregations",
  "contacts",
  "students",
  "classes",
  "enrollments",
  "sessions",
];

/** Internal collections are never valid query resources (S11). */
const INTERNAL_RESOURCES = new Set([
  "operations",
  "receipts",
  "roster",
  "attendance",
  "roleSlots",
  "supervisionRoleSlots",
]);

const RESOURCE_FILTERS: Record<Resource, readonly string[]> = {
  directory: ["scope", "roleCode", "congregationId"],
  congregations: ["active"],
  contacts: ["congregationId", "archived"],
  students: ["congregationId", "archived"],
  classes: ["congregationId", "status"],
  enrollments: ["congregationId", "classId", "studentId", "status"],
  sessions: ["congregationId", "classId", "status"],
};

const NAME_PREFIX_RESOURCES = new Set<Resource>([
  "directory",
  "contacts",
  "students",
  "classes",
]);

const SCOPED_RESOURCES = new Set<Resource>([
  "contacts",
  "students",
  "classes",
  "enrollments",
  "sessions",
]);

export type QueryFilterValue = string | boolean;

export interface QueryRequest {
  resource: string;
  congregationId?: string | null;
  filters?: Record<string, QueryFilterValue>;
  namePrefix?: string;
  limit?: number;
  cursor?: string;
}

export interface NormalizedQuery {
  resource: Resource;
  congregationId: string | null;
  filters: Record<string, QueryFilterValue>;
  namePrefix?: string;
  limit: number;
}

function sortedFilters(
  filters: Record<string, QueryFilterValue>,
): Record<string, QueryFilterValue> {
  const sorted: Record<string, QueryFilterValue> = {};
  for (const key of Object.keys(filters).sort()) {
    const value = filters[key];
    if (value !== undefined) sorted[key] = value;
  }
  return sorted;
}

export function validateQueryRequest(
  request: QueryRequest,
  context: AuthorizedContext,
): NormalizedQuery {
  if (typeof request.resource !== "string") {
    throw validationError("resource is required.");
  }
  if (INTERNAL_RESOURCES.has(request.resource)) {
    throw validationError("Internal collections cannot be queried.");
  }
  if (!(SUPPORTED_RESOURCES as readonly string[]).includes(request.resource)) {
    throw validationError("Unsupported resource.");
  }
  const resource = request.resource as Resource;

  const limit = request.limit ?? DEFAULT_PAGE_SIZE;
  if (!Number.isInteger(limit) || limit < 1 || limit > MAX_PAGE_SIZE) {
    throw validationError(`limit must be between 1 and ${MAX_PAGE_SIZE}.`, {
      limit: `limit must be between 1 and ${MAX_PAGE_SIZE}.`,
    });
  }

  const filters = sortedFilters(request.filters ?? {});
  const allowedFilters = RESOURCE_FILTERS[resource];
  for (const key of Object.keys(filters)) {
    if (!allowedFilters.includes(key)) {
      throw validationError(`Unsupported filter for ${resource}: ${key}.`, {
        [key]: "Unsupported filter.",
      });
    }
  }

  let congregationId = request.congregationId ?? null;
  if (SCOPED_RESOURCES.has(resource)) {
    if (context.profile.accessRole === AccessRole.supervisor) {
      // Supervisors may select any congregation; null means aggregate.
    } else {
      if (congregationId !== null && congregationId !== context.congregationId) {
        throw new AppError("forbidden", "Cross-congregation access is denied.");
      }
      congregationId = context.congregationId;
    }
  } else if (
    congregationId !== null &&
    context.profile.accessRole !== AccessRole.supervisor &&
    congregationId !== context.congregationId
  ) {
    throw new AppError("forbidden", "Cross-congregation access is denied.");
  }

  let namePrefix: string | undefined;
  if (request.namePrefix !== undefined) {
    if (!NAME_PREFIX_RESOURCES.has(resource)) {
      throw validationError(`namePrefix is not supported for ${resource}.`, {
        namePrefix: "Unsupported name prefix search.",
      });
    }
    namePrefix = normalizeName(request.namePrefix);
    if (namePrefix.length === 0) {
      throw validationError("namePrefix must not be blank.", {
        namePrefix: "Unsupported name prefix search.",
      });
    }
  }

  const normalized: NormalizedQuery = {
    resource,
    congregationId,
    filters,
    limit,
  };
  if (namePrefix !== undefined) normalized.namePrefix = namePrefix;
  return normalized;
}

export interface CursorPayload {
  resource: Resource;
  congregationId: string | null;
  filters: Record<string, QueryFilterValue>;
  orderField: string;
  orderValue: string;
  id: string;
}

export function encodeCursor(payload: CursorPayload): string {
  return Buffer.from(JSON.stringify(payload), "utf8").toString("base64url");
}

export function decodeCursor(cursor: string): CursorPayload {
  try {
    const parsed = JSON.parse(
      Buffer.from(cursor, "base64url").toString("utf8"),
    ) as CursorPayload;
    if (
      typeof parsed?.resource !== "string" ||
      typeof parsed?.orderField !== "string" ||
      typeof parsed?.id !== "string"
    ) {
      throw new Error("bad cursor shape");
    }
    return parsed;
  } catch {
    throw validationError("Invalid cursor.", { cursor: "Invalid cursor." });
  }
}

/** A cursor is only reusable while scope and filters are unchanged. */
export function assertCursorMatches(
  cursor: CursorPayload,
  query: NormalizedQuery,
): void {
  const sameIdentity =
    cursor.resource === query.resource &&
    (cursor.congregationId ?? null) === (query.congregationId ?? null) &&
    JSON.stringify(sortedFilters(cursor.filters ?? {})) ===
      JSON.stringify(query.filters);
  if (!sameIdentity) {
    throw conflictError("Cursor does not belong to this query.");
  }
}

export interface QueryMatrixEntry {
  resource: Resource;
  collectionGroup: string;
  filters: readonly string[];
  orderBy: readonly string[];
  /** Ordered composite-index fields required by the shipped query. */
  indexFields: readonly string[];
}

/**
 * The shipped equality-filter and sort-order combinations from S09. Every
 * entry must have a matching composite index in `firestore.indexes.json`.
 */
export const QUERY_MATRIX: readonly QueryMatrixEntry[] = [
  {
    resource: "directory",
    collectionGroup: "directory",
    filters: ["scope"],
    orderBy: ["normalizedName", "id"],
    indexFields: ["scope", "normalizedName"],
  },
  {
    resource: "directory",
    collectionGroup: "directory",
    filters: ["scope", "roleCode"],
    orderBy: ["normalizedName", "id"],
    indexFields: ["scope", "roleCode", "normalizedName"],
  },
  {
    resource: "directory",
    collectionGroup: "directory",
    filters: ["congregationId"],
    orderBy: ["normalizedName", "id"],
    indexFields: ["congregationId", "normalizedName"],
  },
  {
    resource: "students",
    collectionGroup: "students",
    filters: ["congregationId", "archived"],
    orderBy: ["normalizedName", "id"],
    indexFields: ["congregationId", "archived", "normalizedName"],
  },
  {
    resource: "contacts",
    collectionGroup: "contacts",
    filters: ["congregationId", "archived"],
    orderBy: ["normalizedName", "id"],
    indexFields: ["congregationId", "archived", "normalizedName"],
  },
  {
    resource: "contacts",
    collectionGroup: "supervisionContacts",
    filters: ["archived"],
    orderBy: ["normalizedName", "id"],
    indexFields: ["archived", "normalizedName"],
  },
  {
    resource: "classes",
    collectionGroup: "classes",
    filters: ["congregationId", "status"],
    orderBy: ["normalizedName", "id"],
    indexFields: ["congregationId", "status", "normalizedName"],
  },
  {
    resource: "sessions",
    collectionGroup: "sessions",
    filters: ["classId", "status"],
    orderBy: ["date", "id"],
    indexFields: ["classId", "status", "date"],
  },
  {
    resource: "sessions",
    collectionGroup: "sessions",
    filters: ["congregationId", "status"],
    orderBy: ["date", "id"],
    indexFields: ["congregationId", "status", "date"],
  },
  {
    resource: "enrollments",
    collectionGroup: "enrollments",
    filters: ["classId", "status"],
    orderBy: ["startDate", "id"],
    indexFields: ["classId", "status", "startDate"],
  },
  {
    resource: "enrollments",
    collectionGroup: "enrollments",
    filters: ["studentId", "status"],
    orderBy: ["startDate", "id"],
    indexFields: ["studentId", "status", "startDate"],
  },
  {
    resource: "enrollments",
    collectionGroup: "enrollments",
    filters: ["congregationId", "studentId", "status"],
    orderBy: ["startDate", "id"],
    indexFields: ["congregationId", "studentId", "status", "startDate"],
  },
];
