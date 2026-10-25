import {
  createFixedRpcCaller,
  createIntakeHandler,
  createTurnstileVerifier,
  hmacSha256,
  resolveSupabaseEdgeClientAddress,
} from "./handler.ts";

const ORIGIN = "https://church.example";
const PREVIEW_ORIGIN = "https://preview.church.example";
const ADDRESS = "203.0.113.7";
const SUBMISSION_ID = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const CONGREGATION_ID = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
const encoder = new TextEncoder();

type VerifyResult = {
  success: boolean;
  hostname?: string;
  action?: string;
  errorCodes?: string[];
};
type ReceiveInput = {
  submission_id: string;
  network_hash: string;
  draft: Record<string, unknown>;
};
type HarnessOptions = {
  configured?: boolean;
  origins?: string[];
  hostnames?: string[];
  address?: string | null;
  verifyTurnstile?: (
    token: string,
    signal: AbortSignal,
  ) => Promise<VerifyResult>;
  receive?: (input: ReceiveInput, signal: AbortSignal) => Promise<unknown>;
  hashNetwork?: (address: string) => Promise<string>;
  resolveTrustedAddress?: (request: Request) => string | null;
  decodeJson?: (bytes: Uint8Array) => unknown;
  providerTimeoutMs?: number;
  databaseTimeoutMs?: number;
};

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

function assertEquals(
  actual: unknown,
  expected: unknown,
  message: string,
): void {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `${message}: expected ${JSON.stringify(expected)}, received ${
        JSON.stringify(actual)
      }`,
    );
  }
}

function validPayload(): Record<string, unknown> {
  return {
    submission_id: SUBMISSION_ID,
    turnstile_token: "turnstile-token",
    draft: {
      congregation_id: CONGREGATION_ID,
      person: {
        name: "Ana Silva",
        phone: null,
        birth_date: null,
        address: null,
      },
      convert: {
        landmark: "Praca Central",
        gender: "female",
        conversion_date: "2026-10-25",
        worship_type: "Culto regular",
        age: null,
      },
    },
  };
}

function makeHarness(options: HarnessOptions = {}) {
  const received: ReceiveInput[] = [];
  const verifiedTokens: string[] = [];
  const hashedAddresses: string[] = [];
  const decodedBodies: Uint8Array[] = [];
  const dependencies = {
    configured: options.configured ?? true,
    allowedOrigins: options.origins ?? [ORIGIN, PREVIEW_ORIGIN],
    allowedHostnames: options.hostnames ??
      ["church.example", "preview.church.example"],
    providerTimeoutMs: options.providerTimeoutMs ?? 1000,
    databaseTimeoutMs: options.databaseTimeoutMs ?? 1000,
    verifyTurnstile: options.verifyTurnstile ?? (async (token: string) => {
      verifiedTokens.push(token);
      return {
        success: true,
        hostname: "church.example",
        action: "public_intake",
      };
    }),
    receive: options.receive ?? (async (input: ReceiveInput) => {
      received.push(structuredClone(input));
      return { status: "received" };
    }),
    hashNetwork: options.hashNetwork ?? (async (address: string) => {
      hashedAddresses.push(address);
      return "a".repeat(64);
    }),
    resolveTrustedAddress: options.resolveTrustedAddress ??
      (() => options.address === undefined ? ADDRESS : options.address),
    decodeJson: options.decodeJson ?? ((bytes: Uint8Array) => {
      decodedBodies.push(bytes);
      return JSON.parse(
        new TextDecoder("utf-8", { fatal: true }).decode(bytes),
      );
    }),
  };
  return {
    handler: createIntakeHandler(dependencies),
    received,
    verifiedTokens,
    hashedAddresses,
    decodedBodies,
  };
}

function postRequest(
  body: string | Uint8Array,
  options: { origin?: string | null; contentLength?: string } = {},
): Request {
  const headers = new Headers({ "content-type": "application/json" });
  if (options.origin !== null) headers.set("origin", options.origin ?? ORIGIN);
  if (options.contentLength !== undefined) {
    headers.set("content-length", options.contentLength);
  }
  return new Request("https://supabase.example/functions/v1/public-intake", {
    method: "POST",
    headers,
    body: typeof body === "string" ? body : body as unknown as BodyInit,
  });
}

