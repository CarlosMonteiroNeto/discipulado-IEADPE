import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { describe, expect, it } from "vitest";

const root = resolve(__dirname, "../..");
const functionsDir = resolve(__dirname, "..");

function readJson(path: string): Record<string, unknown> {
  return JSON.parse(readFileSync(path, "utf8")) as Record<string, unknown>;
}

describe("backend infrastructure manifests", () => {
  it("declares the local Auth, Firestore and Functions emulators", () => {
    const firebase = readJson(resolve(root, "firebase.json"));
    const emulators = firebase.emulators as Record<string, Record<string, unknown>>;
    expect(emulators.auth.port).toBe(9099);
    expect(emulators.firestore.port).toBe(8080);
    expect(emulators.functions.port).toBe(5001);
  });

  it("binds hosting rewrites to the web SPA without a production project binding", () => {
    const firebase = readJson(resolve(root, "firebase.json"));
    const hosting = firebase.hosting as { rewrites?: Array<Record<string, string>> };
    expect(Array.isArray(hosting.rewrites)).toBe(true);
    expect(hosting.rewrites?.[0]).toEqual({
      source: "**",
      destination: "/index.html",
    });
    expect(Object.prototype.hasOwnProperty.call(firebase, "projectId")).toBe(false);
    expect(JSON.stringify(firebase)).not.toContain("projects/");
  });

  it("ships deny-by-default Firestore rules", () => {
    const rulesPath = resolve(root, "firestore.rules");
    expect(existsSync(rulesPath)).toBe(true);
    const rules = readFileSync(rulesPath, "utf8");
    expect(rules).toContain("service cloud.firestore");
    expect(rules).toContain("allow write: if false");
    expect(rules).toContain("match /directory/{contactId}");
    expect(rules).toContain("match /supervisionContacts/{contactId}");
  });

  it("declares composite indexes for the shipped query matrix", () => {
    const indexes = readJson(resolve(root, "firestore.indexes.json"));
    expect(Array.isArray(indexes.indexes)).toBe(true);
    expect((indexes.indexes as unknown[]).length).toBeGreaterThanOrEqual(8);
  });

  it("provides build, unit-test and emulator-test entry points", () => {
    const pkg = readJson(resolve(functionsDir, "package.json"));
    const scripts = pkg.scripts as Record<string, string>;
    expect(scripts.build).toBeTruthy();
    expect(scripts.test).toBeTruthy();
    expect(scripts["test:emulator"]).toBeTruthy();
  });

  it("locks compatible backend dependencies", () => {
    const lockPath = resolve(functionsDir, "package-lock.json");
    expect(existsSync(lockPath)).toBe(true);
    const lock = readJson(lockPath);
    expect(Number(lock.lockfileVersion)).toBeGreaterThanOrEqual(3);
    const packages = lock.packages as Record<string, unknown>;
    expect(packages["node_modules/firebase-admin"]).toBeTruthy();
    expect(packages["node_modules/firebase-functions"]).toBeTruthy();
    expect(packages["node_modules/typescript"]).toBeTruthy();
    expect(packages["node_modules/vitest"]).toBeTruthy();
  });

  it("compiles with strict TypeScript", () => {
    const tsconfig = readJson(resolve(functionsDir, "tsconfig.json"));
    const compilerOptions = tsconfig.compilerOptions as Record<string, unknown>;
    expect(compilerOptions.strict).toBe(true);
  });
});
