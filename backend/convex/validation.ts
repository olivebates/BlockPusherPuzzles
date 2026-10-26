import { levelMeta, MAX_CODE } from "./codec";
export const COOLDOWN_MS = 300_000;
export const MAX_LEVEL_LENGTH = MAX_CODE;
export function validIdentity(value: unknown): value is string { return typeof value === "string" && /^[a-f0-9]{64}$/.test(value); }
export function validRequest(value: unknown): value is string { return typeof value === "string" && /^[a-f0-9]{32}$/.test(value); }
export function validatePublish(value: unknown) {
  if (!value || typeof value !== "object") return null;
  const input = value as Record<string, unknown>;
  if (!validIdentity(input.publisherId) || !validRequest(input.requestId) || !levelMeta(input.levelString)) return null;
  return { publisherId: input.publisherId, requestId: input.requestId, levelString: input.levelString as string };
}
// Reddit's published Hot formula, using the unclamped net vote count.
// https://github.com/reddit-archive/reddit/blob/master/r2/r2/lib/db/_sorts.pyx
export function hotScore(score: number, publishedAt: number) {
  return Math.round((Math.sign(score) * Math.log10(Math.max(Math.abs(score), 1)) +
    (publishedAt / 1000 - 1134028003) / 45000) * 1e7) / 1e7;
}
