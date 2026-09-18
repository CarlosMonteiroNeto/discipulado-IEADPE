import { describe, expect, it } from "vitest";
import { authorizeContext, assertCongregationAccess } from "../src/core/context";
import { InMemoryDatastore, paths } from "../src/core/datastore";
import { AppError } from "../src/core/errors";

const timestamp = "2026-09-18T12:00:00.000Z";

function seedDatastore(): InMemoryDatastore {
  return new InMemoryDatastore({
    [paths.user("staff1")]: {
      accessRole: "congregationStaff",
      congregationId: "c1",
      active: true,
      revision: 1,
      updatedAt: timestamp,
    },
    [paths.user("staff2")]: {
      accessRole: "congregationStaff",
      congregationId: "c2",
      active: true,
      revision: 1,
      updatedAt: timestamp,
    },
    [paths.user("inactive")]: {
      accessRole: "congregationStaff",
      congregationId: "c1",
      active: false,
      revision: 2,
      updatedAt: timestamp,
    },
    [paths.user("sup1")]: {
      accessRole: "supervisor",
      congregationId: null,
      active: true,
      revision: 1,
      updatedAt: timestamp,
    },
    [paths.user("badRole")]: {
      accessRole: "admin",
      congregationId: null,
      active: true,
      revision: 1,
      updatedAt: timestamp,
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
    [paths.congregation("archived")]: {
      id: "archived",
      name: "Antiga",
      normalizedName: "antiga",
      active: false,
      revision: 3,
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

describe("authorizeContext", () => {
  it("reads the caller profile and congregation on every call", async () => {
    const datastore = seedDatastore();
    const context = await authorizeContext({ datastore, uid: "staff1" });
    expect(context.uid).toBe("staff1");
    expect(context.profile.accessRole).toBe("congregationStaff");
    expect(context.profile.congregationId).toBe("c1");
    expect(context.congregation?.name).toBe("Central");
  });

  it("rejects missing and inactive profiles", async () => {
    const datastore = seedDatastore();
    expect((await expectAppError(() => authorizeContext({ datastore, uid: "ghost" }))).code).toBe(
      "forbidden",
    );
    expect(
      (await expectAppError(() => authorizeContext({ datastore, uid: "inactive" }))).code,
    ).toBe("forbidden");
  });

  it("rejects an unknown access role in the stored profile", async () => {
    const datastore = seedDatastore();
    expect(
      (await expectAppError(() => authorizeContext({ datastore, uid: "badRole" }))).code,
    ).toBe("validation");
  });

  it("rejects staff bound to a missing or inactive congregation", async () => {
    const datastore = seedDatastore();
    await datastore.write(paths.user("orphan"), {
      accessRole: "congregationStaff",
      congregationId: "missing",
      active: true,
      revision: 1,
      updatedAt: timestamp,
    });
    expect(
      (await expectAppError(() => authorizeContext({ datastore, uid: "orphan" }))).code,
    ).toBe("forbidden");
    await datastore.write(paths.user("expired"), {
      accessRole: "congregationStaff",
      congregationId: "archived",
      active: true,
      revision: 1,
      updatedAt: timestamp,
    });
    expect(
      (await expectAppError(() => authorizeContext({ datastore, uid: "expired" }))).code,
    ).toBe("forbidden");
  });

  it("enforces supervisor versus congregationStaff scope", async () => {
    const datastore = seedDatastore();
    const staff = await authorizeContext({ datastore, uid: "staff1" });
    expect(() => assertCongregationAccess(staff, "c1")).not.toThrow();
    expect(() => assertCongregationAccess(staff, "c2")).toThrow(AppError);

    const supervisor = await authorizeContext({ datastore, uid: "sup1" });
    expect(supervisor.congregation).toBeNull();
    expect(() => assertCongregationAccess(supervisor, "c2")).not.toThrow();
    expect(() => assertCongregationAccess(supervisor, "archived")).not.toThrow();
  });

  it("resolves a supervisor-selected congregation and rejects unknown ones", async () => {
    const datastore = seedDatastore();
    const context = await authorizeContext({
      datastore,
      uid: "sup1",
      requestedCongregationId: "c2",
    });
    expect(context.congregationId).toBe("c2");
    expect(context.congregation?.name).toBe("Norte");
    expect(
      (
        await expectAppError(() =>
          authorizeContext({ datastore, uid: "sup1", requestedCongregationId: "nope" }),
        )
      ).code,
    ).toBe("notFound");
  });

  it("rejects a cross-congregation request from staff", async () => {
    const datastore = seedDatastore();
    expect(
      (
        await expectAppError(() =>
          authorizeContext({ datastore, uid: "staff1", requestedCongregationId: "c2" }),
        )
      ).code,
    ).toBe("forbidden");
  });

  it("ignores roles supplied in the payload", async () => {
    const datastore = seedDatastore();
    const context = await authorizeContext({
      datastore,
      uid: "staff1",
      payload: { accessRole: "supervisor", congregationId: "c2" },
    });
    expect(context.profile.accessRole).toBe("congregationStaff");
    expect(context.congregationId).toBe("c1");
    expect(() => assertCongregationAccess(context, "c2")).toThrow(AppError);
  });
});