function encodePayload(payload: unknown): Uint8Array {
  return encoder.encode(JSON.stringify(payload));
}

function padJsonToBytes(size: number): Uint8Array {
  const text = JSON.stringify(validPayload());
  const bytes = encoder.encode(text);
  assert(bytes.length <= size, "fixture must fit under the requested size");
  return encoder.encode(text + " ".repeat(size - bytes.length));
}

async function expectError(
  response: Response,
  status: number,
  error: string,
): Promise<void> {
  assertEquals(response.status, status, `${error} status`);
  assertEquals(await response.json(), { error }, `${error} public mapping`);
}

Deno.test("invalid_bot_never_reaches_database", async () => {
  const invalidResults: VerifyResult[] = [
    { success: false, errorCodes: ["invalid-input-response"] },
    { success: false, errorCodes: ["timeout-or-duplicate"] },
    { success: true, hostname: "attacker.example", action: "public_intake" },
    { success: true, hostname: "church.example", action: "other_action" },
    { success: true, action: "public_intake" },
  ];
  for (const result of invalidResults) {
    const harness = makeHarness({ verifyTurnstile: async () => result });
    await expectError(
      await harness.handler(postRequest(encodePayload(validPayload()))),
      400,
      "bot_check_failed",
    );
    assertEquals(
      harness.received.length,
      0,
      "invalid, expired, replayed, wrong-host and wrong-action tokens never reach database",
    );
  }
});

Deno.test("payload_limit_rejects_before_decode", async () => {
  for (const size of [16 * 1024 - 1, 16 * 1024]) {
    const harness = makeHarness();
    const response = await harness.handler(
      postRequest(padJsonToBytes(size), { contentLength: String(size) }),
    );
    assertEquals(response.status, 202, `${size}-byte request is accepted`);
  }

  let decodeCalls = 0;
  let cancelled = false;
  const bytes = padJsonToBytes(16 * 1024 + 1);
  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      controller.enqueue(bytes);
    },
    cancel() {
      cancelled = true;
    },
  });
  const request = new Request(
    "https://supabase.example/functions/v1/public-intake",
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        origin: ORIGIN,
        "content-length": "1",
      },
      body: stream,
    },
  );
  const overLimit = makeHarness({
    decodeJson: () => {
      decodeCalls++;
      return {};
    },
  });
  await expectError(await overLimit.handler(request), 400, "validation");
  assertEquals(
    decodeCalls,
    0,
    "streamed size is checked before JSON decoding even with a false Content-Length",
  );
  assert(cancelled, "oversized stream is cancelled immediately");

  const advertisedOverLimit = makeHarness({
    decodeJson: () => {
      decodeCalls++;
      return {};
    },
  });
  await expectError(
    await advertisedOverLimit.handler(
      postRequest(bytes, { contentLength: String(bytes.length) }),
    ),
    400,
    "validation",
  );
  assertEquals(
    decodeCalls,
    0,
    "oversized Content-Length is rejected before decoding",
  );
});

