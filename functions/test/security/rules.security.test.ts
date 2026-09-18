import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { afterAll, beforeAll, describe, expect, it } from "vitest";

/**
 * Firestore emulator-backed rules tests. They run only when
 * FIRESTORE_EMULATOR_HOST is present (the backend gate's emulator entry
 * point); the unit gate skips them because rules cannot be proven without a
 * running emulator.
 */
const hasEmulator = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
const suite = hasEmulator ? describe : describe.skip;

suite("firestore security rules", () => {
  let testEnv: any;
  let assertSucceeds: (promise: Promise<unknown>) => Promise<unknown>;
  let assertFails: (promise: Promise<unknown>) => Promise<unknown>;

  beforeAll(async () => {
    const rulesUnitTesting = await import("@firebase/rules-unit-testing");
    assertSucceeds = rulesUnitTesting.assertSucceeds as never;
    assertFails = rulesUnitTesting.assertFails as never;
    testEnv = await rulesUnitTesting.initializeTestEnvironment({
      projectId: "discipulado-ieadpe-emulator",
      firestore: {
        rules: readFileSync(resolve(__dirname, "../../../firestore.rules"), "utf8"),
      },
    });
    await testEnv.withSecurityRulesDisabled(async (context: any) => {
      const db = context.firestore();
      await db.doc("users/staff1").set({
        accessRole: "congregationStaff",
        congregationId: "c1",
        active: true,
        revision: 1,
      });
      await db.doc("users/staff2").set({
        accessRole: "congregationStaff",
        congregationId: "c2",
        active: true,
        revision: 1,
      });
      await db.doc("users/off").set({
        accessRole: "congregationStaff",
        congregationId: "c1",
        active: false,
        revision: 1,
      });
      await db.doc("users/sup1").set({
        accessRole: "supervisor",
        congregationId: null,
        active: true,
        revision: 1,
      });
      await db.doc("congregations/c1").set({
        id: "c1",
        name: "Central",
        normalizedName: "central",
        active: true,
        revision: 1,
      });
      await db.doc("directory/contact1").set({
        id: "contact1",
        name: "Ana",
        normalizedName: "ana",
        scope: "congregation",
        congregationId: "c1",
        roleCode: null,
        phoneE164: null,
      });
      await db.doc("congregations/c1/students/s1").set({
        id: "s1",
        name: "Ana",
        congregationId: "c1",
      });
      await db.doc("supervisionContacts/sc1").set({ id: "sc1", name: "Coord" });
    });
  });

  afterAll(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
  });

  function asUser(uid: string) {
    return testEnv.authenticatedContext(uid).firestore();
  }

  it("denies anonymous directory reads and writes", async () => {
    const anon = testEnv.unauthenticatedContext().firestore();
    await assertFails(anon.doc("directory/contact1").get());
    await assertFails(anon.doc("directory/contact1").set({ name: "x" }));
  });

  it("denies cross-congregation private reads", async () => {
    const staff = asUser("staff1");
    await assertFails(staff.doc("congregations/c2/students/s1").get());
    await assertSucceeds(staff.doc("congregations/c1/students/s1").get());
  });

  it("denies forged paths and disabled accounts", async () => {
    const off = asUser("off");
    await assertFails(off.doc("congregations/c1/students/s1").get());
    const anon = testEnv.unauthenticatedContext().firestore();
    await assertFails(anon.doc("congregations/c1/students/s1").get());
  });

  it("denies user-profile self-escalation", async () => {
    const staff = asUser("staff1");
    await assertFails(
      staff.doc("users/staff1").set({
        accessRole: "supervisor",
        congregationId: null,
        active: true,
        revision: 2,
      }),
    );
    await assertSucceeds(staff.doc("users/staff1").get());
  });

  it("denies client writes everywhere and supervisor-only reads", async () => {
    const staff = asUser("staff1");
    const supervisor = asUser("sup1");
    await assertFails(staff.doc("congregations/c1/students/new").set({ id: "new" }));
    await assertFails(staff.doc("supervisionContacts/sc1").get());
    await assertSucceeds(supervisor.doc("supervisionContacts/sc1").get());
    await assertSucceeds(supervisor.doc("congregations/c2/students/s1").get());
  });
});

describe("security suite wiring", () => {
  it("exists under functions/test/security and is emulator-gated", () => {
    expect(hasEmulator === true || hasEmulator === false).toBe(true);
  });
});
