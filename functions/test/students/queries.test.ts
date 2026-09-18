import { randomUUID } from "node:crypto";
import { describe, expect, it } from "vitest";
import { InMemoryDatastore, JsonMap, paths } from "../../src/core/datastore";
import { AppError } from "../../src/core/errors";
import {
  InMemoryStudentDirectory,
  listClassStudents,
} from "../../src/students/queries";

const TIMESTAMP = "2026-09-18T12:00:00.000Z";

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
    [paths.classGroup("c1", "k1")]: {
      id: "k1",
      congregationId: "c1",
      name: "Turma Central",
      status: "active",
      revision: 1,
    },
    [paths.classGroup("c1", "k2")]: {
      id: "k2",
      congregationId: "c1",
      name: "Outra Turma",
      status: "active",
      revision: 1,
    },
    [paths.classGroup("c2", "k3")]: {
      id: "k3",
      congregationId: "c2",
      name: "Turma Norte",
      status: "active",
      revision: 1,
    },
  });
}

function student(
  id: string,
  congregationId: string,
  name: string,
  overrides: JsonMap = {},
): JsonMap {
  return {
    id,
    name,
    normalizedName: name.trim().toLowerCase(),
    congregationId,
    phoneE164: null,
    birthDate: null,
    address: null,
    education: null,
    maritalStatus: null,
    newConvert: null,
    waterBaptized: null,
    wantsBaptism: null,
    archived: false,
    revision: 1,
    createdAt: TIMESTAMP,
    updatedAt: TIMESTAMP,
    updatedBy: "seed",
    ...overrides,
  };
}