Deno.test("strict_schema_rejects_malformed_json_unknown_keys_and_photo_fields", async () => {
  const invalidBodies: string[] = [
    "{",
    "null",
    "[]",
    JSON.stringify({ ...validPayload(), extra: true }),
    JSON.stringify({
      ...validPayload(),
      draft: { ...(validPayload().draft as object), status: "pending" },
    }),
    JSON.stringify({
      ...validPayload(),
      draft: {
        ...(validPayload().draft as object),
        actor_id: "00000000-0000-4000-8000-000000000001",
      },
    }),
    JSON.stringify({
      ...validPayload(),
      draft: {
        ...(validPayload().draft as object),
        convert: {
          ...((validPayload().draft as Record<string, unknown>)
            .convert as object),
          photo_asset_id: null,
        },
      },
    }),
    JSON.stringify({
      ...validPayload(),
      draft: {
        ...(validPayload().draft as object),
        person: {
          ...((validPayload().draft as Record<string, unknown>)
            .person as object),
          photo_asset_id: null,
        },
      },
    }),
    JSON.stringify({
      ...validPayload(),
      draft: {
        ...(validPayload().draft as object),
        person: {
          ...((validPayload().draft as Record<string, unknown>)
            .person as object),
          unknown: true,
        },
      },
    }),
    JSON.stringify({
      ...validPayload(),
      draft: {
        ...(validPayload().draft as object),
        convert: {
          ...((validPayload().draft as Record<string, unknown>)
            .convert as object),
          unknown: true,
        },
      },
    }),
    JSON.stringify({
      ...validPayload(),
      draft: {
        ...(validPayload().draft as object),
        convert: {
          ...((validPayload().draft as Record<string, unknown>)
            .convert as object),
          photo_bytes: "bytes",
        },
      },
    }),
    JSON.stringify({ ...validPayload(), turnstile_token: "" }),
    JSON.stringify({ ...validPayload(), turnstile_token: "t".repeat(2049) }),
    JSON.stringify({ ...validPayload(), submission_id: "not-a-uuid" }),
  ];
  for (const body of invalidBodies) {
    const harness = makeHarness();
    await expectError(
      await harness.handler(postRequest(body)),
      400,
      "validation",
    );
    assertEquals(
      harness.verifiedTokens.length,
      0,
      "invalid schemas do not reach Turnstile",
    );
    assertEquals(
      harness.received.length,
      0,
      "invalid schemas do not reach database",
    );
  }
});

Deno.test("origin_is_not_identity", async () => {
  const hashed: string[] = [];
  const harness = makeHarness({
    hashNetwork: async (address) => {
      hashed.push(address);
      return "b".repeat(64);
    },
  });
  const payload = encodePayload(validPayload());
  const first = await harness.handler(postRequest(payload, { origin: ORIGIN }));
  const second = await harness.handler(
    postRequest(payload, { origin: PREVIEW_ORIGIN }),
  );
  assertEquals(first.status, 202, "allowed primary origin is accepted");
  assertEquals(second.status, 202, "allowed preview origin is accepted");
  assertEquals(
    hashed,
    [ADDRESS, ADDRESS],
    "changing Origin does not change trusted address input",
  );
  assertEquals(
    harness.received[0].network_hash,
    harness.received[1].network_hash,
    "Origin never affects network hash",
  );
  assertEquals(
    harness.received[0].submission_id,
    SUBMISSION_ID,
    "submission key is forwarded unchanged",
  );
});

Deno.test("lost_response_retry_uses_same_key", async () => {
  let databaseAttempts = 0;
  const seenKeys: string[] = [];
  const seenTokens: string[] = [];
  const harness = makeHarness({
    verifyTurnstile: async (token) => {
      seenTokens.push(token);
      return {
        success: true,
        hostname: "church.example",
        action: "public_intake",
      };
    },
    receive: async (input) => {
      databaseAttempts++;
      seenKeys.push(input.submission_id);
      if (databaseAttempts === 1) {
        throw new Error("simulated lost response after server commit");
      }
      return { status: "received" };
    },
  });
  const firstPayload = validPayload();
  const first = await harness.handler(postRequest(encodePayload(firstPayload)));
  await expectError(first, 503, "unavailable");
  const retryPayload = {
    ...validPayload(),
    turnstile_token: "fresh-turnstile-token",
  };
  const retry = await harness.handler(postRequest(encodePayload(retryPayload)));
  assertEquals(retry.status, 202, "fresh token retry is acknowledged");
  assertEquals(
    await retry.json(),
    { status: "received" },
    "retry returns only generic acknowledgment",
  );
  assertEquals(
    seenKeys,
    [SUBMISSION_ID, SUBMISSION_ID],
    "retry keeps the same idempotency key",
  );
  assertEquals(
    seenTokens,
    ["turnstile-token", "fresh-turnstile-token"],
    "retry uses a fresh bot token",
  );
});

Deno.test("trusted_ip_cannot_be_spoofed", async () => {
  const harness = makeHarness({
    resolveTrustedAddress: resolveSupabaseEdgeClientAddress,
  });
  const request = postRequest(encodePayload(validPayload()));
  request.headers.set("x-forwarded-for", "198.51.100.44");
  request.headers.set("cf-connecting-ip", "198.51.100.45");
  await expectError(await harness.handler(request), 503, "unavailable");
  assertEquals(
    harness.verifiedTokens,
    ["turnstile-token"],
    "bot verification still runs before the unresolved address blocks submission",
  );
  assertEquals(
    harness.received.length,
    0,
    "unverified forwarding headers never reach the intake RPC",
  );
  assertEquals(
    harness.hashedAddresses.length,
    0,
    "unverified address is never HMACed",
  );
});

