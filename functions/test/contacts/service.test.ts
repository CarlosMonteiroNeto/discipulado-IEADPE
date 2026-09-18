import { randomUUID } from "node:crypto";
import { describe, expect, it } from "vitest";
import { fixedClock } from "../../src/core/clock";
import { InMemoryDatastore, JsonMap, paths } from "../../src/core/datastore";
import { AppError } from "../../src/core/errors";
import {
  replaceRoleHolder,
  saveContact,
  setContactArchived,
} from "../../src/contacts/service";
import {
  ROLE_LABELS,
  roleSlotPath,
  teacherClassReferencePath,
} from "../../src/contacts/role_slots";
import { ROLE_CODES } from "../../src/core/models";

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

function directoryEntry(
  id: string,
  name: string,
  roleCode: string | null,
  congregationId: string | null,
): JsonMap {
  return {
    id,
    name,
    normalizedName: name.trim().toLowerCase(),
    roleCode,
    scope: "congregation",
    congregationId,
    phoneE164: null,
  };
}

describe("saveContact", () => {
  it("creates homonymous contacts with distinct IDs and projections", async () => {
    const datastore = seedDatastore();
    const firstId = randomUUID();
    const secondId = randomUUID();

    await saveContact(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id: firstId,
      scope: "congregation",
      congregationId: "c1",
      name: "Ana Souza",
    });
    await saveContact(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id: secondId,
      scope: "congregation",
      congregationId: "c1",
      name: "Ana Souza",
    });

    const first = await datastore.read(paths.contact("c1", firstId));
    const second = await datastore.read(paths.contact("c1", secondId));
    expect(first?.id).toBe(firstId);
    expect(second?.id).toBe(secondId);
    expect(first?.normalizedName).toBe("ana souza");
    expect(second?.normalizedName).toBe("ana souza");
    expect(await datastore.read(paths.directory(firstId))).toEqual(
      directoryEntry(firstId, "Ana Souza", null, "c1"),
    );
    expect(await datastore.read(paths.directory(secondId))).toEqual(
      directoryEntry(secondId, "Ana Souza", null, "c1"),
    );
  });

  it("renames a contact without changing its ID or createdAt", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    await saveContact(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id,
      scope: "congregation",
      congregationId: "c1",
      name: "João",
    });
    const created = await datastore.read(paths.contact("c1", id));

    await saveContact(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id,
      expectedRevision: 1,
      scope: "congregation",
      congregationId: "c1",
      name: "João Silva",
    });

    const renamed = await datastore.read(paths.contact("c1", id));
    expect(renamed?.id).toBe(id);
    expect(renamed?.createdAt).toBe(created?.createdAt);
    expect(renamed?.name).toBe("João Silva");
    expect(renamed?.normalizedName).toBe("joao silva");
    expect(renamed?.revision).toBe(2);
  });

  it("keeps scope immutable, rejecting a supervision contact moved into a congregation", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    await saveContact(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id,
      scope: "supervision",
      name: "Rita",
    });

    const error = await expectAppError(() =>
      saveContact(datastore, clock, {
        uid: "sup1",
        requestId: randomUUID(),
        id,
        expectedRevision: 1,
        scope: "congregation",
        congregationId: "c1",
        name: "Rita",
      }),
    );
    expect(error.code).toBe("validation");

    const stored = await datastore.read(paths.supervisionContact(id));
    expect(stored?.scope).toBe("supervision");
    expect(stored?.revision).toBe(1);
    expect(await datastore.read(paths.contact("c1", id))).toBeNull();
  });

  it("rejects invalid role and scope combinations", async () => {
    const datastore = seedDatastore();
    const error = await expectAppError(() =>
      saveContact(datastore, clock, {
        uid: "sup1",
        requestId: randomUUID(),
        id: randomUUID(),
        scope: "congregation",
        congregationId: "c1",
        name: "Inválido",
        roleCode: "campaignSupervisor",
      }),
    );
    expect(error.code).toBe("validation");

    // The matching combination is accepted.
    const id = randomUUID();
    await saveContact(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id,
      scope: "congregation",
      congregationId: "c1",
      name: "Professor",
      roleCode: "teacher",
    });
    expect((await datastore.read(paths.contact("c1", id)))?.roleCode).toBe(
      "teacher",
    );
  });

  it("normalizes phone input and keeps an optional birth date on the full record", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    await saveContact(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id,
      scope: "congregation",
      congregationId: "c1",
      name: "Contato",
      phone: "(81) 99999-8888",
      birthDate: "1990-05-04",
    });
    const stored = await datastore.read(paths.contact("c1", id));
    expect(stored?.phoneE164).toBe("+5581999998888");
    expect(stored?.birthDate).toBe("1990-05-04");
    expect(await datastore.read(paths.directory(id))).not.toHaveProperty(
      "birthDate",
    );
  });

  it("returns the cached result for a duplicate request replay", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    const requestId = randomUUID();
    const input = {
      uid: "sup1",
      requestId,
      id,
      scope: "congregation" as const,
      congregationId: "c1",
      name: "Replay",
    };
    const first = await saveContact(datastore, clock, input);
    const replay = await saveContact(datastore, clock, input);
    expect(replay).toEqual(first);
    expect((await datastore.read(paths.contact("c1", id)))?.revision).toBe(1);
  });

  it("forbids local staff from editing another congregation or supervision contacts", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    await saveContact(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id,
      scope: "congregation",
      congregationId: "c2",
      name: "Alheio",
    });

    const crossScope = await expectAppError(() =>
      saveContact(datastore, clock, {
        uid: "staff1",
        requestId: randomUUID(),
        id,
        expectedRevision: 1,
        scope: "congregation",
        congregationId: "c2",
        name: "Alheio",
      }),
    );
    expect(crossScope.code).toBe("forbidden");

    const supervision = await expectAppError(() =>
      saveContact(datastore, clock, {
        uid: "staff1",
        requestId: randomUUID(),
        id: randomUUID(),
        scope: "supervision",
        name: "Rita",
      }),
    );
    expect(supervision.code).toBe("forbidden");
  });
});