function enrollment(
  id: string,
  congregationId: string,
  classId: string,
  studentId: string,
  status = "active",
): JsonMap {
  return {
    id,
    congregationId,
    classId,
    studentId,
    status,
    startDate: "2026-01-01",
    endDate: null,
    revision: 1,
    createdAt: TIMESTAMP,
    updatedAt: TIMESTAMP,
    updatedBy: "seed",
  };
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

describe("listClassStudents", () => {
  it("resolves active enrollment membership before listing students", async () => {
    const datastore = seedDatastore();
    const directory = new InMemoryStudentDirectory({
      students: [
        student("s1", "c1", "Ana"),
        student("s2", "c1", "Bruno"),
        student("s3", "c1", "Carla"),
      ],
      enrollments: [
        enrollment("e1", "c1", "k1", "s1", "active"),
        enrollment("e2", "c1", "k1", "s2", "withdrawn"),
        enrollment("e3", "c1", "k1", "s3", "active"),
      ],
    });

    const result = await listClassStudents(datastore, directory, {
      uid: "staff1",
      congregationId: "c1",
      classId: "k1",
    });

    expect(result.items.map((item) => item.id)).toEqual(["s1", "s3"]);
    expect(result.nextCursor).toBeNull();
  });

  it("finds matching members that lie beyond the first unfiltered page", async () => {
    const datastore = seedDatastore();
    const outsiders = Array.from({ length: 10 }, (_, index) =>
      student(`x${index}`, "c1", `Aluno ${String(index + 1).padStart(2, "0")}`),
    );
    const directory = new InMemoryStudentDirectory({
      students: [
        ...outsiders,
        student("z1", "c1", "Zuleica"),
        student("z2", "c1", "Zulmira"),
      ],
      enrollments: [
        enrollment("e1", "c1", "k1", "z1", "active"),
        enrollment("e2", "c1", "k1", "z2", "active"),
      ],
    });

    const result = await listClassStudents(datastore, directory, {
      uid: "staff1",
      congregationId: "c1",
      classId: "k1",
      limit: 10,
    });

    expect(result.items.map((item) => item.name)).toEqual([
      "Zuleica",
      "Zulmira",
    ]);
  });

  it("applies normalized prefix search to the class membership", async () => {
    const datastore = seedDatastore();
    const directory = new InMemoryStudentDirectory({
      students: [
        student("s1", "c1", "Ana"),
        student("s2", "c1", "Bruno"),
        student("s3", "c1", "Carla"),
      ],
      enrollments: [
        enrollment("e1", "c1", "k1", "s1", "active"),
        enrollment("e2", "c1", "k1", "s2", "active"),
        enrollment("e3", "c1", "k1", "s3", "active"),
      ],
    });

    const result = await listClassStudents(datastore, directory, {
      uid: "staff1",
      congregationId: "c1",
      classId: "k1",
      namePrefix: "Br",
    });

    expect(result.items.map((item) => item.id)).toEqual(["s2"]);
  });

  it("paginates ordered members with a cursor", async () => {
    const datastore = seedDatastore();
    const directory = new InMemoryStudentDirectory({
      students: [
        student("s1", "c1", "Ana"),
        student("s2", "c1", "Bia"),
        student("s3", "c1", "Caio"),
        student("s4", "c1", "Duda"),
        student("s5", "c1", "Eva"),
      ],
      enrollments: [
        enrollment("e1", "c1", "k1", "s1", "active"),
        enrollment("e2", "c1", "k1", "s2", "active"),
        enrollment("e3", "c1", "k1", "s3", "active"),
        enrollment("e4", "c1", "k1", "s4", "active"),
        enrollment("e5", "c1", "k1", "s5", "active"),
      ],
    });

    const first = await listClassStudents(datastore, directory, {
      uid: "staff1",
      congregationId: "c1",
      classId: "k1",
      limit: 2,
    });
    expect(first.items.map((item) => item.id)).toEqual(["s1", "s2"]);
    expect(first.nextCursor).toEqual(expect.any(String));

    const second = await listClassStudents(datastore, directory, {
      uid: "staff1",
      congregationId: "c1",
      classId: "k1",
      limit: 2,
      cursor: first.nextCursor,
    });
    expect(second.items.map((item) => item.id)).toEqual(["s3", "s4"]);
    expect(second.nextCursor).toEqual(expect.any(String));

    const third = await listClassStudents(datastore, directory, {
      uid: "staff1",
      congregationId: "c1",
      classId: "k1",
      limit: 2,
      cursor: second.nextCursor,
    });
    expect(third.items.map((item) => item.id)).toEqual(["s5"]);
    expect(third.nextCursor).toBeNull();
  });

  it("rejects cursor reuse after a class, search or scope change", async () => {
    const datastore = seedDatastore();
    const directory = new InMemoryStudentDirectory({
      students: [student("s1", "c1", "Ana"), student("s2", "c1", "Bia")],
      enrollments: [
        enrollment("e1", "c1", "k1", "s1", "active"),
        enrollment("e2", "c1", "k1", "s2", "active"),
      ],
    });

    const first = await listClassStudents(datastore, directory, {
      uid: "staff1",
      congregationId: "c1",
      classId: "k1",
      limit: 1,
    });
    const cursor = first.nextCursor as string;
    expect(cursor).toEqual(expect.any(String));

    const classChanged = await expectAppError(() =>
      listClassStudents(datastore, directory, {
        uid: "staff1",
        congregationId: "c1",
        classId: "k2",
        limit: 1,
        cursor,
      }),
    );
    expect(classChanged.code).toBe("conflict");

    const searchChanged = await expectAppError(() =>
      listClassStudents(datastore, directory, {
        uid: "staff1",
        congregationId: "c1",
        classId: "k1",
        namePrefix: "a",
        limit: 1,
        cursor,
      }),
    );
    expect(searchChanged.code).toBe("conflict");

    const scopeChanged = await expectAppError(() =>
      listClassStudents(datastore, directory, {
        uid: "sup1",
        congregationId: "c2",
        classId: "k3",
        limit: 1,
        cursor,
      }),
    );
    expect(scopeChanged.code).toBe("conflict");
  });

  it("never includes another congregation's students", async () => {
    const datastore = seedDatastore();
    const directory = new InMemoryStudentDirectory({
      students: [
        student("s1", "c1", "Ana"),
        student("s2", "c2", "Ana"),
      ],
      enrollments: [
        enrollment("e1", "c1", "k1", "s1", "active"),
        // A forged membership must not drag in a student from another scope.
        enrollment("e2", "c1", "k1", "s2", "active"),
      ],
    });

    const result = await listClassStudents(datastore, directory, {
      uid: "staff1",
      congregationId: "c1",
      classId: "k1",
    });

    expect(result.items.map((item) => item.id)).toEqual(["s1"]);
  });

  it("returns safe not-found or forbidden failures for unknown or out-of-scope classes", async () => {
    const datastore = seedDatastore();
    const directory = new InMemoryStudentDirectory();

    const unknown = await expectAppError(() =>
      listClassStudents(datastore, directory, {
        uid: "staff1",
        congregationId: "c1",
        classId: randomUUID(),
      }),
    );
    expect(unknown.code).toBe("notFound");

    const crossScope = await expectAppError(() =>
      listClassStudents(datastore, directory, {
        uid: "staff1",
        congregationId: "c2",
        classId: "k3",
      }),
    );
    expect(crossScope.code).toBe("forbidden");
  });

  it("returns list entries without private personal or religious fields", async () => {
    const datastore = seedDatastore();
    const directory = new InMemoryStudentDirectory({
      students: [
        student("s1", "c1", "Ana", {
          birthDate: "1990-05-04",
          address: { street: "Rua A" },
          waterBaptized: true,
        }),
      ],
      enrollments: [enrollment("e1", "c1", "k1", "s1", "active")],
    });

    const result = await listClassStudents(datastore, directory, {
      uid: "staff1",
      congregationId: "c1",
      classId: "k1",
    });

    expect(result.items).toHaveLength(1);
    const entry = result.items[0] as JsonMap;
    expect(Object.keys(entry).sort()).toEqual([
      "archived",
      "congregationId",
      "id",
      "name",
      "normalizedName",
      "revision",
    ]);
    expect(entry).not.toHaveProperty("birthDate");
    expect(entry).not.toHaveProperty("address");
    expect(entry).not.toHaveProperty("waterBaptized");
  });
});
