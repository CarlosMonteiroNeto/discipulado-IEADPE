import { randomUUID } from "node:crypto";
import { describe, expect, it } from "vitest";
import {
  InMemoryClassSessionReader,
  saveClass,
  setClassStatus,
} from "../../src/classes/service";
import { fixedClock } from "../../src/core/clock";
import { InMemoryDatastore, JsonMap, paths } from "../../src/core/datastore";
import { AppError } from "../../src/core/errors";
import {
  scopeReferencePath,
  setCongregationArchived,
} from "../../src/congregations/service";
import { teacherClassReferencePath } from "../../src/contacts/role_slots";
import { closeEnrollment, enrollStudent } from "../../src/enrollments/service";
import { saveStudent } from "../../src/students/service";

const TIMESTAMP = "2026-09-18T12:00:00.000Z";
const clock = fixedClock(new Date(TIMESTAMP));

function seedDatastore(): InMemoryDatastore {
  return new InMemoryDatastore({
    [paths.user("sup1")]: {
      accessRole: "supervisor",
      congregationId: null,
      active: true,
      revision: 1,
      updatedAt: TIMESTAMP,
    },
    [paths.user("staff1")]: {
      accessRole: "congregationStaff",
      congregationId: "c1",
      active: true,
      revision: 1,
      updatedAt: TIMESTAMP,
    },
    [paths.user("staff2")]: {
      accessRole: "congregationStaff",
      congregationId: "c2",
      active: true,
      revision: 1,
      updatedAt: TIMESTAMP,
    },
    [paths.user("inactive1")]: {
      accessRole: "congregationStaff",
      congregationId: "c1",
      active: false,
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
    [paths.congregation("c2")]: {
      id: "c2",
      name: "Norte",
      normalizedName: "norte",
      active: true,
      revision: 1,
    },
    [paths.contact("c1", "t1")]: {
      id: "t1",
      name: "Professor A",
      normalizedName: "professor a",
      scope: "congregation",
      congregationId: "c1",
      roleCode: "teacher",
      phoneE164: null,
      birthDate: null,
      archived: false,
      revision: 1,
      createdAt: TIMESTAMP,
      updatedAt: TIMESTAMP,
      updatedBy: "sup1",
    },
    [paths.contact("c2", "t2")]: {
      id: "t2",
      name: "Professor B",
      normalizedName: "professor b",
      scope: "congregation",
      congregationId: "c2",
      roleCode: "teacher",
      phoneE164: null,
      birthDate: null,
      archived: false,
      revision: 1,
      createdAt: TIMESTAMP,
      updatedAt: TIMESTAMP,
      updatedBy: "sup1",
    },
    [paths.contact("c1", "t3")]: {
      id: "t3",
      name: "Professor Inativo",
      normalizedName: "professor inativo",
      scope: "congregation",
      congregationId: "c1",
      roleCode: "teacher",
      phoneE164: null,
      birthDate: null,
      archived: true,
      revision: 1,
      createdAt: TIMESTAMP,
      updatedAt: TIMESTAMP,
      updatedBy: "sup1",
    },
    [paths.contact("c1", "n1")]: {
      id: "n1",
      name: "Secretária",
      normalizedName: "secretaria",
      scope: "congregation",
      congregationId: "c1",
      roleCode: "congregationAssistant",
      phoneE164: null,
      birthDate: null,
      archived: false,
      revision: 1,
      createdAt: TIMESTAMP,
      updatedAt: TIMESTAMP,
      updatedBy: "sup1",
    },
  });
}

function emptyReader(): InMemoryClassSessionReader {
  return new InMemoryClassSessionReader();
}

function classInput(
  id: string,
  overrides: Record<string, unknown> = {},
): Parameters<typeof saveClass>[2] {
  return {
    uid: "sup1",
    requestId: randomUUID(),
    id,
    congregationId: "c1",
    name: "Discipulado Jovens",
    teacherContactId: "t1",
    startDate: "2026-03-01",
    endDate: "2026-11-30",
    ...overrides,
  } as unknown as Parameters<typeof saveClass>[2];
}

async function expectAppError(run: () => Promise<unknown>): Promise<AppError> {
  try {
    await run();
  } catch (error) {
    expect(error).toBeInstanceOf(AppError);
    return error as AppError;
  }
  throw new Error("expected an AppError to be thrown");
}

function storedClass(
  datastore: InMemoryDatastore,
  classId: string,
): Promise<JsonMap | null> {
  return datastore.read(paths.classGroup("c1", classId));
}

describe("saveClass", () => {
  it("creates an active class with an eligible teacher and its counters", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    const input = classInput(id);

    const result = await saveClass(datastore, clock, input, emptyReader());
    expect(result).toEqual({ id, revision: 1 });

    const stored = await storedClass(datastore, id);
    expect(stored?.id).toBe(id);
    expect(stored?.congregationId).toBe("c1");
    expect(stored?.name).toBe("Discipulado Jovens");
    expect(stored?.normalizedName).toBe("discipulado jovens");
    expect(stored?.teacherContactId).toBe("t1");
    expect(stored?.startDate).toBe("2026-03-01");
    expect(stored?.endDate).toBe("2026-11-30");
    expect(stored?.status).toBe("active");
    expect(stored?.enrollmentCount).toBe(0);
    expect(stored?.activeEnrollmentCount).toBe(0);
    expect(stored?.revision).toBe(1);
    expect(stored?.createdAt).toBe(TIMESTAMP);
    expect(stored?.updatedAt).toBe(TIMESTAMP);
    expect(stored?.updatedBy).toBe("sup1");

    const teacherRef = await datastore.read(
      teacherClassReferencePath("c1", "t1"),
    );
    expect(teacherRef?.activeClassCount).toBe(1);

    const references = await datastore.read(scopeReferencePath("c1"));
    expect(references?.activeClasses).toBe(1);

    const receipt = await datastore.read(paths.receipt("sup1", input.requestId));
    expect(receipt?.operation).toBe("saveClass");
    expect(receipt?.result).toEqual({ id, revision: 1 });
  });

  it("rejects a teacher who is not a local active teacher contact", async () => {
    const candidates = ["t2", "t3", "n1", "ghost"];
    for (const teacherContactId of candidates) {
      const datastore = seedDatastore();
      const id = randomUUID();

      const error = await expectAppError(() =>
        saveClass(
          datastore,
          clock,
          classInput(id, { teacherContactId }),
          emptyReader(),
        ),
      );
      expect(error.code).toBe("conflict");
      expect(await storedClass(datastore, id)).toBeNull();
      expect(
        await datastore.read(teacherClassReferencePath("c1", teacherContactId)),
      ).toBeNull();
    }
  });

  it("rejects an end date before the start date", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();

    const error = await expectAppError(() =>
      saveClass(
        datastore,
        clock,
        classInput(id, { startDate: "2026-06-01", endDate: "2026-05-31" }),
        emptyReader(),
      ),
    );
    expect(error.code).toBe("validation");
    expect(await storedClass(datastore, id)).toBeNull();
  });

  it("denies staff cross-scope, inactive profiles and missing profiles", async () => {
    const datastore = seedDatastore();

    const crossScope = await expectAppError(() =>
      saveClass(
        datastore,
        clock,
        classInput(randomUUID(), {
          uid: "staff1",
          congregationId: "c2",
        }),
        emptyReader(),
      ),
    );
    expect(crossScope.code).toBe("forbidden");

    const inactive = await expectAppError(() =>
      saveClass(
        datastore,
        clock,
        classInput(randomUUID(), { uid: "inactive1" }),
        emptyReader(),
      ),
    );
    expect(inactive.code).toBe("forbidden");

    const anonymous = await expectAppError(() =>
      saveClass(
        datastore,
        clock,
        classInput(randomUUID(), { uid: "ghost" }),
        emptyReader(),
      ),
    );
    expect(anonymous.code).toBe("forbidden");
  });

  it("renames a class while active without changing its identity", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    await saveClass(datastore, clock, classInput(id), emptyReader());
    const created = await storedClass(datastore, id);

    const result = await saveClass(
      datastore,
      clock,
      classInput(id, { name: "Discipulado Adultos", expectedRevision: 1 }),
      emptyReader(),
    );
    expect(result).toEqual({ id, revision: 2 });

    const stored = await storedClass(datastore, id);
    expect(stored?.id).toBe(id);
    expect(stored?.createdAt).toBe(created?.createdAt);
    expect(stored?.name).toBe("Discipulado Adultos");
    expect(stored?.normalizedName).toBe("discipulado adultos");
    expect(stored?.startDate).toBe("2026-03-01");
    expect(stored?.revision).toBe(2);
  });

  it("rejects editing or reopening a completed or archived class", async () => {
    const datastore = seedDatastore();
    const classId = randomUUID();
    await saveClass(datastore, clock, classInput(classId), emptyReader());
    await setClassStatus(
      datastore,
      clock,
      {
        uid: "sup1",
        requestId: randomUUID(),
        id: classId,
        congregationId: "c1",
        status: "completed",
        expectedRevision: 1,
      },
      emptyReader(),
    );

    const editCompleted = await expectAppError(() =>
      saveClass(
        datastore,
        clock,
        classInput(classId, { name: "Editada", expectedRevision: 2 }),
        emptyReader(),
      ),
    );
    expect(editCompleted.code).toBe("conflict");

    const reopenActive = await expectAppError(() =>
      setClassStatus(
        datastore,
        clock,
        {
          uid: "sup1",
          requestId: randomUUID(),
          id: classId,
          congregationId: "c1",
          status: "active",
          expectedRevision: 2,
        },
        emptyReader(),
      ),
    );
    expect(reopenActive.code).toBe("conflict");

    await setClassStatus(
      datastore,
      clock,
      {
        uid: "sup1",
        requestId: randomUUID(),
        id: classId,
        congregationId: "c1",
        status: "archived",
        expectedRevision: 2,
      },
      emptyReader(),
    );
    const editArchived = await expectAppError(() =>
      saveClass(
        datastore,
        clock,
        classInput(classId, { name: "Editada", expectedRevision: 3 }),
        emptyReader(),
      ),
    );
    expect(editArchived.code).toBe("conflict");

    const reopenArchivedCompleted = await expectAppError(() =>
      setClassStatus(
        datastore,
        clock,
        {
          uid: "sup1",
          requestId: randomUUID(),
          id: classId,
          congregationId: "c1",
          status: "completed",
          expectedRevision: 3,
        },
        emptyReader(),
      ),
    );
    expect(reopenArchivedCompleted.code).toBe("conflict");
  });

  it("does not change class dates once an enrollment exists", async () => {    const datastore = seedDatastore();
    const classId = randomUUID();
    const studentId = randomUUID();
    await saveClass(datastore, clock, classInput(classId), emptyReader());
    await saveStudent(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id: studentId,
      congregationId: "c1",
      name: "Aluno",
    });
    await enrollStudent(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id: randomUUID(),
      congregationId: "c1",
      classId,
      studentId,
      startDate: "2026-03-05",
    }, emptyReader());

    const changed = await expectAppError(() =>
      saveClass(
        datastore,
        clock,
        classInput(classId, { startDate: "2026-04-01", expectedRevision: 1 }),
        emptyReader(),
      ),
    );
    expect(changed.code).toBe("conflict");
    expect((await storedClass(datastore, classId))?.startDate).toBe("2026-03-01");

    const renamed = await saveClass(
      datastore,
      clock,
      classInput(classId, { name: "Turma Renomeada", expectedRevision: 1 }),
      emptyReader(),
    );
    expect(renamed).toEqual({ id: classId, revision: 2 });
  });

  it("does not change class dates once a session exists", async () => {
    const datastore = seedDatastore();
    const classId = randomUUID();
    await saveClass(datastore, clock, classInput(classId), emptyReader());
    const reader = new InMemoryClassSessionReader({
      sessions: [
        {
          id: "sess1",
          congregationId: "c1",
          classId,
          date: "2026-03-10",
          status: "finalized",
          rosterFrozen: true,
        },
      ],
    });

    const changed = await expectAppError(() =>
      saveClass(
        datastore,
        clock,
        classInput(classId, { endDate: "2026-12-15", expectedRevision: 1 }),
        reader,
      ),
    );
    expect(changed.code).toBe("conflict");
    expect((await storedClass(datastore, classId))?.endDate).toBe("2026-11-30");
  });

  it("rejects a stale revision and replays an identical request", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    const createInput = classInput(id);

    const first = await saveClass(datastore, clock, createInput, emptyReader());
    const replay = await saveClass(datastore, clock, createInput, emptyReader());
    expect(replay).toEqual(first);
    expect((await storedClass(datastore, id))?.revision).toBe(1);

    await saveClass(
      datastore,
      clock,
      classInput(id, { name: "Primeira edição", expectedRevision: 1 }),
      emptyReader(),
    );
    const stale = await expectAppError(() =>
      saveClass(
        datastore,
        clock,
        classInput(id, { name: "Perdedora", expectedRevision: 1 }),
        emptyReader(),
      ),
    );
    expect(stale.code).toBe("conflict");
    expect((await storedClass(datastore, id))?.name).toBe("Primeira edição");
  });
});

