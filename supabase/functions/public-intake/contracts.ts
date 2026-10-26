export const MAX_REQUEST_BYTES = 16 * 1024;
export const TURNSTILE_ACTION = "public_intake";
export const INTAKE_RPC_NAME = "ieadpe_receive_public_intake";
export const TURNSTILE_SITEVERIFY_URL =
  "https://challenges.cloudflare.com/turnstile/v0/siteverify";
export const DEFAULT_PROVIDER_TIMEOUT_MS = 5_000;
export const DEFAULT_DATABASE_TIMEOUT_MS = 5_000;
export const MAX_DEPENDENCY_TIMEOUT_MS = 15_000;
export const RATE_LIMIT_RETRY_AFTER_SECONDS = 3_600;

export interface OfficialDraft {
  [key: string]: unknown;
}

export interface IntakeSubmission {
  submission_id: string;
  turnstile_token: string;
  draft: OfficialDraft;
}

export interface ReceiveIntakeRequest {
  submission_id: string;
  network_hash: string | null;
  draft: OfficialDraft;
}

export interface SiteverifyOutcome {
  success?: unknown;
  hostname?: unknown;
  action?: unknown;
  [key: string]: unknown;
}

export type PublicIntakeError =
  | "validation"
  | "conflict"
  | "rate_limited"
  | "unavailable"
  | "bot_check_failed";
