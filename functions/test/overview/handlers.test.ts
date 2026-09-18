import { describe, expect, it } from "vitest";
import { fixedClock } from "../../src/core/clock";
import { InMemoryDatastore } from "../../src/core/datastore";
import {
  getOverviewCallable,
  listPendingSessionsCallable,
} from "../../src/overview/handlers";
import {
  InMemoryOverviewReader,
  getOverview,
  listPendingSessions,
} from "../../src/overview/service";

const clock = fixedClock(new Date("2026-09-18T12:00:00.000Z"));

describe("overview callable wrappers", () => {
  it("keeps callable wrappers separate from the injectable services", () => {
    expect(typeof getOverviewCallable).toBe("function");
    expect(typeof listPendingSessionsCallable).toBe("function");
    expect(typeof getOverview).toBe("function");
    expect(typeof listPendingSessions).toBe("function");
    expect(getOverviewCallable).not.toBe(getOverview);
    expect(listPendingSessionsCallable).not.toBe(listPendingSessions);
  });

  it("builds a callable from injected infrastructure", () => {
    const deps = {
      datastore: new InMemoryDatastore(),
      clock,
      reader: new InMemoryOverviewReader(),
    };
    expect(typeof getOverviewCallable(deps)).toBe("function");
    expect(typeof listPendingSessionsCallable(deps)).toBe("function");
  });
});
