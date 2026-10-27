import {
  DEFAULT_DATABASE_TIMEOUT_MS,
  DEFAULT_PROVIDER_TIMEOUT_MS,
  INTAKE_RPC_NAME,
  MAX_DEPENDENCY_TIMEOUT_MS,
  MAX_REQUEST_BYTES,
  type OfficialDraft,
  type PublicIntakeError,
  RATE_LIMIT_RETRY_AFTER_SECONDS,
  type ReceiveIntakeRequest,
  type SiteverifyOutcome,
  TURNSTILE_ACTION,
  TURNSTILE_SITEVERIFY_URL,
} from "./contracts.ts";

export interface IntakeDependencies {
  configured: boolean;
  allowedOrigins: readonly string[];
  allowedHostnames: readonly string[];
  verifyTurnstile: (
    token: string,
    signal: AbortSignal,
  ) => Promise<SiteverifyOutcome>;
  receive: (
    request: ReceiveIntakeRequest,
    signal: AbortSignal,
  ) => Promise<unknown>;
  hashNetwork: (address: string) => Promise<string>;
  resolveTrustedAddress: (request: Request) => string | null;
  providerTimeoutMs?: number;
  databaseTimeoutMs?: number;
  decodeJson?: (bytes: Uint8Array) => unknown;
}

type TimeoutOperation<T> = (signal: AbortSignal) => Promise<T>;

class PayloadLimitError extends Error {}
class DependencyTimeoutError extends Error {}

export class IntakeRpcError extends Error {
  readonly status: number;
  readonly code: string | null;

