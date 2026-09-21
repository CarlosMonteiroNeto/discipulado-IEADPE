import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { assertEmulatorHosts } from "./emulator-guard";

/**
 * Additional emulator-backed rules proof for the internal-mode write matrix
 * (loaded only by `npm run test:emulator`, so the module-scope guard fails
 * fast when the emulator environment is absent and the suite can never report
 * green by being skipped). The task-10 re-pinned `rules.security.test.ts` is
 * left untouched.
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
        congregationId: "c1",
      });
      await db.doc("congregations/c-old/roleSlots/slot-old").set({
        id: "slot-old",
        roleCode: "teacher",
        holderContactId: "contact-old",
        congregationId: "c-old",
      });
      await db.doc("congregations/c1/sessions/s1/roster/e1").set({
        id: "e1",
        studentId: "s1",
        congregationId: "c1",
      });
      await db.doc("supervisionContacts/sc1").set({ id: "sc1", name: "Coord" });
      await db.doc("supervisionRoleSlots/srs1").set({ id: "srs1", roleCode: "coordinator" });
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

  it("makes roleSlots and roster scoped-readable and writable for authorized staff", async () => {
    const staff = asUser("staff-active");
    await assertSucceeds(staff.doc("congregations/c1/roleSlots/slot1").get());
    await assertSucceeds(staff.doc("congregations/c1/sessions/s1/roster/e1").get());
    await assertSucceeds(staff.doc("congregations/c1/roleSlots/slot2").set({
      id: "slot2",
      roleCode: "helper",
      holderContactId: "contact1",
      congregationId: "c1",
    }));
    await assertSucceeds(staff.doc("congregations/c1/sessions/s1/roster/e2").set({
      id: "e2",
      studentId: "s9",
      congregationId: "c1",
    }));
  });

  it("seals cross-congregation internal records from staff and keeps supervisor scope open", async () => {
    const staff = asUser("staff-active");
    const supervisor = asUser("sup1");
    await assertFails(staff.doc("congregations/c-old/roleSlots/slot-old").get());
    await assertFails(staff.doc("congregations/c-old/roleSlots/slot-old").set({
      id: "slot-old",
      roleCode: "supervisor",
      congregationId: "c-old",
    }));
    await assertSucceeds(supervisor.doc("congregations/c-old/roleSlots/slot-old").get());
  });

  it("keeps supervision records supervisor-only", async () => {
    const staff = asUser("staff-active");
    const supervisor = asUser("sup1");
    await assertFails(staff.doc("supervisionContacts/sc1").get());
    await assertFails(staff.doc("supervisionContacts/sc2").set({ id: "sc2" }));
    await assertFails(staff.doc("supervisionRoleSlots/srs1").get());
    await assertSucceeds(supervisor.doc("supervisionContacts/sc1").get());
    await assertSucceeds(supervisor.doc("supervisionContacts/sc2").set({ id: "sc2" }));
    await assertSucceeds(supervisor.doc("supervisionRoleSlots/srs1").get());
  });

  it("denies every unenumerated path, including the retired uniqueness records", async () => {
    const staff = asUser("staff-active");
    const supervisor = asUser("sup1");
    for (const user of [staff, supervisor]) {
      await assertFails(user.doc("congregations/c1/uniqueness/active-student-s1").get());
      await assertFails(user.doc("congregations/c1/uniqueness/active-student-s1").set({
        id: "active-student-s1",
      }));
      await assertFails(user.doc("congregations/c1/private/x").get());
    }
  });
});