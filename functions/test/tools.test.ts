import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";
import { InMemoryDatastore, paths } from "../src/core/datastore";
import { AppError } from "../src/core/errors";
import { AccessRole } from "../src/core/models";
import { provisionAccess } from "../tools/provision-access";
import { assertEmulatorEnvironment, seedEmulators } from "../tools/seed-emulators";

const now = new Date("2026-09-18T12:00:00.000Z");

function seedDatastore(): InMemoryDatastore {
  return new InMemoryDatastore({
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

describe("trusted access provisioning", () => {
  it("provisions an existing Auth UID with a valid congregation binding", async () => {
    const datastore = seedDatastore();
    const outcome = await provisionAccess(datastore, {
      uid: "uid-1",
      accessRole: "congregationStaff",
      active: true,
      congregationId: "c1",
    });
    expect(outcome).toEqual({
      uid: "uid-1",
      accessRole: AccessRole.congregationStaff,
      congregationId: "c1",
      active: true,
    });
    const stored = await datastore.read(paths.user("uid-1"));
    expect(stored?.accessRole).toBe("congregationStaff");
    expect(stored?.congregationId).toBe("c1");
    expect(stored?.active).toBe(true);
    expect(stored?.revision).toBe(1);
    expect(stored).not.toHaveProperty("password");
  });

  it("provisions a supervisor without a mandatory congregation", async () => {
    const datastore = seedDatastore();
    const outcome = await provisionAccess(datastore, {
      uid: "uid-2",
      accessRole: "supervisor",
      active: true,
      congregationId: null,
    });
    expect(outcome.accessRole).toBe(AccessRole.supervisor);
    expect(outcome.congregationId).toBeNull();
  });

  it("validates role, active flag and congregation binding", async () => {
    const datastore = seedDatastore();
    expect(
      (
        await expectAppError(() =>
          provisionAccess(datastore, {
            uid: "uid-3",
            accessRole: "admin",
            active: true,
            congregationId: null,
          }),
        )
      ).code,
    ).toBe("validation");
    expect(
      (
        await expectAppError(() =>
          provisionAccess(datastore, {
            uid: "uid-4",
            accessRole: "congregationStaff",
            active: true,
            congregationId: null,
          }),
        )
      ).code,
    ).toBe("validation");
    expect(
      (
        await expectAppError(() =>
          provisionAccess(datastore, {
            uid: "uid-5",
            accessRole: "congregationStaff",
            active: true,
            congregationId: "missing",
          }),
        )
      ).code,
    ).toBe("notFound");
  });

  it("deactivates an existing profile without storing a password", async () => {
    const datastore = seedDatastore();
    await provisionAccess(datastore, {
      uid: "uid-6",
      accessRole: "congregationStaff",
      active: true,
      congregationId: "c1",
      now,
    });
    const outcome = await provisionAccess(datastore, {
      uid: "uid-6",
      accessRole: "congregationStaff",
      active: false,
      congregationId: "c1",
      now,
    });
    expect(outcome.active).toBe(false);
    const stored = await datastore.read(paths.user("uid-6"));
    expect(stored?.active).toBe(false);
    expect(stored?.revision).toBe(2);
  });

  it("is never exported as a callable", () => {
    const source = readFileSync(resolve(__dirname, "../tools/provision-access.ts"), "utf8");
    expect(source).not.toContain("firebase-functions");
    expect(source).not.toContain("onCall");
  });
});

describe("synthetic emulator seeds", () => {
  it("refuses to operate outside an explicit emulator environment", async () => {
    const datastore = seedDatastore();
    expect(() => assertEmulatorEnvironment({})).toThrow(AppError);
    const error = await expectAppError(() =>
      seedEmulators(datastore, { FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080" }),
    );
    expect(error.code).toBe("unavailable");
  });

  it("runs only when both Auth and Firestore emulator variables are present", async () => {
    const datastore = seedDatastore();
    const env = {
      FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080",
      FIREBASE_AUTH_EMULATOR_HOST: "127.0.0.1:9099",
    };
    expect(() => assertEmulatorEnvironment(env)).not.toThrow();
    const summary = await seedEmulators(datastore, env, now);
    expect(summary.supervisors).toBeGreaterThanOrEqual(1);
    expect(summary.congregations).toBeGreaterThanOrEqual(2);
  });

  it("never references the legacy credential file", () => {
    const source = readFileSync(resolve(__dirname, "../tools/seed-emulators.ts"), "utf8");
    expect(source).not.toContain("serviceAccountKey");
    expect(source).not.toContain("GOOGLE_APPLICATION_CREDENTIALS");
  });
});
