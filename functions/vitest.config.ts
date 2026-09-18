import { defineConfig } from "vitest/config";

// The emulator-backed security suite must never silently skip, so it is part
// of the `test:emulator` run only. Every other entry point (unit, gate test,
// build) excludes it; `test/emulator-gate.test.ts` proves both the fail-fast
// guard and this wiring.
const emulatorRun = process.env.npm_lifecycle_event === "test:emulator";

export default defineConfig({
  test: {
    include: emulatorRun ? ["test/security/**/*.test.ts"] : ["test/**/*.test.ts"],
    exclude: emulatorRun ? ["test/security/rules.security.test.ts"] : ["test/security/**"],
    environment: "node",
    reporters: ["default"],
    passWithNoTests: false,
  },
});