describe("setClassStatus", () => {
  it("blocks completion while an enrollment is active", async () => {
    const datastore = seedDatastore();
    const classId = randomUUID();
    const studentId = randomUUID();
    const enrollmentId = randomUUID();
    await saveClass(datastore, clock, classInput(classId), emptyReader());
    await saveStudent(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id: studentId,
      congregationId: "c1",
      name: "Aluno",
    });
    await enrollStudent(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id: enrollmentId,
      congregationId: "c1",
      classId,
      studentId,
      startDate: "2026-03-05",
    }, emptyReader());

    const blocked = await expectAppError(() =>
      setClassStatus(
        datastore,
        clock,
        {
          uid: "sup1",
          requestId: randomUUID(),
          id: classId,
          congregationId: "c1",
          status: "completed",
          expectedRevision: 1,
        },
        emptyReader(),
      ),
    );
    expect(blocked.code).toBe("conflict");
    expect((await storedClass(datastore, classId))?.status).toBe("active");

    await closeEnrollment(
      datastore,
      clock,
      {
        uid: "sup1",
        requestId: randomUUID(),
        id: enrollmentId,
        congregationId: "c1",
        status: "completed",
        endDate: "2026-06-30",
        expectedRevision: 1,
      },
      emptyReader(),
    );

    const completed = await setClassStatus(
      datastore,
      clock,
      {
        uid: "sup1",
        requestId: randomUUID(),
        id: classId,
        congregationId: "c1",
        status: "completed",
        expectedRevision: 1,
      },
      emptyReader(),
    );
    expect(completed).toEqual({ id: classId, revision: 2 });
    expect((await storedClass(datastore, classId))?.status).toBe("completed");
    const references = await datastore.read(scopeReferencePath("c1"));
    expect(references?.activeClasses).toBe(0);
    const teacherRef = await datastore.read(
      teacherClassReferencePath("c1", "t1"),
    );
    expect(teacherRef?.activeClassCount).toBe(0);
  });

  it("blocks completion while an open session exists", async () => {
    const datastore = seedDatastore();
    const classId = randomUUID();
    await saveClass(datastore, clock, classInput(classId), emptyReader());
    const reader = new InMemoryClassSessionReader({
      sessions: [
        {
          id: "sess1",
          congregationId: "c1",
          classId,
          date: "2026-03-10",
          status: "open",
          rosterFrozen: false,
        },
      ],
    });

    const blocked = await expectAppError(() =>
      setClassStatus(
        datastore,
        clock,
        {
          uid: "sup1",
          requestId: randomUUID(),
          id: classId,
          congregationId: "c1",
          status: "completed",
          expectedRevision: 1,
        },
        reader,
      ),
    );
    expect(blocked.code).toBe("conflict");
    expect((await storedClass(datastore, classId))?.status).toBe("active");
  });

  it("archives only empty active classes", async () => {
    const datastore = seedDatastore();
    const emptyClassId = randomUUID();
    await saveClass(datastore, clock, classInput(emptyClassId), emptyReader());

    const archived = await setClassStatus(
      datastore,
      clock,
      {
        uid: "sup1",
        requestId: randomUUID(),
        id: emptyClassId,
        congregationId: "c1",
        status: "archived",
        expectedRevision: 1,
      },
      emptyReader(),
    );
    expect(archived).toEqual({ id: emptyClassId, revision: 2 });
    expect((await storedClass(datastore, emptyClassId))?.status).toBe("archived");
    expect(
      (await datastore.read(scopeReferencePath("c1")))?.activeClasses,
    ).toBe(0);
    expect(
      (await datastore.read(teacherClassReferencePath("c1", "t1")))
        ?.activeClassCount,
    ).toBe(0);

    const busyClassId = randomUUID();
    const studentId = randomUUID();
    await saveClass(datastore, clock, classInput(busyClassId), emptyReader());
    await saveStudent(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id: studentId,
      congregationId: "c1",
      name: "Aluno Ocupado",
    });
    await enrollStudent(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id: randomUUID(),
      congregationId: "c1",
      classId: busyClassId,
      studentId,
      startDate: "2026-03-05",
    }, emptyReader());

    const blocked = await expectAppError(() =>
      setClassStatus(
        datastore,
        clock,
        {
          uid: "sup1",
          requestId: randomUUID(),
          id: busyClassId,
          congregationId: "c1",
          status: "archived",
          expectedRevision: 1,
        },
        emptyReader(),
      ),
    );
    expect(blocked.code).toBe("conflict");
    expect((await storedClass(datastore, busyClassId))?.status).toBe("active");
  });

  it("archives a completed class without reopening it", async () => {
    const datastore = seedDatastore();
    const classId = randomUUID();
    await saveClass(datastore, clock, classInput(classId), emptyReader());
    await setClassStatus(
      datastore,
      clock,
      {
        uid: "sup1",
        requestId: randomUUID(),
        id: classId,
        congregationId: "c1",
        status: "completed",
        expectedRevision: 1,
      },
      emptyReader(),
    );

    const reopen = await expectAppError(() =>
      setClassStatus(
        datastore,
        clock,
        {
          uid: "sup1",
          requestId: randomUUID(),
          id: classId,
          congregationId: "c1",
          status: "active",
          expectedRevision: 2,
        },
        emptyReader(),
      ),
    );
    expect(reopen.code).toBe("conflict");
    expect((await storedClass(datastore, classId))?.status).toBe("completed");

    const archived = await setClassStatus(
      datastore,
      clock,
      {
        uid: "sup1",
        requestId: randomUUID(),
        id: classId,
        congregationId: "c1",
        status: "archived",
        expectedRevision: 2,
      },
      emptyReader(),
    );
    expect(archived).toEqual({ id: classId, revision: 3 });
    expect((await storedClass(datastore, classId))?.status).toBe("archived");
    expect(
      (await datastore.read(scopeReferencePath("c1")))?.activeClasses,
    ).toBe(0);
  });

  it("reactivates an archived class and restores its references", async () => {
    const datastore = seedDatastore();
    const classId = randomUUID();
    await saveClass(datastore, clock, classInput(classId), emptyReader());
    await setClassStatus(
      datastore,
      clock,
      {
        uid: "sup1",
        requestId: randomUUID(),
        id: classId,
        congregationId: "c1",
        status: "archived",
        expectedRevision: 1,
      },
      emptyReader(),
    );

    const reactivated = await setClassStatus(
      datastore,
      clock,
      {
        uid: "sup1",
        requestId: randomUUID(),
        id: classId,
        congregationId: "c1",
        status: "active",
        expectedRevision: 2,
      },
      emptyReader(),
    );
    expect(reactivated).toEqual({ id: classId, revision: 3 });
    expect((await storedClass(datastore, classId))?.status).toBe("active");
    expect(
      (await datastore.read(scopeReferencePath("c1")))?.activeClasses,
    ).toBe(1);
    expect(
      (await datastore.read(teacherClassReferencePath("c1", "t1")))
        ?.activeClassCount,
    ).toBe(1);
  });

  it("blocks congregation archiving until the real class lifecycle runs", async () => {
    const datastore = seedDatastore();
    const classId = randomUUID();
    await saveClass(datastore, clock, classInput(classId), emptyReader());

    const blocked = await expectAppError(() =>
      setCongregationArchived(datastore, clock, {
        uid: "sup1",
        requestId: randomUUID(),
        id: "c1",
        archived: true,
        expectedRevision: 1,
      }),
    );
    expect(blocked.code).toBe("conflict");

    await setClassStatus(
      datastore,
      clock,
      {
        uid: "sup1",
        requestId: randomUUID(),
        id: classId,
        congregationId: "c1",
        status: "archived",
        expectedRevision: 1,
      },
      emptyReader(),
    );

    const allowed = await setCongregationArchived(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id: "c1",
      archived: true,
      expectedRevision: 1,
    });
    expect(allowed).toEqual({ id: "c1", revision: 2 });
    expect((await datastore.read(paths.congregation("c1")))?.active).toBe(false);
  });
});
