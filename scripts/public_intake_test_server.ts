// Host-only local journey seam. This file is outside supabase/functions and is
// never deployed. It uses the production handler with deterministic verifier,
// address, and network hash dependencies, while writing through the real local
// service-role RPC.
import {
  createFixedRpcCaller,
  createIntakeHandler,
  hmacSha256,
} from "../supabase/functions/public-intake/handler.ts";
import { TURNSTILE_ACTION } from "../supabase/functions/public-intake/contracts.ts";

function required(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error("Missing local test server configuration.");
  return value;
}

function isLoopbackApi(value: string): boolean {
  try {
    const url = new URL(value);
    return url.protocol === "http:" &&
      ["localhost", "127.0.0.1", "[::1]"].includes(url.hostname) &&
      url.username.length === 0 && url.password.length === 0 &&
      url.pathname === "/" && url.search.length === 0 && url.hash.length === 0;
  } catch {
    return false;
  }
}

const supabaseUrl = required("JOURNEY_LOCAL_API_URL");
const serviceCredential = required("JOURNEY_LOCAL_SERVICE_ROLE_KEY");
const runId = required("JOURNEY_RUN_ID");
const allowedOrigin = required("JOURNEY_ALLOWED_ORIGIN");
const port = Number(required("JOURNEY_TEST_PORT"));
const parsedRunId = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

if (
  !isLoopbackApi(supabaseUrl) ||
  !parsedRunId.test(runId) ||
  allowedOrigin !== "http://127.0.0.1:7357" ||
  !Number.isInteger(port) || port < 1 || port > 65535
) {
  throw new Error("Unsafe local test server configuration.");
}

const endpoint = createIntakeHandler({
  configured: true,
  allowedOrigins: [allowedOrigin],
  allowedHostnames: ["127.0.0.1"],
  verifyTurnstile: async (token) => ({
    success: token.startsWith(`journey-test:${runId}:`),
    hostname: "127.0.0.1",
    action: TURNSTILE_ACTION,
  }),
  receive: createFixedRpcCaller({
    supabaseUrl,
    serviceCredential,
  }),
  hashNetwork: (address) =>
    hmacSha256(`journey-test-network:${runId}`, address),
  // This loopback-only seam never reads or accepts caller-supplied address headers.
  resolveTrustedAddress: () => "192.0.2.17",
});

Deno.serve({ hostname: "127.0.0.1", port }, async (request) => {
  const url = new URL(request.url);
  if (request.method === "GET" && url.pathname === "/__journey_health") {
    return Response.json({ ready: true }, {
      headers: { "cache-control": "no-store" },
    });
  }
  if (url.pathname !== "/functions/v1/public-intake") {
    return new Response(null, { status: 404 });
  }
  return await endpoint(request);
});
