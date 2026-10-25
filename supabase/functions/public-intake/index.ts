import {
  createFixedRpcCaller,
  createIntakeHandler,
  createTurnstileVerifier,
  hmacSha256,
  resolveSupabaseEdgeClientAddress,
} from "./handler.ts";

function csv(value: string | undefined): string[] {
  return (value ?? "").split(",").map((item) => item.trim()).filter((item) =>
    item.length > 0
  );
}

function isSupabaseUrl(value: string | undefined): value is string {
  if (value === undefined || value.length === 0) return false;
  try {
    const url = new URL(value);
    return (url.protocol === "https:" || url.protocol === "http:") &&
      url.username.length === 0 && url.password.length === 0 &&
      url.pathname === "/" && url.search.length === 0 && url.hash.length === 0;
  } catch {
    return false;
  }
}

function isCanonicalOrigin(value: string): boolean {
  try {
    const url = new URL(value);
    const isSecure = url.protocol === "https:";
    const isLoopbackHttp = url.protocol === "http:" &&
      ["localhost", "127.0.0.1", "[::1]"].includes(url.hostname);
    return (isSecure || isLoopbackHttp) && url.origin === value;
  } catch {
    return false;
  }
}

function isHostname(value: string): boolean {
  if (
    value.length === 0 || value.length > 253 || value.includes("*") ||
    value.includes(":")
  ) return false;
  return value.split(".").every((label) =>
    label.length > 0 && label.length <= 63 &&
    /^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/i.test(label)
  );
}

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const serviceCredential = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const turnstileSecret = Deno.env.get("TURNSTILE_SECRET_KEY");
const networkHashSecret = Deno.env.get("INTAKE_NETWORK_HASH_SECRET");
const allowedOrigins = csv(Deno.env.get("INTAKE_ALLOWED_ORIGINS"));
const allowedHostnames = csv(Deno.env.get("INTAKE_ALLOWED_HOSTNAMES")).map((
  hostname,
) => hostname.toLowerCase());

const configured = isSupabaseUrl(supabaseUrl) &&
  typeof serviceCredential === "string" && serviceCredential.length > 0 &&
  typeof turnstileSecret === "string" && turnstileSecret.length > 0 &&
  typeof networkHashSecret === "string" && networkHashSecret.length > 0 &&
  allowedOrigins.length > 0 && allowedOrigins.every(isCanonicalOrigin) &&
  allowedHostnames.length > 0 && allowedHostnames.every(isHostname);

const handler = createIntakeHandler({
  configured,
  allowedOrigins,
  allowedHostnames,
  verifyTurnstile: createTurnstileVerifier(fetch, turnstileSecret ?? ""),
  receive: createFixedRpcCaller({
    supabaseUrl: supabaseUrl ?? "",
    serviceCredential: serviceCredential ?? "",
    fetcher: fetch,
  }),
  hashNetwork: (address) => hmacSha256(networkHashSecret ?? "", address),
  resolveTrustedAddress: resolveSupabaseEdgeClientAddress,
});

Deno.serve(handler);
