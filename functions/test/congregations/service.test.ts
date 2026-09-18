import { randomUUID } from "node:crypto";
import { describe, expect, it } from "vitest";
import { fixedClock } from "../../src/core/clock";
import { InMemoryDatastore, JsonMap, paths } from "../../src/core/datastore";
import { AppError } from "../../src/core/errors";
import {
  saveCongregation,
  scopeReferencePath,
  setCongregationArchived,
} from "../../src/congregations/service";

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
    [paths.congregation("c1")]: {
      id: "c1",
      name: "Central",
      normalizedName: "central",
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

describe("saveCongregation", () => {
  it("creates a supervisor congregation with a unique normalized name", async () => {
    const datastore = new InMemoryDatastore({
      [paths.user("sup1")]: {
        accessRole: "supervisor",
        congregationId: null,
        active: true,
        revision: 1,
        updatedAt: TIMESTAMP,
      },
    });
    const id = randomUUID();
    const result = await saveCongregation(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id,
      name: "  Bom Jardim ",
    });
    expect(result).toEqual({ id, revision: 1 });
    const stored = await datastore.read(paths.congregation(id));
    expect(stored?.name).toBe("Bom Jardim");
    expect(stored?.normalizedName).toBe("bom jardim");
    expect(stored?.active).toBe(true);

    const duplicate = await expectAppError(() =>
      saveCongregation(datastore, clock, {
        uid: "sup1",
        requestId: randomUUID(),
        id: randomUUID(),
        name: "bom jardim",
      }),
    );
    expect(duplicate.code).toBe("conflict");
  });

  it("renames without changing the ID and frees the previous name", async () => {
    const datastore = seedDatastore();
    const renamed = await saveCongregation(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id: "c1",
      expectedRevision: 1,
      name: "Central Renovada",
    });
    expect(renamed).toEqual({ id: "c1", revision: 2 });
    const stored = await datastore.read(paths.congregation("c1"));
    expect(stored?.id).toBe("c1");
    expect(stored?.name).toBe("Central Renovada");
    expect(stored?.normalizedName).toBe("central renovada");

    const reuse = await saveCongregation(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id: randomUUID(),
      name: "Central",
    });
    expect(reuse.revision).toBe(1);
  });

  it("returns the cached result for a duplicate request replay", async () => {
    const datastore = seedDatastore();
    const input = {
      uid: "sup1",
      requestId: randomUUID(),
      id: randomUUID(),
      name: "Nova",
    };
    const first = await saveCongregation(datastore, clock, input);
    const replay = await saveCongregation(datastore, clock, input);
    expect(replay).toEqual(first);
  });

  it("forbids congregation staff from creating or renaming congregations", async () => {
    const datastore = seedDatastore();
    const create = await expectAppError(() =>
      saveCongregation(datastore, clock, {
        uid: "staff1",
        requestId: randomUUID(),
        id: randomUUID(),
        name: "Nova",
      }),
    );
    expect(create.code).toBe("forbidden");

    const rename = await expectAppError(() =>
      saveCongregation(datastore, clock, {
        uid: "staff1",
        requestId: randomUUID(),
        id: "c1",
        expectedRevision: 1,
        name: "Alterada",
      }),
    );
    expect(rename.code).toBe("forbidden");
  });
});

describe("setCongregationArchived", () => {
  const dependencyFields = [
    "activeUsers",
    "unarchivedStudents",
    "unarchivedContacts",
    "activeClasses",
  ] as const;

  it.each(dependencyFields)(
    "blocks archiving while %s references the congregation",
    async (field) => {
      const datastore = seedDatastore();
      await datastore.write(scopeReferencePath("c1"), { [field]: 1 });
      const error = await expectAppError(() =>
        setCongregationArchived(datastore, clock, {
          uid: "sup1",
          requestId: randomUUID(),
          id: "c1",
          archived: true,
          expectedRevision: 1,
        }),
      );
      expect(error.code).toBe("conflict");
      expect((await datastore.read(paths.congregation("c1")))?.active).toBe(
        true,
      );
    },
  );

  it("archives and restores when no dependency references remain", async () => {
    const datastore = seedDatastore();
    await datastore.write(scopeReferencePath("c1"), {
      activeUsers: 0,
      unarchivedStudents: 0,
      unarchivedContacts: 0,
      activeClasses: 0,
    });

    await setCongregationArchived(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id: "c1",
      archived: true,
      expectedRevision: 1,
    });
    expect((await datastore.read(paths.congregation("c1")))?.active).toBe(
      false,
    );

    await setCongregationArchived(datastore, clock, {
      uid: "sup1",
      requestId: randomUUID(),
      id: "c1",
      archived: false,
      expectedRevision: 2,
    });
    expect((await datastore.read(paths.congregation("c1")))?.active).toBe(true);
  });

  it("forbids congregation staff from archiving their own congregation", async () => {
    const datastore = seedDatastore();
    const error = await expectAppError(() =>
      setCongregationArchived(datastore, clock, {
        uid: "staff1",
        requestId: randomUUID(),
        id: "c1",
        archived: true,
        expectedRevision: 1,
      }),
    );
    expect(error.code).toBe("forbidden");
    expect((await datastore.read(paths.congregation("c1")))?.active).toBe(true);
  });

  it("fails a stale revision without changing the congregation", async () => {
    const datastore = seedDatastore();
    const before: JsonMap | null = await datastore.read(
      paths.congregation("c1"),
    );
    const error = await expectAppError(() =>
      setCongregationArchived(datastore, clock, {
        uid: "sup1",
        requestId: randomUUID(),
        id: "c1",
        archived: true,
        expectedRevision: 99,
      }),
    );
    expect(error.code).toBe("conflict");
    expect(await datastore.read(paths.congregation("c1"))).toEqual(before);
  });
});