describe("administrative role slots", () => {
  it("yields exactly one holder for concurrent same-role attempts", async () => {
    const datastore = seedDatastore();
    const firstId = randomUUID();
    const secondId = randomUUID();
    for (const id of [firstId, secondId]) {
      await saveContact(datastore, clock, {
        uid: "sup1",
        requestId: randomUUID(),
        id,
        scope: "congregation",
        congregationId: "c1",
        name: `Candidato ${id.slice(0, 4)}`,
      });
    }

    const results = await Promise.allSettled([
      saveContact(datastore, clock, {
        uid: "sup1",
        requestId: randomUUID(),
        id: firstId,
        expectedRevision: 1,
        scope: "congregation",
        congregationId: "c1",
        name: "Candidato A",
        roleCode: "campaignLeader",
      }),
      saveContact(datastore, clock, {
        uid: "sup1",
        requestId: randomUUID(),
        id: secondId,
        expectedRevision: 1,
        scope: "congregation",
        congregationId: "c1",
        name: "Candidato B",
        roleCode: "campaignLeader",
      }),
    ]);

    const fulfilled = results.filter((entry) => entry.status === "fulfilled");
    expect(fulfilled).toHaveLength(1);

    const first = await datastore.read(paths.contact("c1", firstId));
    const second = await datastore.read(paths.contact("c1", secondId));
    const holders = [first, second].filter(
      (record) => record?.roleCode === "campaignLeader",
    );
    expect(holders).toHaveLength(1);
  });

  it("lets distinct scopes hold the same role independently", async () => {
    const datastore = seedDatastore();
    const firstId = randomUUID();
    const secondId = randomUUID();
    const create = (
      id: string,
      congregationId: string,
      name: string,
    ): Parameters<typeof saveContact>[2] => ({
      uid: "sup1",
      requestId: randomUUID(),
      id,
      scope: "congregation",
      congregationId,
      name,
    });
    await saveContact(datastore, clock, create(firstId, "c1", "Líder Central"));
    await saveContact(datastore, clock, create(secondId, "c2", "Líder Norte"));

    await saveContact(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id: firstId,
      expectedRevision: 1,
      scope: "congregation",
      congregationId: "c1",
      name: "Líder Central",
      roleCode: "campaignLeader",
    });
    await saveContact(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id: secondId,
      expectedRevision: 1,
      scope: "congregation",
      congregationId: "c2",
      name: "Líder Norte",
      roleCode: "campaignLeader",
    });

    const firstSlot = await datastore.read(
      roleSlotPath("congregation", "c1", "campaignLeader"),
    );
    const secondSlot = await datastore.read(
      roleSlotPath("congregation", "c2", "campaignLeader"),
    );
    expect(firstSlot?.contactId).toBe(firstId);
    expect(secondSlot?.contactId).toBe(secondId);
  });

  it("permits multiple teachers in the same scope without a slot", async () => {
    const datastore = seedDatastore();
    const firstId = randomUUID();
    const secondId = randomUUID();
    for (const [id, name] of [
      [firstId, "Professor A"],
      [secondId, "Professor B"],
    ] as const) {
      await saveContact(datastore, clock, {
        uid: "sup1",
        requestId: randomUUID(),
        id,
        scope: "congregation",
        congregationId: "c1",
        name,
        roleCode: "teacher",
      });
    }
    expect((await datastore.read(paths.contact("c1", firstId)))?.roleCode).toBe(
      "teacher",
    );
    expect((await datastore.read(paths.contact("c1", secondId)))?.roleCode).toBe(
      "teacher",
    );
    expect(
      await datastore.read(roleSlotPath("congregation", "c1", "teacher")),
    ).toBeNull();
  });

  it("matches all twelve S06 role codes and pt-BR labels", () => {
    expect(Object.keys(ROLE_LABELS).sort()).toEqual(
      Object.keys(ROLE_CODES).sort(),
    );
    expect(ROLE_LABELS).toEqual({
      campaignSupervisor: "Supervisor das campanhas",
      campaignDeputy: "Vice-supervisor das campanhas",
      discipleshipCoordinator: "Coordenador do discipulado",
      discipleshipDeputy: "Vice-coordenador do discipulado",
      coordinationSecretary: "Secretária da coordenação",
      coordinationDeputySecretary: "Vice-secretária da coordenação",
      congregationAssistant: "Assistente de congregação",
      campaignLeader: "Dirigente de campanha",
      campaignDeputyLeader: "Vice-dirigente de campanha",
      teacher: "Professor(a) do discipulado",
      discipleshipSecretary: "Secretária do discipulado",
      discipleshipDeputySecretary: "Vice-secretária do discipulado",
    });
  });
});

