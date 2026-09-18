/**
 * Callable wrappers for student operations (S11).
 *
 * Thin transport layer: it extracts the authenticated UID and forwards the
 * payload to the injectable service. Scope authorization, validation and
 * transactional writes stay in the service and query modules.
 */
import { defineCallable } from "../core/callable";
import { Clock } from "../core/clock";
import { Datastore } from "../core/datastore";
import { AppError } from "../core/errors";
import {
  ListClassStudentsInput,
  StudentQueryReader,
  listClassStudents,
} from "./queries";
import {
  SaveStudentInput,
  SetStudentArchivedInput,
  saveStudent,
  setStudentArchived,
} from "./service";

export interface StudentHandlerDependencies {
  datastore: Datastore;
  clock: Clock;
  directory: StudentQueryReader;
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

export function saveStudentCallable(deps: StudentHandlerDependencies) {
  return defineCallable(async (data, request) =>
    saveStudent(deps.datastore, deps.clock, {
      ...payloadOf(data),
      uid: requireUid(request),
    } as unknown as SaveStudentInput),
  );
}

export function setStudentArchivedCallable(deps: StudentHandlerDependencies) {
  return defineCallable(async (data, request) =>
    setStudentArchived(deps.datastore, deps.clock, {
      ...payloadOf(data),
      uid: requireUid(request),
    } as unknown as SetStudentArchivedInput),
  );
}

export function listClassStudentsCallable(deps: StudentHandlerDependencies) {
  return defineCallable(async (data, request) =>
    listClassStudents(deps.datastore, deps.directory, {
      ...payloadOf(data),
      uid: requireUid(request),
    } as unknown as ListClassStudentsInput),
  );
}
