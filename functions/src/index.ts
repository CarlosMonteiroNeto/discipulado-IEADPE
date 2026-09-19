/**
 * Sole callable registration point (S11).
 *
 * Every S11 operation is exported exactly once, each built by its feature
 * handler factory over one Firestore Admin datastore and the system clock.
 * Trusted provisioning is deliberately absent: no callable may grant access
 * roles (S04).
 */
import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import type { DocumentData, Query } from "firebase-admin/firestore";

import { systemClock } from "./core/clock";
import {
  Datastore,
  JsonMap,
  Transaction,
} from "./core/datastore";
import { conflictError, notFoundError } from "./core/errors";
import {
  AttendanceHandlerDependencies,
  getEnrollmentProgressCallable,
  getSessionAttendanceCallable,
  saveAttendanceCallable,
} from "./attendance/handlers";
import {
  ClassHandlerDependencies,
  saveClassCallable,
  setClassStatusCallable,
} from "./classes/handlers";
import {
  CongregationHandlerDependencies,
  saveCongregationCallable,
  setCongregationArchivedCallable,
} from "./congregations/handlers";
import {
  ContactHandlerDependencies,
  replaceRoleHolderCallable,
  saveContactCallable,
  setContactArchivedCallable,
} from "./contacts/handlers";
import {
  EnrollmentHandlerDependencies,
  closeEnrollmentCallable,
  enrollStudentCallable,
} from "./enrollments/handlers";
import {
  OverviewHandlerDependencies,
  getOverviewCallable,
  listPendingSessionsCallable,
} from "./overview/handlers";
import type {
  OpenSessionCountQuery,
  OverviewQueryReader,
  PendingSessionQuery,
} from "./overview/service";
import {
  SessionHandlerDependencies,
  cancelSessionCallable,
  createSessionCallable,
} from "./sessions/handlers";
import {
  StudentHandlerDependencies,
  listClassStudentsCallable,
  saveStudentCallable,
  setStudentArchivedCallable,
} from "./students/handlers";

if (getApps().length === 0) {
  initializeApp();
}

const firestore = getFirestore();

function toJsonMap(data: DocumentData): JsonMap {
  return { ...data } as JsonMap;
}

/** Firestore-backed [Datastore] using Admin SDK transactions. */
class FirestoreDatastore implements Datastore {
  async read(path: string): Promise<JsonMap | null> {
    const snapshot = await firestore.doc(path).get();
    const data = snapshot.data();
    return data === undefined ? null : toJsonMap(data);
  }

  async write(path: string, data: JsonMap): Promise<void> {
    await firestore.doc(path).set(data);
  }

  async runTransaction<T>(work: (tx: Transaction) => Promise<T>): Promise<T> {
    return firestore.runTransaction(async (transaction) => {
      const tx: Transaction = {
        read: async (path: string): Promise<JsonMap | null> => {
          const snapshot = await transaction.get(firestore.doc(path));
          const data = snapshot.data();
          return data === undefined ? null : toJsonMap(data);
        },
        write: async (path: string, data: JsonMap): Promise<void> => {
          transaction.set(firestore.doc(path), data);
        },
        delete: async (path: string): Promise<void> => {
          transaction.delete(firestore.doc(path));
        },
        createStable: async (path: string, data: JsonMap): Promise<void> => {
          const snapshot = await transaction.get(firestore.doc(path));
          if (snapshot.exists) {
            throw conflictError(`Record already exists at ${path}.`);
          }
          transaction.set(firestore.doc(path), data);
        },
        updateWithRevision: async (
          path: string,
          expectedRevision: number,
          mutate: (current: JsonMap) => JsonMap,
        ): Promise<JsonMap> => {
          const snapshot = await transaction.get(firestore.doc(path));
          if (!snapshot.exists) {
            throw notFoundError(`Record not found at ${path}.`);
          }
          const current = toJsonMap(snapshot.data() ?? {});
          const currentRevision = Number(current.revision);
          if (currentRevision !== expectedRevision) {
            throw conflictError("The record changed since it was loaded.");
          }
          const next = mutate(current);
          next.revision = expectedRevision + 1;
          transaction.set(firestore.doc(path), next);
          return next;
        },
      };
      return work(tx);
    });
  }
}

