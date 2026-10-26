import { Gunzip, gzipSync, strFromU8, strToU8 } from "fflate";
export const MAX_CODE = 900_000;
export const MAX_REPLAY_COMMENT = 40;
const MAX_RAW = 32 * 1024 * 1024;
export function unpack(prefix: string, code: unknown): Record<string, any> | null {
  try {
    if (typeof code !== "string" || code.length > MAX_CODE || !code.startsWith(prefix)) return null;
    const base = code.slice(prefix.length);
    if (base.length % 4 || !/^[A-Za-z0-9+/]*={0,2}$/.test(base)) return null;
    const binary = atob(base);
    if (btoa(binary) !== base || binary.length < 6) return null;
    const bytes = Uint8Array.from(binary, c => c.charCodeAt(0));
    const size = new DataView(bytes.buffer).getUint32(1, true);
    if (size < 2 || size > MAX_RAW || ![3, 255].includes(bytes[0])) return null;
    let raw: Uint8Array;
    if (bytes[0] === 255) raw = bytes.subarray(5);
    else {
      const chunks: Uint8Array[] = [];
      let total = 0;
      const unzip = new Gunzip(chunk => {
        total += chunk.length;
        if (total > size) throw new Error("Oversized payload");
        chunks.push(chunk);
      });
      for (let i = 5; i < bytes.length; i += 1024) unzip.push(bytes.subarray(i, i + 1024), i + 1024 >= bytes.length);
      raw = new Uint8Array(total);
      let offset = 0;
      for (const chunk of chunks) { raw.set(chunk, offset); offset += chunk.length; }
    }
    if (raw.length !== size) return null;
    const value = JSON.parse(strFromU8(raw));
    return value && typeof value === "object" && !Array.isArray(value) ? value : null;
  } catch { return null; }
}
export function pack(prefix: string, value: unknown): string {
  const raw = strToU8(JSON.stringify(value));
  const zipped = gzipSync(raw);
  const data = zipped.length < raw.length ? zipped : raw;
  const bytes = new Uint8Array(data.length + 5);
  bytes[0] = data === zipped ? 3 : 255;
  new DataView(bytes.buffer).setUint32(1, raw.length, true);
  bytes.set(data, 5);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return prefix + btoa(binary);
}
export function text(value: unknown, max: number, required = false): value is string {
  return typeof value === "string" && [...value].length <= max &&
    (!required || value.trim().length > 0) && !/[\u0000-\u001f\u007f]/.test(value);
}
export function validLevelEnvelope(level: string): boolean {
  if (level.length > 524288 || !level.startsWith("CPE1:")) return false;
  const base = level.slice(5);
  if (base.length % 4 || !/^[A-Za-z0-9+/]*={0,2}$/.test(base)) return false;
  const data = atob(base);
  if (data.length < 9 || btoa(data) !== base) return false;
  const w = data.charCodeAt(0) | data.charCodeAt(1) << 8;
  const h = data.charCodeAt(2) | data.charCodeAt(3) << 8;
  return w >= 1 && w <= 512 && h >= 1 && h <= 512 && [0,1,2,3,255].includes(data.charCodeAt(7));
}
export function levelMeta(code: unknown) {
  const value = unpack("CPE2:", code);
  if (!value || !text(value.n, 80, true) || !text(value.a, 40, true) || !text(value.d, 100) ||
      typeof value.l !== "string" || !validLevelEnvelope(value.l)) return null;
  return value as { n: string; a: string; d: string; l: string };
}
export function replayMeta(code: unknown) {
  const value = unpack("CPR1:", code);
  if (!value || value.v !== 1 || !text(value.n, 80, true) || !text(value.a, 40, true) ||
      !text(value.c, 100) || !levelMeta(value.l) || value.fps !== 60 ||
      !Array.isArray(value.kinds) || value.kinds.length > 10000 ||
      !value.kinds.every((k: unknown) => [1,2,3,10,11].includes(k as number)) ||
      !Array.isArray(value.frames) || value.frames.length < 2 || value.frames.length > 108000) return null;
  for (const [i, frame] of value.frames.entries()) {
    if (!Array.isArray(frame) || frame.length !== 2 || !Number.isInteger(frame[0]) || frame[0] < 0 || frame[0] > 65535 ||
        !Array.isArray(frame[1]) || frame[1].length > value.kinds.length) return null;
    const seen = new Set<number>();
    for (const state of frame[1]) {
      if (!Array.isArray(state) || !Number.isInteger(state[0]) || state[0] < 0 || state[0] >= value.kinds.length || seen.has(state[0]) ||
          state.length !== ({1: 12, 2: 11, 3: 6, 10: 7, 11: 7} as Record<number, number>)[value.kinds[state[0]]] ||
          !state.every((n: unknown) => typeof n === "number" && Number.isFinite(n) && Math.abs(n) <= 1e9)) return null;
      seen.add(state[0]);
    }
    if (i === 0 && seen.size !== value.kinds.length) return null;
  }
  return value;
}
