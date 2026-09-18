import { randomUUID } from "node:crypto";
import { describe, expect, it } from "vitest";
import { fixedClock } from "../../src/core/clock";
import { InMemoryDatastore, paths } from "../../src/core/datastore";
import {
  renderDirectoryEntry,
  writeDirectoryProjection,
} from "../../src/contacts/directory";
import { saveContact } from "../../src/contacts/service";
import { saveCongregation } from "../../src/congregations/service";

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
    [paths.congregation("c1")]: {
      id: "c1",
      name: "Central",
      normalizedName: "central",
      active: true,
      revision: 1,
    },
  });
}

describe("directory projection", () => {
  it("never exposes the birth date and keeps only the minimal fields", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    await saveContact(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id,
      scope: "congregation",
      congregationId: "c1",
      name: "José da Silva",
      phone: "81999998888",
      birthDate: "1990-01-01",
    });

    const projection = await datastore.read(paths.directory(id));
    expect(projection).not.toHaveProperty("birthDate");
    expect(projection).not.toHaveProperty("address");
    expect(Object.keys(projection ?? {}).sort()).toEqual([
      "congregationId",
      "id",
      "name",
      "normalizedName",
      "phoneE164",
      "roleCode",
      "scope",
    ]);
    expect((await datastore.read(paths.contact("c1", id)))?.birthDate).toBe(
      "1990-01-01",
    );
  });

  it("renders the authoritative congregation name after a rename", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    await saveContact(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id,
      scope: "congregation",
      congregationId: "c1",
      name: "Membro",
      birthDate: "1985-02-03",
    });
    const projection = await datastore.read(paths.directory(id));
    const before = await datastore.read(paths.congregation("c1"));

    const firstRender = renderDirectoryEntry(projection!, before);
    expect(firstRender.congregationName).toBe("Central");
    expect(firstRender).not.toHaveProperty("birthDate");

    await saveCongregation(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id: "c1",
      expectedRevision: 1,
      name: "Central Renovada",
    });
    const after = await datastore.read(paths.congregation("c1"));
    const secondRender = renderDirectoryEntry(
      (await datastore.read(paths.directory(id)))!,
      after,
    );
    expect(secondRender.congregationName).toBe("Central Renovada");
    expect(secondRender).not.toHaveProperty("birthDate");
  });

  it("drops the projection for archived contacts and rewrites it on restore", async () => {
    const datastore = seedDatastore();
    const id = randomUUID();
    const contact = {
      id,
      name: "Membro",
      normalizedName: "membro",
      scope: "congregation",
      congregationId: "c1",
      roleCode: null,
      phoneE164: null,
      birthDate: "1985-02-03",
      archived: true,
      revision: 2,
      createdAt: TIMESTAMP,
      updatedAt: TIMESTAMP,
      updatedBy: "sup1",
    };
    await datastore.runTransaction(async (tx) => {
      await tx.write(paths.directory(id), { id, name: "stale" });
      await writeDirectoryProjection(tx, contact);
    });
    expect(await datastore.read(paths.directory(id))).toBeNull();

    await datastore.runTransaction(async (tx) => {
      await writeDirectoryProjection(tx, { ...contact, archived: false });
    });
    expect(await datastore.read(paths.directory(id))).toEqual({
      id,
      name: "Membro",
      normalizedName: "membro",
      roleCode: null,
      scope: "congregation",
      congregationId: "c1",
      phoneE164: null,
    });
  });
});
