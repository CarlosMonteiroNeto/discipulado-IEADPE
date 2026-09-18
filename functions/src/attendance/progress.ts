/**
 * Enrollment progress from finalized, noncanceled sessions (S08, S11).
 *
 * Progress is enrollment-specific and counts only finalized sessions that are
 * not canceled and whose frozen roster contains the enrollment. Excused
 * sessions are reported separately and excluded from the denominator, so the
 * percentage is `present / (present + absent)` rounded to the nearest whole
 * percent. A zero denominator returns a null percentage instead of 0%.
 */
import { authorizeContext } from "../core/context";
import { Datastore, paths } from "../core/datastore";
import { notFoundError, validationError } from "../core/errors";
import { AttendanceStatus, SessionStatus } from "../core/models";
import {
  attendanceEntryPath,
  readRoster,
  rosterIdsFromSession,
  sessionIndexPath,
  sessionPath,
} from "./roster";

export interface GetEnrollmentProgressInput {
  uid: string;
  congregationId?: string | null;
  enrollmentId: string;
}

export interface EnrollmentProgress {
  enrollmentId: string;
  studentId: string;
  classId: string;
  present: number;
  absent: number;
  excused: number;
  total: number;
  percentage: number | null;
}

function nonEmpty(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value : null;
}

export async function getEnrollmentProgress(
  datastore: Datastore,
  input: GetEnrollmentProgressInput,
): Promise<EnrollmentProgress> {
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
  if (typeof input.enrollmentId !== "string" || input.enrollmentId.length === 0) {
    throw validationError("enrollmentId is required.", {
      enrollmentId: "enrollmentId is required.",
    });
  }

  const enrollment = await datastore.read(
    paths.enrollment(congregationId, input.enrollmentId),
  );
  if (enrollment === null || enrollment.congregationId !== congregationId) {
    throw notFoundError("Enrollment not found.");
  }
  const classId = nonEmpty(enrollment.classId);
  if (classId === null) {
    throw notFoundError("Enrollment is missing its class.");
  }
  const studentId = nonEmpty(enrollment.studentId) ?? "";

  const index = await datastore.read(sessionIndexPath(congregationId, classId));
  const sessionIds = Array.isArray(index?.sessionIds)
    ? (index?.sessionIds as unknown[]).filter(
        (value): value is string => typeof value === "string",
      )
    : [];

  let present = 0;
  let absent = 0;
  let excused = 0;
  for (const sessionId of sessionIds) {
    const session = await datastore.read(sessionPath(congregationId, sessionId));
    if (session === null || session.status !== SessionStatus.finalized) continue;

    let containsEnrollment = rosterIdsFromSession(session).includes(
      input.enrollmentId,
    );
    if (!containsEnrollment) {
      // Defensive: a session document without the denormalized index still
      // resolves membership from the roster subcollection.
      const roster = await readRoster(datastore, congregationId, sessionId);
      containsEnrollment = roster.some(
        (entry) => String(entry.enrollmentId) === input.enrollmentId,
      );
    }
    if (!containsEnrollment) continue;

    const attendance = await datastore.read(
      attendanceEntryPath(congregationId, sessionId, input.enrollmentId),
    );
    const status = nonEmpty(attendance?.status);
    if (status === AttendanceStatus.present) present += 1;
    else if (status === AttendanceStatus.absent) absent += 1;
    else if (status === AttendanceStatus.excused) excused += 1;
  }

  const total = present + absent;
  const percentage = total > 0 ? Math.round((present / total) * 100) : null;
  return {
    enrollmentId: input.enrollmentId,
    studentId,
    classId,
    present,
    absent,
    excused,
    total,
    percentage,
  };
}
