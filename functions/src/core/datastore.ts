/**
 * Datastore boundary and an atomic in-memory implementation (S05, S11).
 *
 * Core handlers depend on this narrow interface so they can be tested without
 * a live Firestore instance; the production adapter binds it to the Admin SDK.
 * Transactions buffer writes and commit only when the work function resolves,
 * which is the property the stale-revision and rollback guards rely on.
 */
import { conflictError, notFoundError } from "./errors";

export type JsonMap = Record<string, unknown>;

export interface Transaction {
  read(path: string): Promise<JsonMap | null>;
  write(path: string, data: JsonMap): Promise<void>;
  delete(path: string): Promise<void>;
  /** Create with a stable ID; an existing record is an unrelated conflict. */
  createStable(path: string, data: JsonMap): Promise<void>;
  /**
   * Optimistic update: a mismatched `expectedRevision` fails with `conflict`
   * and writes nothing.
   */
  updateWithRevision(
    path: string,
    expectedRevision: number,
    mutate: (current: JsonMap) => JsonMap,
  ): Promise<JsonMap>;
}

export interface Datastore {
  read(path: string): Promise<JsonMap | null>;
  write(path: string, data: JsonMap): Promise<void>;
  runTransaction<T>(work: (tx: Transaction) => Promise<T>): Promise<T>;
}

/** Canonical document paths; the single place collection names are spelled. */
export const paths = {
  user: (uid: string): string => `users/${uid}`,
  congregation: (congregationId: string): string =>
    `congregations/${congregationId}`,
  directory: (contactId: string): string => `directory/${contactId}`,
  supervisionContact: (contactId: string): string =>
    `supervisionContacts/${contactId}`,
  supervisionRoleSlot: (slotId: string): string =>
    `supervisionRoleSlots/${slotId}`,
  contact: (congregationId: string, contactId: string): string =>
    `congregations/${congregationId}/contacts/${contactId}`,
  student: (congregationId: string, studentId: string): string =>
    `congregations/${congregationId}/students/${studentId}`,
  classGroup: (congregationId: string, classId: string): string =>
    `congregations/${congregationId}/classes/${classId}`,
  enrollment: (congregationId: string, enrollmentId: string): string =>
    `congregations/${congregationId}/enrollments/${enrollmentId}`,
  session: (congregationId: string, sessionId: string): string =>
    `congregations/${congregationId}/sessions/${sessionId}`,
  receipt: (uid: string, requestId: string): string =>
    `operations/${uid}/receipts/${requestId}`,
} as const;

function clone<T>(value: T): T {
  return structuredClone(value);
}

export class InMemoryDatastore implements Datastore {
  private readonly documents = new Map<string, JsonMap>();

  constructor(seed: Record<string, JsonMap> = {}) {
    for (const [path, data] of Object.entries(seed)) {
      this.documents.set(path, clone(data));
    }
  }

  async read(path: string): Promise<JsonMap | null> {
    const data = this.documents.get(path);
    return data === undefined ? null : clone(data);
  }

  async write(path: string, data: JsonMap): Promise<void> {
    this.documents.set(path, clone(data));
  }

  async runTransaction<T>(work: (tx: Transaction) => Promise<T>): Promise<T> {
    const staged = new Map<string, JsonMap | null>();

    const readStaged = async (path: string): Promise<JsonMap | null> => {
      if (staged.has(path)) {
        const value = staged.get(path);
        return value === undefined || value === null ? null : clone(value);
      }
      return this.read(path);
    };

    const tx: Transaction = {
      read: readStaged,
      write: async (path, data) => {
        staged.set(path, clone(data));
      },
      delete: async (path) => {
        staged.set(path, null);
      },
      createStable: async (path, data) => {
        const existing = await readStaged(path);
        if (existing !== null) {
          throw conflictError(`Record already exists at ${path}.`);
        }
        staged.set(path, clone(data));
      },
      updateWithRevision: async (path, expectedRevision, mutate) => {
        const current = await readStaged(path);
        if (current === null) {
          throw notFoundError(`Record not found at ${path}.`);
        }
        const currentRevision = Number(current.revision);
        if (currentRevision !== expectedRevision) {
          throw conflictError("The record changed since it was loaded.");
        }
        const next = mutate(clone(current));
        next.revision = expectedRevision + 1;
        staged.set(path, clone(next));
        return next;
      },
    };

    const result = await work(tx);

    for (const [path, data] of staged) {
      if (data === null) {
        this.documents.delete(path);
      } else {
        this.documents.set(path, clone(data));
      }
    }
    return result;
  }
}
