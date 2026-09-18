import { randomUUID } from "node:crypto";
import { describe, expect, it } from "vitest";
import { fixedClock } from "../../src/core/clock";
import { InMemoryDatastore, JsonMap, paths } from "../../src/core/datastore";
import { AppError } from "../../src/core/errors";
import { setCongregationArchived } from "../../src/congregations/service";
import {
  activeEnrollmentReferencePath,
  saveStudent,
  setStudentArchived,
} from "../../src/students/service";

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
  });
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

function createInput(id: string, name: string): Parameters<typeof saveStudent>[2] {
  return {
    uid: "sup1",
    requestId: randomUUID(),
    id,
    congregationId: "c1",
    name,
  };
}

describe("saveStudent", () => {
  it("creates homonymous students with stable distinct identities", async () => {
    const datastore = seedDatastore();
    const firstId = randomUUID();
    const secondId = randomUUID();

    await saveStudent(datastore, clock, createInput(firstId, "Ana Souza"));
    await saveStudent(datastore, clock, createInput(secondId, "Ana Souza"));

    const first = await datastore.read(paths.student("c1", firstId));
    const second = await datastore.read(paths.student("c1", secondId));
    expect(first?.id).toBe(firstId);
    expect(second?.id).toBe(secondId);
    expect(first?.normalizedName).toBe("ana souza");
    expect(second?.normalizedName).toBe("ana souza");
    expect(first?.archived).toBe(false);
    expect(second?.archived).toBe(false);
    expect(first?.revision).toBe(1);
    expect(second?.revision).toBe(1);
  });

  it("requires only a name and stores unanswered optional fields as null", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();

    await saveStudent(datastore, clock, createInput(id, "Maria"));

    expect(await datastore.read(paths.student("c1", id))).toEqual({
      id,
      name: "Maria",
      normalizedName: "maria",
      congregationId: "c1",
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
      updatedBy: "sup1",
    });
  });

  it("accepts optional personal, contact, address and religious fields", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();

    await saveStudent(datastore, clock, {
      ...createInput(id, "José da Silva"),
      phone: "(81) 99999-8888",
      birthDate: "1990-05-04",
      education: "Ensino médio",
      maritalStatus: "Casado(a)",
      address: {
        street: "Rua A",
        district: "Boa Vista",
        city: "Recife",
        postalCode: "52011000",
        stateCode: "PE",
      },
      newConvert: true,
      waterBaptized: false,
      wantsBaptism: true,
    });

    const stored = await datastore.read(paths.student("c1", id));
    expect(stored?.phoneE164).toBe("+5581999998888");
    expect(stored?.birthDate).toBe("1990-05-04");
    expect(stored?.education).toBe("Ensino médio");
    expect(stored?.maritalStatus).toBe("Casado(a)");
    expect(stored?.address).toEqual({
      street: "Rua A",
      district: "Boa Vista",
      city: "Recife",
      postalCode: "52011000",
      stateCode: "PE",
    });
    expect(stored?.newConvert).toBe(true);
    expect(stored?.waterBaptized).toBe(false);
    expect(stored?.wantsBaptism).toBe(true);
  });

  it("rejects a student who is baptized and also wants baptism", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();

    const error = await expectAppError(() =>
      saveStudent(datastore, clock, {
        ...createInput(id, "Contraditório"),
        waterBaptized: true,
        wantsBaptism: true,
      }),
    );
    expect(error.code).toBe("validation");
    expect(await datastore.read(paths.student("c1", id))).toBeNull();
  });

  it("rejects optional values outside the S05 limits", async () => {
    const datastore = seedDatastore();

    const longEducation = await expectAppError(() =>
      saveStudent(datastore, clock, {
        ...createInput(randomUUID(), "Educação"),
        education: "x".repeat(81),
      }),
    );
    expect(longEducation.code).toBe("validation");

    const oldBirthDate = await expectAppError(() =>
      saveStudent(datastore, clock, {
        ...createInput(randomUUID(), "Antigo"),
        birthDate: "1899-12-31",
      }),
    );
    expect(oldBirthDate.code).toBe("validation");

    const futureBirthDate = await expectAppError(() =>
      saveStudent(datastore, clock, {
        ...createInput(randomUUID(), "Futuro"),
        birthDate: "2027-01-01",
      }),
    );
    expect(futureBirthDate.code).toBe("validation");

    const badPostalCode = await expectAppError(() =>
      saveStudent(datastore, clock, {
        ...createInput(randomUUID(), "CEP"),
        address: { postalCode: "123" },
      }),
    );
    expect(badPostalCode.code).toBe("validation");
  });

  it("rejects unknown fields instead of copying them into the record", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();

    const error = await expectAppError(() =>
      saveStudent(datastore, clock, {
        ...createInput(id, "Desconhecido"),
        nickname: "apelido",
      } as unknown as Parameters<typeof saveStudent>[2]),
    );
    expect(error.code).toBe("validation");
    expect(await datastore.read(paths.student("c1", id))).toBeNull();
  });

  it("renames a student without changing its ID or createdAt", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    await saveStudent(datastore, clock, createInput(id, "João"));
    const created = await datastore.read(paths.student("c1", id));

    await saveStudent(datastore, clock, {
      ...createInput(id, "João Silva"),
      expectedRevision: 1,
    });

    const renamed = await datastore.read(paths.student("c1", id));
    expect(renamed?.id).toBe(id);
    expect(renamed?.createdAt).toBe(created?.createdAt);
    expect(renamed?.name).toBe("João Silva");
    expect(renamed?.normalizedName).toBe("joao silva");
    expect(renamed?.revision).toBe(2);
  });

  it("cannot move a student to another congregation and leaves the record unchanged", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    await saveStudent(datastore, clock, createInput(id, "Moradora"));

    const error = await expectAppError(() =>
      saveStudent(datastore, clock, {
        ...createInput(id, "Moradora"),
        congregationId: "c2",
        expectedRevision: 1,
      }),
    );
    expect(error.code).toBe("notFound");

    const stored = await datastore.read(paths.student("c1", id));
    expect(stored?.congregationId).toBe("c1");
    expect(stored?.name).toBe("Moradora");
    expect(stored?.revision).toBe(1);
    expect(await datastore.read(paths.student("c2", id))).toBeNull();
  });

  it("rejects a stale revision without overwriting the newer edit", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    await saveStudent(datastore, clock, createInput(id, "Original"));
    await saveStudent(datastore, clock, {
      ...createInput(id, "Novo nome"),
      expectedRevision: 1,
    });

    const error = await expectAppError(() =>
      saveStudent(datastore, clock, {
        ...createInput(id, "Perdedor"),
        expectedRevision: 1,
      }),
    );
    expect(error.code).toBe("conflict");

    const stored = await datastore.read(paths.student("c1", id));
    expect(stored?.name).toBe("Novo nome");
    expect(stored?.revision).toBe(2);
  });

  it("replays an identical creation request idempotently", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    const requestId = randomUUID();
    const input = {
      uid: "sup1",
      requestId,
      id,
      congregationId: "c1",
      name: "Replay",
    };

    const first = await saveStudent(datastore, clock, input);
    const replay = await saveStudent(datastore, clock, input);

    expect(replay).toEqual(first);
    expect((await datastore.read(paths.student("c1", id)))?.revision).toBe(1);
  });

  it("forbids staff from creating or editing another congregation's student", async () => {
    const datastore = seedDatastore();
    const foreignId = randomUUID();
    await saveStudent(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id: foreignId,
      congregationId: "c2",
      name: "Alheia",
    });

    const create = await expectAppError(() =>
      saveStudent(datastore, clock, {
        uid: "staff1",
        requestId: randomUUID(),
        id: randomUUID(),
        congregationId: "c2",
        name: "Intrusa",
      }),
    );
    expect(create.code).toBe("forbidden");

    const edit = await expectAppError(() =>
      saveStudent(datastore, clock, {
        uid: "staff1",
        requestId: randomUUID(),
        id: foreignId,
        congregationId: "c2",
        expectedRevision: 1,
        name: "Intrusa",
      }),
    );
    expect(edit.code).toBe("forbidden");

    const foreign = await datastore.read(paths.student("c2", foreignId));
    expect(foreign?.name).toBe("Alheia");
    expect(foreign?.revision).toBe(1);
  });

  it("returns not-found for unknown IDs without creating a record", async () => {
    const datastore = seedDatastore();
    const unknownId = randomUUID();

    const edit = await expectAppError(() =>
      saveStudent(datastore, clock, {
        uid: "staff1",
        requestId: randomUUID(),
        id: unknownId,
        congregationId: "c1",
        expectedRevision: 1,
        name: "Inexistente",
      }),
    );
    expect(edit.code).toBe("notFound");

    const archive = await expectAppError(() =>
      setStudentArchived(datastore, clock, {
        uid: "staff1",
        requestId: randomUUID(),
        id: unknownId,
        congregationId: "c1",
        archived: true,
        expectedRevision: 1,
      }),
    );
    expect(archive.code).toBe("notFound");
    expect(await datastore.read(paths.student("c1", unknownId))).toBeNull();
  });
});

