import { randomUUID } from "node:crypto";
import { describe, expect, it } from "vitest";
import { fixedClock } from "../../src/core/clock";
import {
  Datastore,
  InMemoryDatastore,
  JsonMap,
  Transaction,
  paths,
} from "../../src/core/datastore";
import { scopeReferencePath } from "../../src/congregations/service";
import { saveStudent, setStudentArchived } from "../../src/students/service";

/**
 * Fault-injection rollback coverage (S11, S12, S13).
 *
 * Each test wraps the real InMemoryDatastore in a double that delegates every
 * read and staged write and throws exactly when the transaction writes the
 * `congregations/{id}/internal/references` document after a student write has
 * already been staged. The failure therefore fires inside the production
 * `runCommand` transaction, after the paired student write and before commit.
 * The double never owns state and never bypasses the production transaction:
 * it only intercepts one write path on the real transaction. A green run proves
 * the student document, the reference counter and the receipt all roll back
 * together; the counter pre-failure value is always established by a prior
 * real service operation, never by seeding the internal document.
 */
const TIMESTAMP = "2026-09-18T12:00:00.000Z";
const clock = fixedClock(new Date(TIMESTAMP));

class ReferencesWriteFailure extends Error {}

class FaultInjectingDatastore implements Datastore {
  constructor(
    private readonly inner: InMemoryDatastore,
    private readonly congregationId: string,
  ) {}

  read(path: string): Promise<JsonMap | null> {
    return this.inner.read(path);
  }

  write(path: string, data: JsonMap): Promise<void> {
    return this.inner.write(path, data);
  }

  runTransaction<T>(work: (tx: Transaction) => Promise<T>): Promise<T> {
    const referencesPath = scopeReferencePath(this.congregationId);
    const studentPrefix = `congregations/${this.congregationId}/students/`;
    return this.inner.runTransaction(async (tx) => {
      let studentWriteStaged = false;
      const wrapped: Transaction = {
        read: (path) => tx.read(path),
        write: async (path, data) => {
          if (path === referencesPath && studentWriteStaged) {
            throw new ReferencesWriteFailure(
              "injected failure writing the reference counter",
            );
          }
          await tx.write(path, data);
        },
        delete: (path) => tx.delete(path),
        createStable: async (path, data) => {
          if (path.startsWith(studentPrefix)) studentWriteStaged = true;
          await tx.createStable(path, data);
        },
        updateWithRevision: async (path, expectedRevision, mutate) => {
          if (path.startsWith(studentPrefix)) studentWriteStaged = true;
          return tx.updateWithRevision(path, expectedRevision, mutate);
        },
      };
      return work(wrapped);
    });
  }
}

function seedDatastore(): InMemoryDatastore {
  return new InMemoryDatastore({
    [paths.user("sup1")]: {
      accessRole: "supervisor",
      congregationId: null,
      active: true,
      revision: 1,
      updatedAt: TIMESTAMP,
    },
    [paths.congregation("c1")]: {
      id: "c1",
      name: "Central",
      normalizedName: "central",
      active: true,
      revision: 1,
    },
  });
}

async function createThrough(
  datastore: InMemoryDatastore,
  name: string,
): Promise<string> {
  const id = randomUUID();
  await saveStudent(datastore, clock, {
    uid: "sup1",
    requestId: randomUUID(),
    id,
    congregationId: "c1",
    name,
  });
  return id;
}

async function expectAppError(run: () => Promise<unknown>): Promise<unknown> {
  try {
    await run();
  } catch (error) {
    return error;
  }
  throw new Error("expected the operation to reject");
}

describe("student and counter write atomicity", () => {
  it("rolls back a create so no student, counter change or receipt remains", async () => {
    const inner = seedDatastore();
    const existingId = await createThrough(inner, "Existente");
    const referenceBefore = await inner.read(scopeReferencePath("c1"));
    expect(referenceBefore).toEqual({
      activeUsers: 0,
      unarchivedStudents: 1,
      unarchivedContacts: 0,
      activeClasses: 0,
    });

    const injected = new FaultInjectingDatastore(inner, "c1");
    const id = randomUUID();
    const requestId = randomUUID();

    const error = await expectAppError(() =>
      saveStudent(injected, clock, {
        uid: "sup1",
        requestId,
        id,
        congregationId: "c1",
        name: "Descartada",
      }),
    );
    expect(error).toBeInstanceOf(ReferencesWriteFailure);

    expect(await inner.read(paths.student("c1", id))).toBeNull();
    expect(await inner.read(scopeReferencePath("c1"))).toEqual(referenceBefore);
    expect(await inner.read(paths.receipt("sup1", requestId))).toBeNull();
    expect(await inner.read(paths.student("c1", existingId))).not.toBeNull();
  });

  it("rolls back an archive so the student stays unarchived and the count is unchanged", async () => {
    const inner = seedDatastore();
    const id = await createThrough(inner, "Matriculada");
    const studentBefore = await inner.read(paths.student("c1", id));
    const referenceBefore = await inner.read(scopeReferencePath("c1"));

    const injected = new FaultInjectingDatastore(inner, "c1");
    const requestId = randomUUID();

    const error = await expectAppError(() =>
      setStudentArchived(injected, clock, {
        uid: "sup1",
        requestId,
        id,
        congregationId: "c1",
        archived: true,
        expectedRevision: 1,
      }),
    );
    expect(error).toBeInstanceOf(ReferencesWriteFailure);

    const after = await inner.read(paths.student("c1", id));
    expect(after).toEqual(studentBefore);
    expect(after?.archived).toBe(false);
    expect(after?.revision).toBe(1);
    expect(await inner.read(scopeReferencePath("c1"))).toEqual(referenceBefore);
    expect(await inner.read(paths.receipt("sup1", requestId))).toBeNull();
  });

  it("rolls back a restore so the student stays archived and the count is unchanged", async () => {
    const inner = seedDatastore();
    const id = await createThrough(inner, "Retornada");
    await setStudentArchived(inner, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id,
      congregationId: "c1",
      archived: true,
      expectedRevision: 1,
    });
    const studentBefore = await inner.read(paths.student("c1", id));
    expect(studentBefore?.archived).toBe(true);
    const referenceBefore = await inner.read(scopeReferencePath("c1"));
    expect((referenceBefore as JsonMap).unarchivedStudents).toBe(0);

    const injected = new FaultInjectingDatastore(inner, "c1");
    const requestId = randomUUID();

    const error = await expectAppError(() =>
      setStudentArchived(injected, clock, {
        uid: "sup1",
        requestId,
        id,
        congregationId: "c1",
        archived: false,
        expectedRevision: 2,
      }),
    );
    expect(error).toBeInstanceOf(ReferencesWriteFailure);

    const after = await inner.read(paths.student("c1", id));
    expect(after).toEqual(studentBefore);
    expect(after?.archived).toBe(true);
    expect(after?.revision).toBe(2);
    expect(await inner.read(scopeReferencePath("c1"))).toEqual(referenceBefore);
    expect(await inner.read(paths.receipt("sup1", requestId))).toBeNull();
  });
});
