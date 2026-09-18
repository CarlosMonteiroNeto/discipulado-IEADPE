/**
 * Scoped overview counts and pending sessions (S04, S08, S09, S11).
 *
 * The overview never downloads records to the browser: counts are produced by
 * authorized server-side queries, and `listPendingSessions` returns one page of
 * open sessions ordered by date then ID. `OverviewQueryReader` is the read port
 * the Admin/Firestore adapter implements; the in-memory implementation is the
 * deterministic test/emulator backing, mirroring `InMemoryStudentDirectory`.
 *
 * Authorization runs through `authorizeContext` on every call: staff are pinned
 * to their own congregation, supervisors may select one congregation or `null`
 * (Todas), and inactive profiles are rejected before any read.
 */
import { Clock, recifeToday } from "../core/clock";
import { authorizeContext } from "../core/context";
import { Datastore, JsonMap, paths } from "../core/datastore";
import { conflictError, validationError } from "../core/errors";
import { ClassStatus, SessionStatus } from "../core/models";
import {
  DEFAULT_PAGE_SIZE,
  MAX_PAGE_SIZE,
  NormalizedQuery,
  assertCursorMatches,
  decodeCursor,
  encodeCursor,
} from "../core/queries";

export interface OverviewCounts {
  students: number;
  classes: number;
  openSessions: number;
  throughDate: string;
}

export interface OpenSessionCountQuery {
  congregationId: string | null;
  throughDate: string;
}

export interface PendingSessionQuery {
  congregationId: string | null;
  throughDate: string;
  limit: number;
  after?: { date: string; id: string };
}

/**
 * Read port for the overview. Every method applies the scope filter before the
 * result is produced, so an aggregate query never leaks another scope.
 */
export interface OverviewQueryReader {
  countUnarchivedStudents(congregationId: string | null): Promise<number>;
  countActiveClasses(congregationId: string | null): Promise<number>;
  countOpenSessions(query: OpenSessionCountQuery): Promise<number>;
  listOpenSessions(query: PendingSessionQuery): Promise<JsonMap[]>;
}

function clone<T>(value: T): T {
  return structuredClone(value);
}

function nonEmpty(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value : null;
}

function inScope(document: JsonMap, congregationId: string | null): boolean {
  return (
    congregationId === null || document.congregationId === congregationId
  );
}

/**
 * Deterministic in-memory reader for tests and emulator runs. It applies the
 * same scope, archive, status and date constraints a scoped Firestore query
 * would, never returning a record outside the requested scope.
 */
export class InMemoryOverviewReader implements OverviewQueryReader {
  private readonly students: JsonMap[];
  private readonly classes: JsonMap[];
  private readonly sessions: JsonMap[];

  constructor(
    seed: {
      students?: readonly JsonMap[];
      classes?: readonly JsonMap[];
      sessions?: readonly JsonMap[];
    } = {},
  ) {
    this.students = (seed.students ?? []).map(clone);
    this.classes = (seed.classes ?? []).map(clone);
    this.sessions = (seed.sessions ?? []).map(clone);
  }

  async countUnarchivedStudents(congregationId: string | null): Promise<number> {
    return this.students.filter(
      (student) => inScope(student, congregationId) && student.archived !== true,
    ).length;
  }

  async countActiveClasses(congregationId: string | null): Promise<number> {
    return this.classes.filter(
      (record) =>
        inScope(record, congregationId) && record.status === ClassStatus.active,
    ).length;
  }

  async countOpenSessions(query: OpenSessionCountQuery): Promise<number> {
    return this.openSessions(query).length;
  }

  async listOpenSessions(query: PendingSessionQuery): Promise<JsonMap[]> {
    const after = query.after;
    return this.openSessions(query)
      .filter((session) => {
        if (after === undefined) return true;
        const date = String(session.date ?? "");
        if (date !== after.date) return date > after.date;
        return String(session.id ?? "") > after.id;
      })
      .slice(0, query.limit)
      .map(clone);
  }

  private openSessions(query: OpenSessionCountQuery): JsonMap[] {
    return this.sessions
      .filter(
        (session) =>
          inScope(session, query.congregationId) &&
          session.status === SessionStatus.open &&
          typeof session.date === "string" &&
          session.date <= query.throughDate,
      )
      .slice()
      .sort(compareSessions);
  }
}

