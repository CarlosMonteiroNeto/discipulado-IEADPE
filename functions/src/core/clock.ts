/**
 * Injected, deterministic clock and America/Recife calendar semantics (S05).
 */
export interface Clock {
  now(): Date;
}

/** A clock frozen at an instant, for deterministic tests. */
export function fixedClock(instant: Date): Clock {
  const frozen = new Date(instant.getTime());
  return {
    now: () => new Date(frozen.getTime()),
  };
}

export const systemClock: Clock = {
  now: () => new Date(),
};

/** America/Recife has been UTC-3 without DST since 2019. */
export const RECIFE_UTC_OFFSET_MS = -3 * 60 * 60 * 1000;

/** The calendar date in America/Recife for a UTC instant, as `yyyy-MM-dd`. */
export function recifeToday(nowUtc: Date): string {
  const local = new Date(nowUtc.getTime() + RECIFE_UTC_OFFSET_MS);
  const year = local.getUTCFullYear().toString().padStart(4, "0");
  const month = (local.getUTCMonth() + 1).toString().padStart(2, "0");
  const day = local.getUTCDate().toString().padStart(2, "0");
  return `${year}-${month}-${day}`;
}
