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
import { roleSlotPath } from "../../src/contacts/role_slots";

const TIMESTAMP = "2026-09-18T12:00:00.000Z";
const clock = fixedClock(new Date(TIMESTAMP));

function supervisorProfile(): JsonMap {
  return {
    accessRole: "supervisor",
    congregationId: null,
    active: true,
    revision: 1,
    updatedAt: TIMESTAMP,
  };
}

function contactDocument(
  id: string,
  congregationId: string,
  name: string,
  overrides: JsonMap,
): JsonMap {
  return {
    id,
    name,
    normalizedName: name.toLowerCase(),
    scope: "congregation",
    congregationId,
    roleCode: null,
    phoneE164: null,
    birthDate: null,
    archived: false,
    revision: 1,
    createdAt: TIMESTAMP,
    updatedAt: TIMESTAMP,
    updatedBy: "seed",
    ...overrides,
  };
}

function directoryDocument(
  id: string,
  congregationId: string,
  name: string,
): JsonMap {
  return {
    id,
    name,
    normalizedName: name.toLowerCase(),
    roleCode: null,
    scope: "congregation",
    congregationId,
    phoneE164: null,
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

function activeSeed(): InMemoryDatastore {
  return new InMemoryDatastore({
    [paths.user("sup1")]: supervisorProfile(),
    [paths.congregation("c1")]: {
      id: "c1",
      name: "Central",
      normalizedName: "central",
      active: true,
      revision: 1,
    },
  });
}

describe("replaceRoleHolder against archived contacts", () => {
  it("rejects an archived replacement target and leaves every document unchanged", async () => {
    const datastore = activeSeed();
    const holderId = randomUUID();
    const targetId = randomUUID();
    await saveContact(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id: holderId,
      scope: "congregation",
      congregationId: "c1",
      name: "Titular",
      roleCode: "campaignLeader",
    });
    await saveContact(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id: targetId,
      scope: "congregation",
      congregationId: "c1",
      name: "Alvo",
    });
    await setContactArchived(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id: targetId,
      scope: "congregation",
      congregationId: "c1",
      archived: true,
      expectedRevision: 1,
    });

    const snapshot = async (): Promise<JsonMap> => ({
      holder: await datastore.read(paths.contact("c1", holderId)),
      target: await datastore.read(paths.contact("c1", targetId)),
      slot: await datastore.read(
        roleSlotPath("congregation", "c1", "campaignLeader"),
      ),
      holderDirectory: await datastore.read(paths.directory(holderId)),
      targetDirectory: await datastore.read(paths.directory(targetId)),
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
        expectedRevision: 2,
      }),
    );
    expect(error.code).toBe("conflict");

    expect(await snapshot()).toEqual(before);
    const after = await snapshot();
    expect((after.target as JsonMap).archived).toBe(true);
    expect((after.target as JsonMap).roleCode).toBeNull();
    expect((after.slot as JsonMap).contactId).toBe(holderId);
    expect((after.slot as JsonMap).contactId).not.toBe(targetId);
    expect(after.targetDirectory).toBeNull();
  });

  it("defensively rejects an archived previous holder without touching a free slot", async () => {
    const datastore = activeSeed();
    const holderId = randomUUID();
    const targetId = randomUUID();
    await saveContact(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id: holderId,
      scope: "congregation",
      congregationId: "c1",
      name: "Titular",
      roleCode: "campaignLeader",
    });
    await saveContact(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id: targetId,
      scope: "congregation",
      congregationId: "c1",
      name: "Alvo",
    });
    await setContactArchived(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id: holderId,
      scope: "congregation",
      congregationId: "c1",
      archived: true,
      expectedRevision: 1,
    });

    const slotBefore = await datastore.read(
      roleSlotPath("congregation", "c1", "campaignLeader"),
    );
    expect(slotBefore?.contactId).toBeNull();

    const error = await expectAppError(() =>
      replaceRoleHolder(datastore, clock, {
        uid: "sup1",
        requestId: randomUUID(),
        scope: "congregation",
        congregationId: "c1",
        roleCode: "campaignLeader",
        previousContactId: holderId,
        previousExpectedRevision: 2,
        id: targetId,
        expectedRevision: 1,
      }),
    );
    expect(error.code).toBe("conflict");

    expect(
      (
        await datastore.read(
          roleSlotPath("congregation", "c1", "campaignLeader"),
        )
      )?.contactId,
    ).toBeNull();
    expect(
      (await datastore.read(paths.contact("c1", targetId)))?.roleCode,
    ).toBeNull();
  });
});

describe("contact mutations inside an inactive congregation", () => {
  it("forbids supervisor create, rename, archive and restore without any write", async () => {
    const activeId = randomUUID();
    const archivedId = randomUUID();
    const newId = randomUUID();
    const datastore = new InMemoryDatastore({
      [paths.user("sup1")]: supervisorProfile(),
      [paths.congregation("c2")]: {
        id: "c2",
        name: "Norte",
        normalizedName: "norte",
        active: false,
        revision: 4,
      },
      [paths.contact("c2", activeId)]: contactDocument(
        activeId,
        "c2",
        "Ativo",
        { revision: 1 },
      ),
      [paths.directory(activeId)]: directoryDocument(activeId, "c2", "Ativo"),
      [paths.contact("c2", archivedId)]: contactDocument(
        archivedId,
        "c2",
        "Arquivado",
        { archived: true, revision: 2 },
      ),
    });

    const snapshot = async (): Promise<JsonMap> => ({
      active: await datastore.read(paths.contact("c2", activeId)),
      archived: await datastore.read(paths.contact("c2", archivedId)),
      directory: await datastore.read(paths.directory(activeId)),
      created: await datastore.read(paths.contact("c2", newId)),
      createdDirectory: await datastore.read(paths.directory(newId)),
    });
    const before = await snapshot();

    const create = await expectAppError(() =>
      saveContact(datastore, clock, {
        uid: "sup1",
        requestId: randomUUID(),
        id: newId,
        scope: "congregation",
        congregationId: "c2",
        name: "Novo",
      }),
    );
    const rename = await expectAppError(() =>
      saveContact(datastore, clock, {
        uid: "sup1",
        requestId: randomUUID(),
        id: activeId,
        expectedRevision: 1,
        scope: "congregation",
        congregationId: "c2",
        name: "Renomeado",
      }),
    );
    const archive = await expectAppError(() =>
      setContactArchived(datastore, clock, {
        uid: "sup1",
        requestId: randomUUID(),
        id: activeId,
        scope: "congregation",
        congregationId: "c2",
        archived: true,
        expectedRevision: 1,
      }),
    );
    const restore = await expectAppError(() =>
      setContactArchived(datastore, clock, {
        uid: "sup1",
        requestId: randomUUID(),
        id: archivedId,
        scope: "congregation",
        congregationId: "c2",
        archived: false,
        expectedRevision: 2,
      }),
    );

    for (const error of [create, rename, archive, restore]) {
      expect(error.code).toBe("forbidden");
    }
    expect(await snapshot()).toEqual(before);
  });
});