Deno.test("origin_policy_and_options_are_exact", async () => {
  const allowed = makeHarness();
  const preflight = await allowed.handler(
    new Request("https://supabase.example/functions/v1/public-intake", {
      method: "OPTIONS",
      headers: {
        origin: ORIGIN,
        "access-control-request-method": "POST",
        "access-control-request-headers": "content-type",
      },
    }),
  );
  assertEquals(preflight.status, 204, "allowed OPTIONS succeeds");
  assertEquals(
    preflight.headers.get("access-control-allow-origin"),
    ORIGIN,
    "preflight reflects only exact allowed origin",
  );
  assert(
    preflight.headers.get("access-control-allow-methods")?.includes("POST"),
    "preflight advertises POST",
  );
  assertEquals(
    allowed.verifiedTokens.length,
    0,
    "preflight does not call Turnstile",
  );
  assertEquals(allowed.received.length, 0, "preflight does not call database");

  const denied = makeHarness();
  const deniedPreflight = await denied.handler(
    new Request("https://supabase.example/functions/v1/public-intake", {
      method: "OPTIONS",
      headers: { origin: "https://evil.example" },
    }),
  );
  await expectError(deniedPreflight, 400, "validation");
  assertEquals(
    deniedPreflight.headers.get("access-control-allow-origin"),
    null,
    "disallowed origin receives no CORS grant",
  );
  assertEquals(
    denied.verifiedTokens.length,
    0,
    "disallowed origin is rejected before Turnstile",
  );
  assertEquals(
    denied.received.length,
    0,
    "disallowed origin is rejected before database",
  );

  const invalidContentType = makeHarness();
  await expectError(
    await invalidContentType.handler(
      new Request("https://supabase.example/functions/v1/public-intake", {
        method: "POST",
        headers: { origin: ORIGIN, "content-type": "text/plain" },
        body: "{}",
      }),
    ),
    400,
    "validation",
  );
  assertEquals(
    invalidContentType.verifiedTokens.length,
    0,
    "wrong media type is rejected before provider calls",
  );
});

Deno.test("provider_and_database_timeouts_fail_closed", async () => {
  const providerTimeout = makeHarness({
    providerTimeoutMs: 5,
    verifyTurnstile: (_token, signal) =>
      new Promise((_resolve, reject) => {
        signal.addEventListener("abort", () => reject(signal.reason), {
          once: true,
        });
      }),
  });
  await expectError(
    await providerTimeout.handler(postRequest(encodePayload(validPayload()))),
    503,
    "unavailable",
  );
  assertEquals(
    providerTimeout.received.length,
    0,
    "provider timeout never reaches database",
  );

  const databaseTimeout = makeHarness({
    databaseTimeoutMs: 5,
    receive: (_input, signal) =>
      new Promise((_resolve, reject) => {
        signal.addEventListener("abort", () => reject(signal.reason), {
          once: true,
        });
      }),
  });
  await expectError(
    await databaseTimeout.handler(postRequest(encodePayload(validPayload()))),
    503,
    "unavailable",
  );
});

