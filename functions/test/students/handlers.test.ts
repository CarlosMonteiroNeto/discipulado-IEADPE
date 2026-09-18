import { describe, expect, it } from "vitest";
import { fixedClock } from "../../src/core/clock";
import { InMemoryDatastore } from "../../src/core/datastore";
import {
  listClassStudentsCallable,
  saveStudentCallable,
  setStudentArchivedCallable,
} from "../../src/students/handlers";
import { InMemoryStudentDirectory } from "../../src/students/queries";
import { saveStudent, setStudentArchived } from "../../src/students/service";
import { listClassStudents } from "../../src/students/queries";

const clock = fixedClock(new Date("2026-09-18T12:00:00.000Z"));

describe("student callable wrappers", () => {
  it("keeps callable wrappers separate from the injectable services", () => {
    expect(typeof saveStudentCallable).toBe("function");
    expect(typeof setStudentArchivedCallable).toBe("function");
    expect(typeof listClassStudentsCallable).toBe("function");
    expect(typeof saveStudent).toBe("function");
    expect(typeof setStudentArchived).toBe("function");
    expect(typeof listClassStudents).toBe("function");
    expect(saveStudentCallable).not.toBe(saveStudent);
    expect(setStudentArchivedCallable).not.toBe(setStudentArchived);
    expect(listClassStudentsCallable).not.toBe(listClassStudents);
  });

  it("builds a callable from injected infrastructure", () => {
    const deps = {
      datastore: new InMemoryDatastore(),
      clock,
      directory: new InMemoryStudentDirectory(),
    };
    expect(typeof saveStudentCallable(deps)).toBe("function");
    expect(typeof setStudentArchivedCallable(deps)).toBe("function");
    expect(typeof listClassStudentsCallable(deps)).toBe("function");
  });
});