/** Scoped overview reads over Firestore collections (S09). */
class FirestoreOverviewReader implements OverviewQueryReader {
  async countUnarchivedStudents(
    congregationId: string | null,
  ): Promise<number> {
    return this.count(
      this.scopeFilter(
        firestore
          .collectionGroup("students")
          .where("archived", "==", false),
        congregationId,
      ),
    );
  }

  async countActiveClasses(congregationId: string | null): Promise<number> {
    return this.count(
      this.scopeFilter(
        firestore.collectionGroup("classes").where("status", "==", "active"),
        congregationId,
      ),
    );
  }

  async countOpenSessions(query: OpenSessionCountQuery): Promise<number> {
    return this.count(this.openSessionsQuery(query));
  }

  async listOpenSessions(query: PendingSessionQuery): Promise<JsonMap[]> {
    let request: Query = this.openSessionsQuery(query)
      .orderBy("date")
      .orderBy("id")
      .limit(query.limit);
    if (query.after !== undefined) {
      request = request.startAfter(query.after.date, query.after.id);
    }
    const snapshot = await request.get();
    return snapshot.docs.map(
      (document) => ({ id: document.id, ...document.data() }) as JsonMap,
    );
  }

  private openSessionsQuery(
    query: OpenSessionCountQuery,
  ): Query {
    return this.scopeFilter(
      firestore
        .collectionGroup("sessions")
        .where("status", "==", "open")
        .where("date", "<=", query.throughDate),
      query.congregationId,
    );
  }

  private scopeFilter(query: Query, congregationId: string | null): Query {
    return congregationId === null
      ? query
      : query.where("congregationId", "==", congregationId);
  }

  private async count(query: Query): Promise<number> {
    const snapshot = await query.count().get();
    return snapshot.data().count;
  }
}

const datastore = new FirestoreDatastore();
const clock = systemClock;
const reader = new FirestoreOverviewReader();

const congregationDependencies: CongregationHandlerDependencies = {
  datastore,
  clock,
};
const contactDependencies: ContactHandlerDependencies = { datastore, clock };
const studentDependencies: StudentHandlerDependencies = { datastore, clock };
const classDependencies: ClassHandlerDependencies = { datastore, clock };
const enrollmentDependencies: EnrollmentHandlerDependencies = {
  datastore,
  clock,
};
const sessionDependencies: SessionHandlerDependencies = { datastore, clock };
const attendanceDependencies: AttendanceHandlerDependencies = {
  datastore,
  clock,
};
const overviewDependencies: OverviewHandlerDependencies = {
  datastore,
  clock,
  reader,
};

export const saveCongregation = saveCongregationCallable(
  congregationDependencies,
);
export const setCongregationArchived = setCongregationArchivedCallable(
  congregationDependencies,
);
export const saveContact = saveContactCallable(contactDependencies);
export const replaceRoleHolder = replaceRoleHolderCallable(contactDependencies);
export const setContactArchived = setContactArchivedCallable(
  contactDependencies,
);
export const saveStudent = saveStudentCallable(studentDependencies);
export const setStudentArchived = setStudentArchivedCallable(
  studentDependencies,
);
export const listClassStudents = listClassStudentsCallable(
  studentDependencies,
);
export const saveClass = saveClassCallable(classDependencies);
export const setClassStatus = setClassStatusCallable(classDependencies);
export const enrollStudent = enrollStudentCallable(enrollmentDependencies);
export const closeEnrollment = closeEnrollmentCallable(enrollmentDependencies);
export const createSession = createSessionCallable(sessionDependencies);
export const cancelSession = cancelSessionCallable(sessionDependencies);
export const saveAttendance = saveAttendanceCallable(attendanceDependencies);
export const getSessionAttendance = getSessionAttendanceCallable(
  attendanceDependencies,
);
export const getEnrollmentProgress = getEnrollmentProgressCallable(
  attendanceDependencies,
);
export const getOverview = getOverviewCallable(overviewDependencies);
export const listPendingSessions = listPendingSessionsCallable(
  overviewDependencies,
);