Deno.test("sql_errors_map_to_only_safe_public_codes", async () => {
  const errors: Array<
    { error: unknown; status: number; code: string; retry?: boolean }
  > = [
    {
      error: { status: 429, code: "PGRST", message: "raw private SQL detail" },
      status: 429,
      code: "rate_limited",
      retry: true,
    },
    {
      error: { status: 400, code: "22023", message: "invalid_payload" },
      status: 400,
      code: "validation",
    },
    {
      error: { status: 400, code: "22023", message: "operation_conflict" },
      status: 409,
      code: "conflict",
    },
    {
      error: { status: 400, code: "22023", message: "rate_limited" },
      status: 429,
      code: "rate_limited",
      retry: true,
    },
    {
      error: { status: 400, code: "22023", message: "intake_paused" },
      status: 503,
      code: "unavailable",
    },
    {
      error: { status: 400, code: "22023", message: "capacity_full" },
      status: 503,
      code: "unavailable",
    },
    {
      error: { status: 400, code: "22023", message: "intake_unavailable" },
      status: 503,
      code: "unavailable",
    },
    {
      error: {
        status: 500,
        code: "XX000",
        message: "sensitive database trace",
      },
      status: 503,
      code: "unavailable",
    },
  ];
  for (const item of errors) {
    const harness = makeHarness({
      receive: async () => {
        throw item.error;
      },
    });
    const response = await harness.handler(
      postRequest(encodePayload(validPayload())),
    );
    const responseText = await response.clone().text();
    await expectError(response, item.status, item.code);
    if (item.retry) {
      assert(
        /^\d+$/.test(response.headers.get("retry-after") ?? ""),
        "rate limit has integer Retry-After",
      );
    } else {assertEquals(
        response.headers.get("retry-after"),
        null,
        "non-rate-limit response omits Retry-After",
      );}
    assert(
      !responseText.includes("sensitive"),
      "database details are not returned",
    );
  }
});

Deno.test("missing_required_configuration_fails_before_provider_or_database", async () => {
  const harness = makeHarness({ configured: false });
  await expectError(
    await harness.handler(postRequest(encodePayload(validPayload()))),
    503,
    "unavailable",
  );
  assertEquals(
    harness.verifiedTokens.length,
    0,
    "missing secrets fail before provider call",
  );
  assertEquals(
    harness.received.length,
    0,
    "missing secrets fail before database call",
  );
});

Deno.test("responses_and_logs_never_contain_body_or_secrets", async () => {
  const secret = "server-secret-never-returned";
  const body = validPayload();
  body.turnstile_token = "token-never-returned";
  const harness = makeHarness();
  const original = {
    log: console.log,
    warn: console.warn,
    error: console.error,
  };
  const logs: string[] = [];
  console.log = (...values: unknown[]) => {
    logs.push(values.map(String).join(" "));
  };
  console.warn = (...values: unknown[]) => {
    logs.push(values.map(String).join(" "));
  };
  console.error = (...values: unknown[]) => {
    logs.push(values.map(String).join(" "));
  };
  try {
    const response = await harness.handler(postRequest(encodePayload(body)));
    const responseText = await response.text();
    for (
      const sensitive of [
        "Ana Silva",
        "token-never-returned",
        secret,
        "203.0.113.7",
      ]
    ) {
      assert(!responseText.includes(sensitive), `response omits ${sensitive}`);
      assert(!logs.join("\n").includes(sensitive), `logs omit ${sensitive}`);
    }
    assertEquals(logs.length, 0, "handler emits no request or secret logs");
  } finally {
    console.log = original.log;
    console.warn = original.warn;
    console.error = original.error;
  }
});

Deno.test("supabase_address_resolver_rejects_unverified_forwarding_headers", () => {
  const request = new Request(
    "https://supabase.example/functions/v1/public-intake",
    {
      method: "POST",
      headers: {
        "x-forwarded-for": "198.51.100.44, 203.0.113.9",
        "cf-connecting-ip": "198.51.100.45",
      },
      body: "{}",
    },
  );
  assertEquals(
    resolveSupabaseEdgeClientAddress(request),
    null,
    "unverified headers do not become a trusted address",
  );
});

Deno.test("network_hash_uses_hmac_sha256", async () => {
  const actual = await hmacSha256(
    "key",
    "The quick brown fox jumps over the lazy dog",
  );
  assertEquals(
    actual,
    "f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8",
    "HMAC-SHA256 matches the standard vector",
  );
});

