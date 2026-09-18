/**
 * Scoped student list queries (S07, S09, S11).
 *
 * The active-class filter first resolves the class's active enrollment
 * membership and only then reads the students constrained to those student
 * IDs, so a page is never assembled from unrelated students and filtered
 * afterwards. Ordering is normalizedName then ID and the opaque cursor binds
 * resource, congregation, class filter, search and ordering, so a cursor is
 * only reusable while the query identity is unchanged.
 *
 * `StudentQueryReader` is the read port the Admin/Firestore adapter will
 * implement (one query over enrollments and one over students). The in-memory
 * implementation is the deterministic test/emulator backing, mirroring
 * `InMemoryDatastore` in the core.
 */
import { authorizeContext } from "../core/context";
import { Datastore, JsonMap, paths } from "../core/datastore";
import { conflictError, notFoundError, validationError } from "../core/errors";
import {
  DEFAULT_PAGE_SIZE,
  MAX_PAGE_SIZE,
  NormalizedQuery,
  assertCursorMatches,
  decodeCursor,
  encodeCursor,
} from "../core/queries";
import { normalizeName } from "../core/validation";

/** Active-enrollment query for one class. `status` is always "active" here. */
export interface ClassEnrollmentQuery {
  congregationId: string;
  classId: string;
  status: string;
}

/** Student read constrained to the resolved class membership. */
export interface ClassStudentQuery {
  congregationId: string;
  studentIds: readonly string[];
  archived: boolean;
  namePrefix?: string;
}

export interface StudentQueryReader {
  listEnrollments(query: ClassEnrollmentQuery): Promise<JsonMap[]>;
  listStudents(query: ClassStudentQuery): Promise<JsonMap[]>;
}

function clone<T>(value: T): T {
  return structuredClone(value);
}

/**
 * Deterministic in-memory reader for tests and emulator runs. It applies the
 * same congregation, membership, archived and normalized-prefix constraints a
 * scoped Firestore query would, never returning a student outside the scope.
 */
export class InMemoryStudentDirectory implements StudentQueryReader {
  private readonly students: JsonMap[];
  private readonly enrollments: JsonMap[];

  constructor(
    seed: {
      students?: readonly JsonMap[];
      enrollments?: readonly JsonMap[];
    } = {},
  ) {
    this.students = (seed.students ?? []).map(clone);
    this.enrollments = (seed.enrollments ?? []).map(clone);
  }

  async listEnrollments(query: ClassEnrollmentQuery): Promise<JsonMap[]> {
    return this.enrollments
      .filter(
        (enrollment) =>
          enrollment.congregationId === query.congregationId &&
          enrollment.classId === query.classId &&
          enrollment.status === query.status,
      )
      .map(clone);
  }

  async listStudents(query: ClassStudentQuery): Promise<JsonMap[]> {
    const members = new Set(query.studentIds);
    return this.students
      .filter(
        (student) =>
          student.congregationId === query.congregationId &&
          typeof student.id === "string" &&
          members.has(student.id) &&
          (student.archived === true) === query.archived &&
          (query.namePrefix === undefined ||
            String(student.normalizedName ?? "").startsWith(query.namePrefix)),
      )
      .map(clone);
  }
}

/** Fields a student list row may expose; no birth date, address or religious answers. */
export const STUDENT_LIST_FIELDS = [
  "id",
  "name",
  "normalizedName",
  "congregationId",
  "archived",
  "revision",
] as const;

export function toStudentListEntry(student: JsonMap): JsonMap {
  const entry: JsonMap = {};
  for (const field of STUDENT_LIST_FIELDS) {
    if (Object.prototype.hasOwnProperty.call(student, field)) {
      entry[field] = student[field];
    }
  }
  return entry;
}

export interface ListClassStudentsInput {
  uid: string;
  congregationId?: string | null;
  classId: string;
  namePrefix?: string;
  archived?: boolean;
  limit?: number;
  cursor?: string | null;
}

export interface ClassStudentPage {
  items: JsonMap[];
  nextCursor: string | null;
}

interface CursorPosition {
  orderValue: string;
  id: string;
}