describe("setStudentArchived", () => {
  it("blocks archiving while an active enrollment exists and preserves history", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    await saveStudent(datastore, clock, createInput(id, "Matriculada"));
    const created = await datastore.read(paths.student("c1", id));
    await datastore.write(activeEnrollmentReferencePath("c1", id), {
      studentId: id,
      congregationId: "c1",
      enrollmentId: randomUUID(),
      classId: randomUUID(),
    });

    const error = await expectAppError(() =>
      setStudentArchived(datastore, clock, {
        uid: "sup1",
        requestId: randomUUID(),
        id,
        congregationId: "c1",
        archived: true,
        expectedRevision: 1,
      }),
    );
    expect(error.code).toBe("conflict");

    const stored = await datastore.read(paths.student("c1", id));
    expect(stored?.archived).toBe(false);
    expect(stored?.revision).toBe(1);
    expect(stored?.createdAt).toBe(created?.createdAt);
    expect(await datastore.read(activeEnrollmentReferencePath("c1", id))).not.toBeNull();
  });

  it("archives and restores with the existing ID and creation metadata", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    await saveStudent(datastore, clock, createInput(id, "Histórica"));
    const created = await datastore.read(paths.student("c1", id));

    const archived = await setStudentArchived(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id,
      congregationId: "c1",
      archived: true,
      expectedRevision: 1,
    });
    expect(archived).toEqual({ id, revision: 2 });
    const afterArchive = await datastore.read(paths.student("c1", id));
    expect(afterArchive?.archived).toBe(true);
    expect(afterArchive?.createdAt).toBe(created?.createdAt);

    const restored = await setStudentArchived(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id,
      congregationId: "c1",
      archived: false,
      expectedRevision: 2,
    });
    expect(restored).toEqual({ id, revision: 3 });
    const afterRestore = await datastore.read(paths.student("c1", id));
    expect(afterRestore?.archived).toBe(false);
    expect(afterRestore?.id).toBe(id);
    expect(afterRestore?.createdAt).toBe(created?.createdAt);
  });

  it("blocks archiving the congregation until the real student archive runs", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    await saveStudent(datastore, clock, createInput(id, "Dependente"));

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

    await setStudentArchived(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id,
      congregationId: "c1",
      archived: true,
      expectedRevision: 1,
    });

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

  it("re-blocks archiving the congregation after a real student restore", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    await saveStudent(datastore, clock, createInput(id, "Retornada"));
    await setStudentArchived(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id,
      congregationId: "c1",
      archived: true,
      expectedRevision: 1,
    });
    await setStudentArchived(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id,
      congregationId: "c1",
      archived: false,
      expectedRevision: 2,
    });

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
  });
});