Deno.test("turnstile_verifier_uses_siteverify_and_keeps_secret_server_side", async () => {
  let requestUrl = "";
  let requestInit: RequestInit | undefined;
  const verifier = createTurnstileVerifier(async (input, init) => {
    requestUrl = String(input);
    requestInit = init;
    return new Response(
      JSON.stringify({
        success: true,
        hostname: "church.example",
        action: "public_intake",
      }),
      {
        status: 200,
        headers: { "content-type": "application/json" },
      },
    );
  }, "turnstile-server-secret");
  const outcome = await verifier(
    "one-time-token",
    new AbortController().signal,
  );
  assertEquals(
    requestUrl,
    "https://challenges.cloudflare.com/turnstile/v0/siteverify",
    "calls the fixed Siteverify endpoint",
  );
  assertEquals(requestInit?.method, "POST", "uses POST");
  const form = new URLSearchParams(String(requestInit?.body));
  assertEquals(
    form.get("secret"),
    "turnstile-server-secret",
    "server secret is sent only to Siteverify",
  );
  assertEquals(
    form.get("response"),
    "one-time-token",
    "verifier sends the supplied one-time token",
  );
  assertEquals(
    form.get("remoteip"),
    null,
    "unverified client address is not sent to provider",
  );
  assertEquals(
    outcome.success,
    true,
    "returns provider outcome for strict handler validation",
  );
});

Deno.test("database_caller_uses_only_fixed_service_role_rpc", async () => {
  const calls: Array<{ url: string; init: RequestInit }> = [];
  const caller = createFixedRpcCaller({
    supabaseUrl: "https://project.supabase.co/",
    serviceCredential: "server-role-secret",
    fetcher: async (input, init) => {
      calls.push({ url: String(input), init: init ?? {} });
      return new Response(JSON.stringify({ status: "received" }), {
        status: 200,
        headers: { "content-type": "application/json" },
      });
    },
  });
  const request = {
    submission_id: SUBMISSION_ID,
    network_hash: "c".repeat(64),
    draft: validPayload().draft as Record<string, unknown>,
  };
  const result = await caller(request, new AbortController().signal);
  assertEquals(result, { status: "received" }, "returns only fixed RPC result");
  assertEquals(calls.length, 1, "makes one RPC request");
  assertEquals(
    calls[0].url,
    "https://project.supabase.co/rest/v1/rpc/ieadpe_receive_public_intake",
    "targets only the receive RPC",
  );
  assertEquals(calls[0].init.method, "POST", "uses POST");
  const headers = new Headers(calls[0].init.headers);
  assertEquals(
    headers.get("apikey"),
    "server-role-secret",
    "uses server role API key",
  );
  assertEquals(
    headers.get("authorization"),
    "Bearer server-role-secret",
    "uses server role bearer credential",
  );
  const sent = JSON.parse(String(calls[0].init.body)) as Record<
    string,
    unknown
  >;
  assertEquals(Object.keys(sent).sort(), [
    "draft",
    "network_hash",
    "submission_id",
  ], "forwards only fixed RPC fields");
  assertEquals(
    sent.submission_id,
    SUBMISSION_ID,
    "keeps the submission idempotency key",
  );
  assert(
    !String(calls[0].init.body).includes("turnstile_token"),
    "never forwards bot token to database",
  );
});

Deno.test("trusted_network_address_is_canonicalized_before_hmac", async () => {
  const harness = makeHarness({
    address: "2001:0db8:0000:0000:0000:0000:0000:0001",
  });
  const response = await harness.handler(
    postRequest(encodePayload(validPayload())),
  );
  assertEquals(response.status, 202, "trusted IPv6 submission is accepted");
  assertEquals(
    harness.hashedAddresses,
    ["2001:db8::1"],
    "equivalent IPv6 forms use one canonical HMAC input",
  );
});

Deno.test("non_ip_address_never_reaches_hmac_or_database", async () => {
  const harness = makeHarness({ address: "127.1" });
  await expectError(
    await harness.handler(postRequest(encodePayload(validPayload()))),
    503,
    "unavailable",
  );
  assertEquals(
    harness.hashedAddresses.length,
    0,
    "non-canonical address is not hashed",
  );
  assertEquals(
    harness.received.length,
    0,
    "non-canonical address never reaches database",
  );
});

Deno.test("public_http_origin_is_rejected", async () => {
  const harness = makeHarness({ origins: ["http://church.example"] });
  await expectError(
    await harness.handler(
      postRequest(encodePayload(validPayload()), {
        origin: "http://church.example",
      }),
    ),
    400,
    "validation",
  );
  assertEquals(
    harness.verifiedTokens.length,
    0,
    "insecure public origin is rejected before provider calls",
  );
  assertEquals(
    harness.received.length,
    0,
    "insecure public origin is rejected before database calls",
  );
});
