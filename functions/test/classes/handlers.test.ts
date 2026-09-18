import { describe, expect, it } from "vitest";
import {
  saveClassCallable,
  setClassStatusCallable,
} from "../../src/classes/handlers";
import {
  InMemoryClassSessionReader,
  saveClass,
  setClassStatus,
} from "../../src/classes/service";
import { fixedClock } from "../../src/core/clock";
import { InMemoryDatastore } from "../../src/core/datastore";

const clock = fixedClock(new Date("2026-09-18T12:00:00.000Z"));

describe("class callable wrappers", () => {
  it("keeps callable wrappers separate from the injectable services", () => {
    expect(typeof saveClassCallable).toBe("function");
    expect(typeof setClassStatusCallable).toBe("function");
    expect(typeof saveClass).toBe("function");
    expect(typeof setClassStatus).toBe("function");
    expect(saveClassCallable).not.toBe(saveClass);
    expect(setClassStatusCallable).not.toBe(setClassStatus);
  });

  it("builds a callable from injected infrastructure", () => {
    const deps = {
      datastore: new InMemoryDatastore(),
      clock,
      sessions: new InMemoryClassSessionReader(),
    };
    expect(typeof saveClassCallable(deps)).toBe("function");
    expect(typeof setClassStatusCallable(deps)).toBe("function");
  });
});
