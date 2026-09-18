import { describe, expect, it } from "vitest";
import { fixedClock } from "../../src/core/clock";
import { InMemoryDatastore } from "../../src/core/datastore";
import {
  saveCongregationCallable,
  setCongregationArchivedCallable,
} from "../../src/congregations/handlers";
import {
  saveCongregation,
  setCongregationArchived,
} from "../../src/congregations/service";

const clock = fixedClock(new Date("2026-09-18T12:00:00.000Z"));

describe("congregation callable wrappers", () => {
  it("keeps callable wrappers separate from the injectable services", () => {
    expect(typeof saveCongregationCallable).toBe("function");
    expect(typeof setCongregationArchivedCallable).toBe("function");
    expect(typeof saveCongregation).toBe("function");
    expect(typeof setCongregationArchived).toBe("function");
    expect(saveCongregationCallable).not.toBe(saveCongregation);
    expect(setCongregationArchivedCallable).not.toBe(setCongregationArchived);
  });

  it("builds a callable from injected infrastructure", () => {
    const deps = { datastore: new InMemoryDatastore(), clock };
    expect(typeof saveCongregationCallable(deps)).toBe("function");
    expect(typeof setCongregationArchivedCallable(deps)).toBe("function");
  });
});