describe("replaceRoleHolder", () => {
  async function createHolder(
    datastore: InMemoryDatastore,
    name: string,
  ): Promise<string> {
    const id = randomUUID();
    await saveContact(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id,
      scope: "congregation",
      congregationId: "c1",
      name,
      roleCode: "campaignLeader",
    });
    return id;
  }

  it("leaves every document unchanged when a revision does not match", async () => {
    const datastore = seedDatastore();
    const holderId = await createHolder(datastore, "Titular");
    const targetId = randomUUID();
    await saveContact(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id: targetId,
      scope: "congregation",
      congregationId: "c1",
      name: "Alvo",
    });

    const before = {
      holder: await datastore.read(paths.contact("c1", holderId)),
      target: await datastore.read(paths.contact("c1", targetId)),
      slot: await datastore.read(
        roleSlotPath("congregation", "c1", "campaignLeader"),
      ),
      holderDirectory: await datastore.read(paths.directory(holderId)),
      targetDirectory: await datastore.read(paths.directory(targetId)),
    };

    const error = await expectAppError(() =>
      replaceRoleHolder(datastore, clock, {
        uid: "sup1",
        requestId: randomUUID(),
        scope: "congregation",
        congregationId: "c1",
        roleCode: "campaignLeader",
        previousContactId: holderId,
        previousExpectedRevision: 99,
        id: targetId,
        expectedRevision: 1,
      }),
    );
    expect(error.code).toBe("conflict");

    expect({
      holder: await datastore.read(paths.contact("c1", holderId)),
      target: await datastore.read(paths.contact("c1", targetId)),
      slot: await datastore.read(
        roleSlotPath("congregation", "c1", "campaignLeader"),
      ),
      holderDirectory: await datastore.read(paths.directory(holderId)),
      targetDirectory: await datastore.read(paths.directory(targetId)),
    }).toEqual(before);
  });

  it("leaves every document unchanged when the target revision does not match", async () => {
    const datastore = seedDatastore();
    const holderId = await createHolder(datastore, "Titular");
    const targetId = randomUUID();
    await saveContact(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id: targetId,
      scope: "congregation",
      congregationId: "c1",
      name: "Alvo",
    });

    const snapshot = async (): Promise<unknown> => ({
      holder: await datastore.read(paths.contact("c1", holderId)),
      target: await datastore.read(paths.contact("c1", targetId)),
      slot: await datastore.read(
        roleSlotPath("congregation", "c1", "campaignLeader"),
      ),
    });
    const before = await snapshot();

    const error = await expectAppError(() =>
      replaceRoleHolder(datastore, clock, {
        uid: "sup1",
        requestId: randomUUID(),
        scope: "congregation",
        congregationId: "c1",
        roleCode: "campaignLeader",
        previousContactId: holderId,
        previousExpectedRevision: 1,
        id: targetId,
        expectedRevision: 99,
      }),
    );
    expect(error.code).toBe("conflict");
    expect(await snapshot()).toEqual(before);
  });

  it("clears only the old assignment, preserves the old person and updates both projections", async () => {
    const datastore = seedDatastore();
    const holderId = await createHolder(datastore, "Titular");
    const targetId = randomUUID();
    await saveContact(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id: targetId,
      scope: "congregation",
      congregationId: "c1",
      name: "Alvo",
    });

    const result = await replaceRoleHolder(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      scope: "congregation",
      congregationId: "c1",
      roleCode: "campaignLeader",
      previousContactId: holderId,
      previousExpectedRevision: 1,
      id: targetId,
      expectedRevision: 1,
    });
    expect(result.id).toBe(targetId);
    expect(result.revision).toBe(2);

    const holder = await datastore.read(paths.contact("c1", holderId));
    const target = await datastore.read(paths.contact("c1", targetId));
    expect(holder?.id).toBe(holderId);
    expect(holder?.name).toBe("Titular");
    expect(holder?.roleCode).toBeNull();
    expect(target?.roleCode).toBe("campaignLeader");

    const slot = await datastore.read(
      roleSlotPath("congregation", "c1", "campaignLeader"),
    );
    expect(slot?.contactId).toBe(targetId);
    expect(await datastore.read(paths.directory(holderId))).toEqual(
      directoryEntry(holderId, "Titular", null, "c1"),
    );
    expect(await datastore.read(paths.directory(targetId))).toEqual(
      directoryEntry(targetId, "Alvo", "campaignLeader", "c1"),
    );
  });
});

