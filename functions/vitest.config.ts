import { defineConfig } from "vitest/config";

// The emulator-backed security suites only run under `test:emulator`; every
// other entry point excludes all of test/security/**, so no security test can
// run without emulators. The emulator branch stays non-skippable through the
// module-scope `assertEmulatorHosts` guard and the package.json host check, so
// it must NOT exclude any suite: both the committed task-2 anonymous/cross-
// scope denial matrix and the task-14 hardening suite execute there.
const emulatorRun = process.env.npm_lifecycle_event === "test:emulator";

export default defineConfig({
  test: {
    include: emulatorRun ? ["test/security/**/*.test.ts"] : ["test/**/*.test.ts"],
    exclude: emulatorRun ? [] : ["test/security/**"],
    environment: "node",
    reporters: ["default"],
    passWithNoTests: false,
  },
});
