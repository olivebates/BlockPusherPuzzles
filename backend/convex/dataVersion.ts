import manifest from "../../version.json";

export const DATA_VERSION = manifest.data_version;
export const LEGACY_DATA_VERSION = manifest.legacy_data_version;
export const RELEASE_VERSION = manifest.release;

export function readableVersion(value: unknown): value is number {
  return typeof value === "number" && Number.isInteger(value) &&
    value >= manifest.oldest_readable_data_version && value <= DATA_VERSION;
}

export function acceptsVersion(value: Record<string, unknown>, allowMissing = false): boolean {
  return readableVersion(value.v === undefined && allowMissing ? LEGACY_DATA_VERSION : value.v);
}
