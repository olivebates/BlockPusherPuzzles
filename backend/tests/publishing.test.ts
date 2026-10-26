import { afterEach, describe, expect, it, vi } from "vitest";
import { convexTest } from "convex-test";
import schema from "../convex/schema";
import { internal } from "../convex/_generated/api";
import { COOLDOWN_MS, MAX_LEVEL_LENGTH } from "../convex/validation";
import { pack, levelMeta } from "../convex/codec";
import type { Id } from "../convex/_generated/dataModel";

const modules = import.meta.glob("../convex/**/*.ts");
// Uncompressed 3x1 CPE1: player, cyan block, cyan key.
const raw = "CPE1:" + btoa(String.fromCharCode(3, 0, 1, 0, 0, 81, 85, 255, 2, 3, 16));
const metadata = {n:"First puzzle",a:"Fox",d:"A small puzzle",l:raw};
const levelString = pack("CPE2:",metadata);
const input = { levelString,
  publisherId: "a".repeat(64), requestId: "b".repeat(32) };

function post(t: ReturnType<typeof convexTest>, value: unknown = input) {
  return t.fetch("/levels", {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify(value),
  });
}
afterEach(() => vi.useRealTimers());

describe("publishing HTTP API", () => {
  it("accepts browser preflight and returns CORS on errors", async () => {
    const t = convexTest(schema, modules);
    const options = await t.fetch("/levels", { method: "OPTIONS" });
    expect(options.status).toBe(204);
    expect(options.headers.get("Access-Control-Allow-Origin")).toBe("*");
    const invalid = await post(t, {});
    expect(invalid.status).toBe(400);
    expect(invalid.headers.get("Access-Control-Allow-Origin")).toBe("*");
    expect(await t.run(ctx => ctx.db.query("levels").collect())).toHaveLength(0);
  });
  it("stores the exact level string and trimmed metadata", async () => {
    const t = convexTest(schema, modules);
    const response = await post(t);
    expect(response.status).toBe(201);
    const result = await response.json();
    expect(result).toMatchObject({ ok: true, retryAfterSeconds: 300 });
    const saved = await t.run(ctx => ctx.db.get(result.levelId as Id<"levels">));
    expect(saved).toMatchObject({ levelString, likes:1 });
    expect(saved).not.toHaveProperty("puzzleName");
    expect(saved).not.toHaveProperty("author");
    expect(saved).not.toHaveProperty("description");
    expect(levelMeta(saved!.levelString)).toEqual(metadata);
  });
  it("blocks all new levels for this publisher until five minutes have elapsed", async () => {
    vi.useFakeTimers();
    const t = convexTest(schema, modules);
    await post(t);
    const next = { ...input, requestId: "c".repeat(32), puzzleName: "Next puzzle" };
    const blocked = await post(t, next);
    expect(blocked.status).toBe(429);
    expect(blocked.headers.get("Retry-After")).toBe("300");
    vi.advanceTimersByTime(COOLDOWN_MS - 1);
    expect((await post(t, next)).status).toBe(429);
    vi.advanceTimersByTime(1);
    expect((await post(t, next)).status).toBe(201);
    expect(await t.run(ctx => ctx.db.query("levels").collect())).toHaveLength(2);
  });
  it("lets another installation publish during someone else's cooldown", async () => {
    const t = convexTest(schema, modules);
    await post(t);
    expect((await post(t, { ...input, publisherId: "d".repeat(64) })).status).toBe(201);
  });
  it("makes concurrent submissions respect the same cooldown", async () => {
    const t = convexTest(schema, modules);
    const results = await Promise.all([
      post(t), post(t, { ...input, requestId: "c".repeat(32) }),
    ]);
    expect(results.map(r => r.status).sort()).toEqual([201, 429]);
    expect(await t.run(ctx => ctx.db.query("levels").collect())).toHaveLength(1);
  });
  it("retries an uncertain upload without duplicates or extending the cooldown", async () => {
    vi.useFakeTimers();
    const t = convexTest(schema, modules);
    const first = await (await post(t)).json();
    vi.advanceTimersByTime(30_000);
    const retry = await (await post(t)).json();
    expect(retry.levelId).toBe(first.levelId);
    expect(retry.retryAfterSeconds).toBe(270);
    expect(await t.run(ctx => ctx.db.query("levels").collect())).toHaveLength(1);
    expect((await post(t, { ...input, levelString:pack("CPE2:",{...metadata,a:"Changed"}) })).status).toBe(400);
  });
  it.each([
    ...[{n:" "},{n:"x".repeat(81)},{a:""},{a:"x".repeat(41)},{a:"a\nb"},{d:"x".repeat(101)}].map(meta=>({levelString:pack("CPE2:",{...metadata,...meta})})),
    { levelString: "CPE1:!!!!" }, { levelString: "CPE1:AA==" },
    { levelString: "CPE1:" + "A".repeat(MAX_LEVEL_LENGTH) },
    { publisherId: "bad" }, { requestId: "bad" },
  ])("rejects invalid submission %j without consuming the cooldown", async (change) => {
    const t = convexTest(schema, modules);
    expect((await post(t, { ...input, ...change })).status).toBe(400);
    expect(await t.run(ctx => ctx.db.query("publishers").collect())).toHaveLength(0);
    expect((await post(t)).status).toBe(201);
  });
  it("rejects malformed JSON, wrong content type, and oversized bodies", async () => {
    const t = convexTest(schema, modules);
    expect((await t.fetch("/levels", { method: "POST", body: "{}" })).status).toBe(415);
    expect((await t.fetch("/levels", { method: "POST",
      headers: { "Content-Type": "application/json" }, body: "{" })).status).toBe(400);
    expect((await t.fetch("/levels", { method: "POST",
      headers: { "Content-Type": "application/json" },
      body: "x".repeat(MAX_LEVEL_LENGTH + 4097) })).status).toBe(413);
  });
  it("validates again inside the internal mutation", async () => {
    const t = convexTest(schema, modules);
    const result = await t.mutation(internal.levels.publish, { ...input, levelString:"invalid" });
    expect(result.ok).toBe(false);
    expect(await t.run(ctx => ctx.db.query("levels").collect())).toHaveLength(0);
  });
});
