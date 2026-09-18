/**
 * Session, roster and attendance storage helpers (S05, S08, S11).
 *
 * A session is a scoped document under `congregations/{id}/sessions`; its
 * frozen roster and marks live in the `roster` and `attendance` subcollections
 * keyed by enrollment ID, matching the S05 model. Because the core Datastore
 * deliberately exposes no collection queries, the session document also keeps
 * `rosterEnrollmentIds`, a denormalized index the service reads to enumerate
 * frozen members inside the same transaction. Session uniqueness per
 * class/date is held by an internal `sessionDates/{date}` document that
 * noncanceled sessions claim and cancellation releases, and
 * `classes/{classId}/internal/sessionIndex` lists the class session IDs for
 * progress reads without a collection scan.
 *
 * `ClassEnrollmentReader` is the read port over enrollment intervals the
 * roster freeze needs; the in-memory implementation backs deterministic tests
 * while the Admin/Firestore adapter issues the scoped class query.
 */
import { MAX_ENROLLMENTS_PER_CLASS } from "../classes/service";
import { JsonMap } from "../core/datastore";

/** Minimal read surface shared by `Datastore` and `Transaction`. */
export interface SessionDocumentReader {
  read(path: string): Promise<JsonMap | null>;
}

export function sessionPath(congregationId: string, sessionId: string): string {
  return `congregations/${congregationId}/sessions/${sessionId}`;
}

export function rosterEntryPath(
  congregationId: string,
  sessionId: string,
  enrollmentId: string,
): string {
  return `${sessionPath(congregationId, sessionId)}/roster/${enrollmentId}`;
}

export function attendanceEntryPath(
  congregationId: string,
  sessionId: string,
  enrollmentId: string,
): string {
  return `${sessionPath(congregationId, sessionId)}/attendance/${enrollmentId}`;
}

export function sessionIndexPath(congregationId: string, classId: string): string {
  return `congregations/${congregationId}/classes/${classId}/internal/sessionIndex`;
}

export function sessionDateLockPath(
  congregationId: string,
  classId: string,
  date: string,
): string {
  return `congregations/${congregationId}/classes/${classId}/internal/sessionDates/${date}`;
}

/** The S11 cap of 100 roster members bounds every attendance transaction. */
export const MAX_ROSTER_MEMBERS = MAX_ENROLLMENTS_PER_CLASS;

export interface ClassEnrollmentQuery {
  congregationId: string;
  classId: string;
}

export interface ClassEnrollmentReader {
  listClassEnrollments(query: ClassEnrollmentQuery): Promise<JsonMap[]>;
}

export class InMemoryClassEnrollmentReader implements ClassEnrollmentReader {
  private readonly enrollments: JsonMap[];

  constructor(seed: { enrollments?: readonly JsonMap[] } = {}) {
    this.enrollments = (seed.enrollments ?? []).map((entry) =>
      structuredClone(entry),
    );
  }

  async listClassEnrollments(query: ClassEnrollmentQuery): Promise<JsonMap[]> {
    return this.enrollments
      .filter(
        (enrollment) =>
          enrollment.congregationId === query.congregationId &&
          enrollment.classId === query.classId,
      )
      .map((entry) => structuredClone(entry));
  }
}

function nonEmpty(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value : null;
}

export function enrollmentIdOf(enrollment: JsonMap): string | null {
  return nonEmpty(enrollment.id) ?? nonEmpty(enrollment.enrollmentId);
}

/**
 * S08 freezes every enrollment whose date interval includes the session date,
 * including completed and withdrawn intervals.
 */
export function isEligibleOnDate(enrollment: JsonMap, date: string): boolean {
  const startDate = nonEmpty(enrollment.startDate);
  if (startDate === null || date < startDate) return false;
  const endDate = nonEmpty(enrollment.endDate);
  if (endDate !== null && date > endDate) return false;
  return true;
}

/** Reads the denormalized frozen-membership index from a session document. */
export function rosterIdsFromSession(session: JsonMap): string[] {
  const raw = session.rosterEnrollmentIds;
  if (!Array.isArray(raw)) return [];
  return raw.filter((value): value is string => typeof value === "string");
}

export async function readRoster(
  reader: SessionDocumentReader,
  congregationId: string,
  sessionId: string,
): Promise<JsonMap[]> {
  const session = await reader.read(sessionPath(congregationId, sessionId));
  if (session === null) return [];
  const entries: JsonMap[] = [];
  for (const enrollmentId of rosterIdsFromSession(session)) {
    const entry = await reader.read(
      rosterEntryPath(congregationId, sessionId, enrollmentId),
    );
    if (entry !== null) entries.push(entry);
  }
  return entries;
}

export async function readAttendance(
  reader: SessionDocumentReader,
  congregationId: string,
  sessionId: string,
): Promise<JsonMap[]> {
  const entries: JsonMap[] = [];
  const session = await reader.read(sessionPath(congregationId, sessionId));
  if (session === null) return entries;
  for (const enrollmentId of rosterIdsFromSession(session)) {
    const entry = await reader.read(
      attendanceEntryPath(congregationId, sessionId, enrollmentId),
    );
    if (entry !== null) entries.push(entry);
  }
  return entries;
}