function compareStudents(a: JsonMap, b: JsonMap): number {
  const aName = String(a.normalizedName ?? "");
  const bName = String(b.normalizedName ?? "");
  if (aName !== bName) return aName < bName ? -1 : 1;
  const aId = String(a.id ?? "");
  const bId = String(b.id ?? "");
  if (aId === bId) return 0;
  return aId < bId ? -1 : 1;
}

function isAfter(item: JsonMap, position: CursorPosition): boolean {
  const name = String(item.normalizedName ?? "");
  if (name !== position.orderValue) return name > position.orderValue;
  return String(item.id ?? "") > position.id;
}

export async function listClassStudents(
  datastore: Datastore,
  reader: StudentQueryReader,
  input: ListClassStudentsInput,
): Promise<ClassStudentPage> {
  if (typeof input.classId !== "string" || input.classId.trim().length === 0) {
    throw validationError("classId is required.", {
      classId: "classId is required.",
    });
  }
  const limit = input.limit ?? DEFAULT_PAGE_SIZE;
  if (!Number.isInteger(limit) || limit < 1 || limit > MAX_PAGE_SIZE) {
    throw validationError(`limit must be between 1 and ${MAX_PAGE_SIZE}.`, {
      limit: `limit must be between 1 and ${MAX_PAGE_SIZE}.`,
    });
  }
  const archived = input.archived ?? false;
  if (typeof archived !== "boolean") {
    throw validationError("archived must be true or false.", {
      archived: "archived must be true or false.",
    });
  }
  let namePrefix: string | undefined;
  if (input.namePrefix !== undefined) {
    namePrefix = normalizeName(input.namePrefix);
    if (namePrefix.length === 0) {
      throw validationError("namePrefix must not be blank.", {
        namePrefix: "namePrefix must not be blank.",
      });
    }
  }

  const context = await authorizeContext({
    datastore,
    uid: input.uid,
    requestedCongregationId: input.congregationId ?? null,
  });
  const congregationId = context.congregationId;
  if (congregationId === null || congregationId.length === 0) {
    throw validationError("congregationId is required.", {
      congregationId: "congregationId is required.",
    });
  }

  const classDocument = await datastore.read(
    paths.classGroup(congregationId, input.classId),
  );
  if (classDocument === null) {
    throw notFoundError("Class not found.");
  }

  const filters: Record<string, string | boolean> = {
    archived,
    classId: input.classId,
  };
  if (namePrefix !== undefined) filters.namePrefix = namePrefix;
  const identity: NormalizedQuery = {
    resource: "students",
    congregationId,
    filters,
    limit,
  };
  if (namePrefix !== undefined) identity.namePrefix = namePrefix;

  let position: CursorPosition | null = null;
  if (
    input.cursor !== undefined &&
    input.cursor !== null &&
    input.cursor.length > 0
  ) {
    const cursor = decodeCursor(input.cursor);
    if (cursor.orderField !== "normalizedName") {
      throw conflictError("Cursor does not belong to this query.");
    }
    assertCursorMatches(cursor, identity);
    position = { orderValue: cursor.orderValue, id: cursor.id };
  }

  const enrollments = await reader.listEnrollments({
    congregationId,
    classId: input.classId,
    status: "active",
  });
  const studentIds = Array.from(
    new Set(
      enrollments
        .map((enrollment) => enrollment.studentId)
        .filter(
          (id): id is string => typeof id === "string" && id.length > 0,
        ),
    ),
  );
  if (studentIds.length === 0) {
    return { items: [], nextCursor: null };
  }

  const studentQuery: ClassStudentQuery = { congregationId, studentIds, archived };
  if (namePrefix !== undefined) studentQuery.namePrefix = namePrefix;
  const students = await reader.listStudents(studentQuery);
  const ordered = students.slice().sort(compareStudents);

  let start = 0;
  if (position !== null) {
    const index = ordered.findIndex((item) => isAfter(item, position as CursorPosition));
    start = index < 0 ? ordered.length : index;
  }
  const page = ordered.slice(start, start + limit);
  const hasMore = start + page.length < ordered.length;
  const last = page[page.length - 1];
  const nextCursor =
    hasMore && last !== undefined
      ? encodeCursor({
          resource: "students",
          congregationId,
          filters,
          orderField: "normalizedName",
          orderValue: String(last.normalizedName ?? ""),
          id: String(last.id ?? ""),
        })
      : null;

  return { items: page.map(toStudentListEntry), nextCursor };
}
