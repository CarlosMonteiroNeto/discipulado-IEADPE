/**
 * Idempotent command wrapper (S11).
 *
 * Every mutation carries a client-generated `requestId`. The wrapper validates
 * the UUID and payload digest, authorizes the caller even when a receipt
 * already exists, then transactionally persists a seven-day receipt together
 * with the result. An identical replay returns the original result; reusing a
 * requestId with another payload is a `conflict`.
 */
import { createHash } from "node:crypto";
import { Clock } from "./clock";
import { AuthorizedContext, authorizeContext } from "./context";
import { Datastore, JsonMap, Transaction, paths } from "./datastore";
import { conflictError, validationError } from "./errors";

export const RECEIPT_TTL_MS = 7 * 24 * 60 * 60 * 1000;

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function isUuid(value: unknown): value is string {
  return typeof value === "string" && UUID_PATTERN.test(value);
}

/** Deterministic JSON with object keys sorted at every depth. */
export function canonicalize(value: unknown): string {
  if (value === null || typeof value !== "object") {
    return JSON.stringify(value) ?? "null";
  }
  if (Array.isArray(value)) {
    return `[${value.map((entry) => canonicalize(entry)).join(",")}]`;
  }
  const record = value as Record<string, unknown>;
  const keys = Object.keys(record).sort();
  const entries = keys.map(
    (key) => `${JSON.stringify(key)}:${canonicalize(record[key])}`,
  );
  return `{${entries.join(",")}}`;
}

/** Canonical payload digest binding an operation to its exact payload. */
export function payloadDigest(operation: string, payload: JsonMap): string {
  return createHash("sha256")
    .update(`${operation}\u0000${canonicalize(payload)}`)
    .digest("hex");
}

export interface CommandInput {
  uid: string;
  requestId: string;
  operation: string;
  payload: JsonMap;
  requestedCongregationId?: string | null;
}

export type CommandExecutor<TResult> = (
  tx: Transaction,
  context: AuthorizedContext,
) => Promise<TResult>;

export async function runCommand<TResult>(
  datastore: Datastore,
  clock: Clock,
  input: CommandInput,
  execute: CommandExecutor<TResult>,
): Promise<TResult> {
  if (!isUuid(input.requestId)) {
    throw validationError("requestId must be a UUID.", {
      requestId: "requestId must be a UUID.",
    });
  }
  if (typeof input.operation !== "string" || input.operation.length === 0) {
    throw validationError("operation is required.", {
      operation: "operation is required.",
    });
  }

  const digest = payloadDigest(input.operation, input.payload);
  const receiptPath = paths.receipt(input.uid, input.requestId);

  return datastore.runTransaction(async (tx) => {
    // Authorization is evaluated inside the transaction, before any receipt is
    // returned, so a cached result is never granted after revocation.
    const context = await authorizeContext({
      datastore: tx as unknown as Datastore,
      uid: input.uid,
      requestedCongregationId: input.requestedCongregationId,
      payload: input.payload,
    });

    const existing = await tx.read(receiptPath);
    if (existing !== null) {
      if (existing.operation !== input.operation || existing.digest !== digest) {
        throw conflictError("requestId was reused with a different payload.");
      }
      return existing.result as TResult;
    }

    const result = await execute(tx, context);
    const nowMs = clock.now().getTime();
    await tx.write(receiptPath, {
      uid: input.uid,
      requestId: input.requestId,
      operation: input.operation,
      digest,
      result: result as JsonMap,
      createdAt: nowMs,
      expiresAt: nowMs + RECEIPT_TTL_MS,
    });
    return result;
  });
}
