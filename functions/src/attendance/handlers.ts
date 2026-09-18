/**
 * Callable wrappers for attendance and progress operations (S11).
 *
 * Thin transport layer: it extracts the authenticated UID and forwards the
 * payload to the injectable services. Scope authorization, validation and
 * transactional writes stay in the services.
 */
import { defineCallable } from "../core/callable";
import { Clock } from "../core/clock";
import { Datastore } from "../core/datastore";
import { AppError } from "../core/errors";
import {
  GetEnrollmentProgressInput,
  getEnrollmentProgress,
} from "./progress";
import { ClassEnrollmentReader } from "./roster";
import {
  GetSessionAttendanceInput,
  SaveAttendanceInput,
  getSessionAttendance,
  saveAttendance,
} from "./service";

export interface AttendanceHandlerDependencies {
  datastore: Datastore;
  clock: Clock;
  enrollments: ClassEnrollmentReader;
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

export function saveAttendanceCallable(deps: AttendanceHandlerDependencies) {
  return defineCallable(async (data, request) =>
    saveAttendance(
      deps.datastore,
      deps.clock,
      {
        ...payloadOf(data),
        uid: requireUid(request),
      } as unknown as SaveAttendanceInput,
      deps.enrollments,
    ),
  );
}

export function getSessionAttendanceCallable(deps: AttendanceHandlerDependencies) {
  return defineCallable(async (data, request) =>
    getSessionAttendance(deps.datastore, {
      ...payloadOf(data),
      uid: requireUid(request),
    } as unknown as GetSessionAttendanceInput),
  );
}

export function getEnrollmentProgressCallable(deps: AttendanceHandlerDependencies) {
  return defineCallable(async (data, request) =>
    getEnrollmentProgress(deps.datastore, {
      ...payloadOf(data),
      uid: requireUid(request),
    } as unknown as GetEnrollmentProgressInput),
  );
}