function compareSessions(a: JsonMap, b: JsonMap): number {
  const aDate = String(a.date ?? "");
  const bDate = String(b.date ?? "");
  if (aDate !== bDate) return aDate < bDate ? -1 : 1;
  const aId = String(a.id ?? "");
  const bId = String(b.id ?? "");
  if (aId === bId) return 0;
  return aId < bId ? -1 : 1;
}

export interface GetOverviewInput {
  uid: string;
  congregationId?: string | null;
}

/**
 * Authoritative counts for the caller's authorized scope. `null` means Todas
 * and is only reachable by a supervisor; `authorizeContext` pins staff to their
 * own congregation and rejects inactive profiles.
 */
export async function getOverview(
  datastore: Datastore,
  reader: OverviewQueryReader,
  clock: Clock,
  input: GetOverviewInput,
): Promise<OverviewCounts> {
  const context = await authorizeContext({
    datastore,
    uid: input.uid,
    requestedCongregationId: input.congregationId ?? null,
  });
  const congregationId = context.congregationId;
  const throughDate = recifeToday(clock.now());

  const students = await reader.countUnarchivedStudents(congregationId);
  const classes = await reader.countActiveClasses(congregationId);
  const openSessions = await reader.countOpenSessions({
    congregationId,
    throughDate,
  });

  return { students, classes, openSessions, throughDate };
}

export interface ListPendingSessionsInput {
  uid: string;
  congregationId?: string | null;
  limit?: number;
  cursor?: string | null;
}

export interface PendingSessionsPage {
  items: JsonMap[];
  nextCursor: string | null;
}

/**
 * One page of open sessions through today's Recife date, ordered by date then
 * ID. The opaque cursor binds the scope and filter identity, so a cursor from
 * another scope or filter is rejected as a conflict.
 */
export async function listPendingSessions(
  datastore: Datastore,
  reader: OverviewQueryReader,
  clock: Clock,
  input: ListPendingSessionsInput,
): Promise<PendingSessionsPage> {
  const limit = input.limit ?? DEFAULT_PAGE_SIZE;
  if (!Number.isInteger(limit) || limit < 1 || limit > MAX_PAGE_SIZE) {
    throw validationError(`limit must be between 1 and ${MAX_PAGE_SIZE}.`, {
      limit: `limit must be between 1 and ${MAX_PAGE_SIZE}.`,
    });
  }

  const context = await authorizeContext({
    datastore,
    uid: input.uid,
    requestedCongregationId: input.congregationId ?? null,
  });
  const congregationId = context.congregationId;
  const throughDate = recifeToday(clock.now());

  // `throughDate` is part of the cursor identity: a cursor minted before the
  // Recife date rollover must not page against the next day's window.
  const identity: NormalizedQuery = {
    resource: "sessions",
    congregationId,
    filters: { status: SessionStatus.open, throughDate },
    limit,
  };

  let after: { date: string; id: string } | undefined;
  const cursor = nonEmpty(input.cursor);
  if (cursor !== null) {
    const decoded = decodeCursor(cursor);
    if (decoded.orderField !== "date") {
      throw conflictError("Cursor does not belong to this query.");
    }
    assertCursorMatches(decoded, identity);
    after = { date: decoded.orderValue, id: decoded.id };
  }

  const query: PendingSessionQuery = { congregationId, throughDate, limit: limit + 1 };
  if (after !== undefined) query.after = after;
  const candidates = await reader.listOpenSessions(query);

  const hasMore = candidates.length > limit;
  const page = candidates.slice(0, limit);
  const items: JsonMap[] = [];
  for (const session of page) {
    const classId = nonEmpty(session.classId) ?? "";
    const sessionCongregationId =
      nonEmpty(session.congregationId) ?? congregationId ?? "";
    let className: string | null = null;
    if (classId.length > 0 && sessionCongregationId.length > 0) {
      const classDocument = await datastore.read(
        paths.classGroup(sessionCongregationId, classId),
      );
      className = classDocument === null ? null : nonEmpty(classDocument.name);
    }
    items.push({
      id: session.id,
      classId,
      className,
      congregationId: sessionCongregationId,
      date: session.date,
      topic: session.topic ?? null,
      status: session.status,
    });
  }

  const last = page[page.length - 1];
  const nextCursor =
    hasMore && last !== undefined
      ? encodeCursor({
          resource: "sessions",
          congregationId,
          filters: { status: SessionStatus.open, throughDate },
          orderField: "date",
          orderValue: String(last.date ?? ""),
          id: String(last.id ?? ""),
        })
      : null;

  return { items, nextCursor };
}