describe("setContactArchived", () => {
  it("releases the slot and removes directory availability, then restores unassigned", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    await saveContact(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id,
      scope: "congregation",
      congregationId: "c1",
      name: "Titular",
      roleCode: "campaignLeader",
    });

    await setContactArchived(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id,
      scope: "congregation",
      congregationId: "c1",
      archived: true,
      expectedRevision: 1,
    });

    expect((await datastore.read(paths.contact("c1", id)))?.archived).toBe(true);
    expect((await datastore.read(paths.contact("c1", id)))?.roleCode).toBeNull();
    expect(await datastore.read(paths.directory(id))).toBeNull();
    expect(
      (await datastore.read(
        roleSlotPath("congregation", "c1", "campaignLeader"),
      ))?.contactId,
    ).toBeNull();

    await setContactArchived(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id,
      scope: "congregation",
      congregationId: "c1",
      archived: false,
      expectedRevision: 2,
    });

    const restored = await datastore.read(paths.contact("c1", id));
    expect(restored?.archived).toBe(false);
    expect(restored?.roleCode).toBeNull();
    expect(await datastore.read(paths.directory(id))).toEqual(
      directoryEntry(id, "Titular", null, "c1"),
    );
  });

  it("blocks archiving a teacher referenced by an active class", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    await saveContact(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id,
      scope: "congregation",
      congregationId: "c1",
      name: "Professor",
      roleCode: "teacher",
    });
    await datastore.write(teacherClassReferencePath("c1", id), {
      id,
      congregationId: "c1",
      activeClassCount: 1,
    });

    const archive = await expectAppError(() =>
      setContactArchived(datastore, clock, {
        uid: "sup1",
        requestId: randomUUID(),
        id,
        scope: "congregation",
        congregationId: "c1",
        archived: true,
        expectedRevision: 1,
      }),
    );
    expect(archive.code).toBe("conflict");

    const loseEligibility = await expectAppError(() =>
      saveContact(datastore, clock, {
        uid: "sup1",
        requestId: randomUUID(),
        id,
        expectedRevision: 1,
        scope: "congregation",
        congregationId: "c1",
        name: "Professor",
        roleCode: null,
      }),
    );
    expect(loseEligibility.code).toBe("conflict");

    await datastore.runTransaction(async (tx) => {
      await tx.delete(teacherClassReferencePath("c1", id));
    });
    await setContactArchived(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id,
      scope: "congregation",
      congregationId: "c1",
      archived: true,
      expectedRevision: 1,
    });
    expect((await datastore.read(paths.contact("c1", id)))?.archived).toBe(true);
  });
});
