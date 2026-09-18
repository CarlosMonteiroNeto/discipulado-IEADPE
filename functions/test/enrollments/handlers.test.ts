import { describe, expect, it } from "vitest";
import { InMemoryClassSessionReader } from "../../src/classes/service";
import { fixedClock } from "../../src/core/clock";
import { InMemoryDatastore } from "../../src/core/datastore";
import {
  closeEnrollmentCallable,
  enrollStudentCallable,
} from "../../src/enrollments/handlers";
import {
  closeEnrollment,
  enrollStudent,
} from "../../src/enrollments/service";

const clock = fixedClock(new Date("2026-09-18T12:00:00.000Z"));

describe("enrollment callable wrappers", () => {
  it("keeps callable wrappers separate from the injectable services", () => {
    expect(typeof enrollStudentCallable).toBe("function");
    expect(typeof closeEnrollmentCallable).toBe("function");
    expect(typeof enrollStudent).toBe("function");
    expect(typeof closeEnrollment).toBe("function");
    expect(enrollStudentCallable).not.toBe(enrollStudent);
    expect(closeEnrollmentCallable).not.toBe(closeEnrollment);
  });

  it("builds a callable from injected infrastructure", () => {
    const deps = {
      datastore: new InMemoryDatastore(),
      clock,
      sessions: new InMemoryClassSessionReader(),
    };
    expect(typeof enrollStudentCallable(deps)).toBe("function");
    expect(typeof closeEnrollmentCallable(deps)).toBe("function");
  });
});
