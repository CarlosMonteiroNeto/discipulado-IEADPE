import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { assertEmulatorHosts } from "./emulator-guard";

/**
 * Additional emulator-backed rules proof for task 14 (the task-2 security
 * suite is left untouched). Loaded only by `npm run test:emulator`, so the
 * module-scope guard fails fast when the emulator environment is absent and
 * the suite can never report green by being skipped.
 *
 * Sentinel: `rulesRunSentinel` is set only after the emulator fixture has been
 * written, and the first test asserts it, so a skipped run cannot pass.
 */
assertEmulatorHosts(process.env);

let rulesRunSentinel = false;

describe("firestore rules hardening", () => {
  let testEnv: any;
  let assertSucceeds: (promise: Promise<unknown>) => Promise<unknown>;
  let assertFails: (promise: Promise<unknown>) => Promise<unknown>;

  beforeAll(async () => {
    const rulesUnitTesting = await import("@firebase/rules-unit-testing");
    assertSucceeds = rulesUnitTesting.assertSucceeds as never;
    assertFails = rulesUnitTesting.assertFails as never;
    testEnv = await rulesUnitTesting.initializeTestEnvironment({
      projectId: "discipulado-ieadpe-emulator-hardening",
      firestore: {
        rules: readFileSync(resolve(__dirname, "../../../firestore.rules"), "utf8"),
      },
    });
    await testEnv.withSecurityRulesDisabled(async (context: any) => {
      const db = context.firestore();
      await db.doc("users/staff-active").set({
        accessRole: "congregationStaff",
        congregationId: "c1",
        active: true,
        revision: 1,
      });
      await db.doc("users/staff-archived").set({
        accessRole: "congregationStaff",
        congregationId: "c-old",
        active: true,
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
      await db.doc("congregations/c-old").set({
        id: "c-old",
        name: "Antiga",
        normalizedName: "antiga",
        active: false,
        revision: 1,
      });
      await db.doc("congregations/c1/roleSlots/slot1").set({
        id: "slot1",
        roleCode: "teacher",
        holderContactId: "contact1",
      });
      await db.doc("congregations/c1/uniqueness/active-student-s1").set({
        id: "active-student-s1",
      });
      await db.doc("congregations/c1/sessions/s1/roster/e1").set({
        id: "e1",
        studentId: "s1",
      });
    });
    rulesRunSentinel = true;
  });

  afterAll(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
  });

  function asUser(uid: string) {
    return testEnv.authenticatedContext(uid).firestore();
  }

  it("executed the hardening rules run (sentinel)", () => {
    expect(rulesRunSentinel).toBe(true);
  });

  it("denies staff reading their own inactive/archived congregation", async () => {
    const staff = asUser("staff-archived");
    await assertFails(staff.doc("congregations/c-old").get());
  });

  it("allows a supervisor to read the archived congregation", async () => {
    const supervisor = asUser("sup1");
    await assertSucceeds(supervisor.doc("congregations/c-old").get());
  });

  it("denies direct client reads of internal role-slot, uniqueness and roster records", async () => {
    const staff = asUser("staff-active");
    const supervisor = asUser("sup1");
    await assertFails(staff.doc("congregations/c1/roleSlots/slot1").get());
    await assertFails(staff.doc("congregations/c1/uniqueness/active-student-s1").get());
    await assertFails(staff.doc("congregations/c1/sessions/s1/roster/e1").get());
    await assertFails(supervisor.doc("congregations/c1/roleSlots/slot1").get());
    await assertFails(supervisor.doc("congregations/c1/sessions/s1/roster/e1").get());
  });
});