  constructor(status: number, code: string | null, message: string | null) {
    super(message ?? "rpc_failed");
    this.name = "IntakeRpcError";
    this.status = status;
    this.code = code;
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function hasExactKeys(
  value: Record<string, unknown>,
  required: readonly string[],
  optional: readonly string[] = [],
): boolean {
  const allowed = new Set([...required, ...optional]);
  return required.every((key) => Object.hasOwn(value, key)) &&
    Object.keys(value).every((key) => allowed.has(key));
}

function isUuid(value: unknown): value is string {
  return typeof value === "string" &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(
      value,
    );
}

function isNullableString(value: unknown): boolean {
  return value === null || typeof value === "string";
}

function isAddress(value: unknown): boolean {
  if (value === null) return true;
  if (
    !isRecord(value) ||
    !hasExactKeys(value, [
      "street",
      "district",
      "city",
      "postal_code",
      "state_code",
    ])
  ) {
    return false;
  }
  return ["street", "district", "city", "postal_code", "state_code"].every((
    key,
  ) => isNullableString(value[key]));
}

function isOfficialDraft(value: unknown): value is OfficialDraft {
  if (
    !isRecord(value) ||
    !hasExactKeys(value, ["congregation_id", "person", "convert"])
  ) return false;
  if (
    !isUuid(value.congregation_id) || !isRecord(value.person) ||
    !isRecord(value.convert)
  ) return false;

  const person = value.person;
  if (
    !hasExactKeys(person, ["name"], ["phone", "birth_date", "address"]) ||
    typeof person.name !== "string"
  ) {
    return false;
  }
  if (Object.hasOwn(person, "phone") && !isNullableString(person.phone)) {
    return false;
  }
  if (
    Object.hasOwn(person, "birth_date") && !isNullableString(person.birth_date)
  ) return false;
  if (Object.hasOwn(person, "address") && !isAddress(person.address)) {
    return false;
  }

  const convert = value.convert;
  if (
    !hasExactKeys(convert, [
      "landmark",
      "gender",
      "conversion_date",
      "worship_type",
    ], ["age"])
  ) {
    return false;
  }
  if (
    typeof convert.landmark !== "string" ||
    typeof convert.gender !== "string" ||
    typeof convert.conversion_date !== "string" ||
    typeof convert.worship_type !== "string"
  ) return false;
  if (
    Object.hasOwn(convert, "age") && convert.age !== null &&
    typeof convert.age !== "number"
  ) return false;
  return true;
}

function parseSubmission(value: unknown): {
  submissionId: string;
  token: string;
  draft: OfficialDraft;
} | null {
  if (
    !isRecord(value) ||
    !hasExactKeys(value, ["submission_id", "turnstile_token", "draft"])
  ) return null;
  if (
    !isUuid(value.submission_id) || typeof value.turnstile_token !== "string" ||
    value.turnstile_token.trim().length === 0 ||
    value.turnstile_token.length > 2_048 ||
    !isOfficialDraft(value.draft)
  ) return null;
  return {
    submissionId: value.submission_id,
    token: value.turnstile_token,
    draft: value.draft,
  };
}

function canonicalIpAddress(value: string): string | null {
  if (value.length === 0 || value.trim() !== value || value.includes("%")) {
    return null;
  }
  if (value.includes(":")) {
    try {
      const parsed = new URL("http://[" + value + "]/");
      const hostname = parsed.hostname;
      if (!hostname.startsWith("[") || !hostname.endsWith("]")) return null;
      return hostname.slice(1, -1).toLowerCase();
    } catch {
      return null;
    }
  }
  if (!/^[0-9]{1,3}(?:\.[0-9]{1,3}){3}$/.test(value)) return null;
  const octets = value.split(".").map(Number);
  if (octets.some((octet) => octet < 0 || octet > 255)) return null;
  const canonical = octets.join(".");
  return canonical === value ? canonical : null;
}
function validConfiguredOrigin(origin: string): boolean {
  try {
    const parsed = new URL(origin);
    const isSecure = parsed.protocol === "https:";
    const isLoopbackHttp = parsed.protocol === "http:" &&
      ["localhost", "127.0.0.1", "[::1]"].includes(parsed.hostname);
    return (isSecure || isLoopbackHttp) && parsed.origin === origin;
  } catch {
    return false;
  }
}

function requestOrigin(
  request: Request,
  allowedOrigins: readonly string[],
): string | null | undefined {
  const origin = request.headers.get("origin");
  if (origin === null) return null;
  return allowedOrigins.includes(origin) && validConfiguredOrigin(origin)
    ? origin
    : undefined;
}

const CORS_METHODS = "POST, OPTIONS";
const CORS_HEADERS = "authorization, apikey, content-type, x-client-info";
const ALLOWED_REQUEST_HEADERS = [
  "authorization",
  "apikey",
  "content-type",
  "x-client-info",
] as const;

function corsHeaders(origin: string | null): Headers {
  const headers = new Headers({
    "content-type": "application/json; charset=utf-8",
    vary: "Origin",
  });
  if (origin !== null) {
    headers.set("access-control-allow-origin", origin);
    headers.set("access-control-allow-methods", CORS_METHODS);
    headers.set("access-control-allow-headers", CORS_HEADERS);
  }
  return headers;
}

function jsonResponse(
  body: Record<string, string>,
  status: number,
  origin: string | null,
  retryAfter?: number,
): Response {
  const headers = corsHeaders(origin);
  if (retryAfter !== undefined) headers.set("retry-after", String(retryAfter));
  return new Response(JSON.stringify(body), { status, headers });
}

function errorResponse(
  error: PublicIntakeError,
  status: number,
  origin: string | null,
  retryAfter?: number,
): Response {
  return jsonResponse({ error }, status, origin, retryAfter);
}

function optionsResponse(request: Request, origin: string | null): Response {
  if (origin === null) return errorResponse("validation", 400, null);
  const requestedMethod = request.headers.get("access-control-request-method");
  if (requestedMethod !== null && requestedMethod.toUpperCase() !== "POST") {
    return errorResponse("validation", 400, null);
  }
  const requestedHeaders = request.headers.get(
    "access-control-request-headers",
  );
  if (requestedHeaders !== null) {
    const names = requestedHeaders.split(",").map((value) =>
      value.trim().toLowerCase()
    );
    if (
      names.some((name) =>
        name.length === 0 ||
        !ALLOWED_REQUEST_HEADERS.includes(
          name as typeof ALLOWED_REQUEST_HEADERS[number],
        )
      )
    ) {
      return errorResponse("validation", 400, null);
    }
  }
  const headers = new Headers({
    "access-control-allow-origin": origin,
    "access-control-allow-methods": CORS_METHODS,
    "access-control-allow-headers": CORS_HEADERS,
    "access-control-max-age": "600",
    vary: "Origin",
  });
  return new Response(null, { status: 204, headers });
}

async function readLimitedBody(request: Request): Promise<Uint8Array> {
  const contentLength = request.headers.get("content-length");
  if (contentLength !== null) {
    if (!/^(0|[1-9][0-9]*)$/.test(contentLength)) throw new PayloadLimitError();
    if (Number(contentLength) > MAX_REQUEST_BYTES) {
      throw new PayloadLimitError();
    }
  }

  const stream = request.body;
  if (stream === null) throw new PayloadLimitError();
  const reader = stream.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  try {
    while (true) {
      const next = await reader.read();
      if (next.done) break;
      total += next.value.byteLength;
      if (total > MAX_REQUEST_BYTES) {
        await reader.cancel();
        throw new PayloadLimitError();
      }
      chunks.push(next.value);
    }
  } finally {
    reader.releaseLock();
  }

  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return bytes;
}

function decodeRequest(
  bytes: Uint8Array,
  decodeJson?: (bytes: Uint8Array) => unknown,
): unknown {
  if (decodeJson !== undefined) return decodeJson(bytes);
  const source = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  return JSON.parse(source) as unknown;
}

function boundedTimeout(value: number | undefined, fallback: number): number {
  if (!Number.isInteger(value) || value === undefined || value <= 0) {
    return fallback;
  }
  return Math.min(value, MAX_DEPENDENCY_TIMEOUT_MS);
}

async function runWithTimeout<T>(
  timeoutMs: number,
  operation: TimeoutOperation<T>,
): Promise<T> {
  const controller = new AbortController();
  let timeoutId: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<never>((_resolve, reject) => {
    timeoutId = setTimeout(() => {
      const error = new DependencyTimeoutError("dependency_timeout");
      controller.abort(error);
      reject(error);
    }, timeoutMs);
  });
  try {
    return await Promise.race([operation(controller.signal), timeout]);
  } finally {
    if (timeoutId !== undefined) clearTimeout(timeoutId);
  }
}

function safeDatabaseError(
  error: unknown,
): { code: PublicIntakeError; status: number; retryAfter?: number } {
  if (!isRecord(error)) return { code: "unavailable", status: 503 };
  const status = typeof error.status === "number" ? error.status : 0;
  const sqlState = typeof error.code === "string" ? error.code : "";
  const message = typeof error.message === "string" ? error.message : "";

  if (status === 429 || sqlState === "429") {
    return {
      code: "rate_limited",
      status: 429,
      retryAfter: RATE_LIMIT_RETRY_AFTER_SECONDS,
    };
  }
  if (sqlState === "22023") {
    if (message === "invalid_payload") {
      return { code: "validation", status: 400 };
    }
    if (message === "operation_conflict") {
      return { code: "conflict", status: 409 };
    }
    if (message === "rate_limited") {
      return {
        code: "rate_limited",
        status: 429,
        retryAfter: RATE_LIMIT_RETRY_AFTER_SECONDS,
      };
    }
    if (
      message === "intake_paused" || message === "capacity_full" ||
      message === "intake_unavailable"
    ) {
      return { code: "unavailable", status: 503 };
    }
  }
  return { code: "unavailable", status: 503 };
}

function isReceivedResult(value: unknown): boolean {
  return isRecord(value) && Object.keys(value).length === 1 &&
    value.status === "received";
}

export function createIntakeHandler(
  dependencies: IntakeDependencies,
): (request: Request) => Promise<Response> {
  const providerTimeout = boundedTimeout(
    dependencies.providerTimeoutMs,
    DEFAULT_PROVIDER_TIMEOUT_MS,
  );
  const databaseTimeout = boundedTimeout(
    dependencies.databaseTimeoutMs,
    DEFAULT_DATABASE_TIMEOUT_MS,
  );

  return async (request: Request): Promise<Response> => {
    const origin = requestOrigin(request, dependencies.allowedOrigins);
    if (origin === undefined) return errorResponse("validation", 400, null);
    if (request.method === "OPTIONS") return optionsResponse(request, origin);
    if (request.method !== "POST") {
      return errorResponse("validation", 400, origin);
    }
    if (
      !/^application\/json(?:\s*;|\s*$)/i.test(
        request.headers.get("content-type") ?? "",
      )
    ) {
      return errorResponse("validation", 400, origin);
    }
    if (
      !dependencies.configured || dependencies.allowedOrigins.length === 0 ||
      dependencies.allowedHostnames.length === 0
    ) {
      return errorResponse("unavailable", 503, origin);
    }

    let submission: ReturnType<typeof parseSubmission>;
    try {
      const bytes = await readLimitedBody(request);
      submission = parseSubmission(
        decodeRequest(bytes, dependencies.decodeJson),
      );
    } catch {
      return errorResponse("validation", 400, origin);
    }
    if (submission === null) return errorResponse("validation", 400, origin);

    let verification: SiteverifyOutcome;
    try {
      verification = await runWithTimeout(
        providerTimeout,
        (signal) => dependencies.verifyTurnstile(submission.token, signal),
      );
    } catch {
      return errorResponse("unavailable", 503, origin);
    }
    if (
      !isRecord(verification) || verification.success !== true ||
      typeof verification.hostname !== "string" ||
      !dependencies.allowedHostnames.includes(verification.hostname) ||
      verification.action !== TURNSTILE_ACTION
    ) {
      return errorResponse("bot_check_failed", 400, origin);
    }

    let trustedAddress: string | null;
    try {
      trustedAddress = dependencies.resolveTrustedAddress(request);
    } catch {
      return errorResponse("unavailable", 503, origin);
    }
    const canonicalAddress = typeof trustedAddress === "string"
      ? canonicalIpAddress(trustedAddress)
      : null;
    if (trustedAddress !== null && canonicalAddress === null) {
      return errorResponse("unavailable", 503, origin);
    }
    let networkHash: string | null = null;
    if (canonicalAddress !== null) {
      try {
        networkHash = await dependencies.hashNetwork(canonicalAddress);
      } catch {
        return errorResponse("unavailable", 503, origin);
      }
      if (!/^[0-9a-f]{64}$/.test(networkHash)) {
        return errorResponse("unavailable", 503, origin);
      }
    }

    const rpcRequest: ReceiveIntakeRequest = {
      submission_id: submission.submissionId,
      network_hash: networkHash,
      draft: submission.draft,
    };
    let result: unknown;
    try {
      result = await runWithTimeout(
        databaseTimeout,
        (signal) => dependencies.receive(rpcRequest, signal),
      );
    } catch (error) {
      const mapped = safeDatabaseError(error);
      return errorResponse(
        mapped.code,
        mapped.status,
        origin,
        mapped.retryAfter,
      );
    }
    if (!isReceivedResult(result)) {
      return errorResponse("unavailable", 503, origin);
    }
    return jsonResponse({ status: "received" }, 202, origin);
  };
}

export function createTurnstileVerifier(
  fetcher: typeof fetch,
  secret: string,
): (token: string, signal: AbortSignal) => Promise<SiteverifyOutcome> {
  return async (token, signal) => {
    const body = new URLSearchParams({ secret, response: token });
    const response = await fetcher(TURNSTILE_SITEVERIFY_URL, {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: body.toString(),
      signal,
    });
    if (!response.ok) throw new Error("turnstile_unavailable");
    const outcome: unknown = await response.json();
    if (!isRecord(outcome)) throw new Error("turnstile_unavailable");
    return outcome;
  };
}

export function createFixedRpcCaller(options: {
  supabaseUrl: string;
  serviceCredential: string;
  fetcher?: typeof fetch;
}): (request: ReceiveIntakeRequest, signal: AbortSignal) => Promise<unknown> {
  const fetcher = options.fetcher ?? fetch;
  return async (request, signal) => {
    const url = new URL(`/rest/v1/rpc/${INTAKE_RPC_NAME}`, options.supabaseUrl)
      .toString();
    const response = await fetcher(url, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        apikey: options.serviceCredential,
        authorization: `Bearer ${options.serviceCredential}`,
      },
      body: JSON.stringify({ request }),
      signal,
    });
    if (!response.ok) {
      let errorCode: string | null = null;
      let message: string | null = null;
      try {
        const body: unknown = await response.json();
        if (isRecord(body)) {
          errorCode = typeof body.code === "string" ? body.code : null;
          message = typeof body.message === "string" ? body.message : null;
        }
      } catch {
        // Keep the remote response private; the handler maps unknown failures to unavailable.
      }
      throw new IntakeRpcError(response.status, errorCode, message);
    }
    return await response.json() as unknown;
  };
}

export async function hmacSha256(
  secret: string,
  message: string,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(message),
  );
  return Array.from(
    new Uint8Array(signature),
    (byte) => byte.toString(16).padStart(2, "0"),
  ).join("");
}

/**
 * No provider document currently establishes that an address header received by a
 * managed Edge Function is provider-authenticated. Keep intake fail-closed until
 * hosted gateway semantics are verified; never treat caller-supplied XFF/CF headers
 * as authoritative by default.
 */
export function resolveSupabaseEdgeClientAddress(
  _request: Request,
): string | null {
  return null;
}
