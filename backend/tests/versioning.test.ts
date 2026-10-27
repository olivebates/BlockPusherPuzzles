import { describe, expect, it } from "vitest";
import { convexTest } from "convex-test";
import schema from "../convex/schema";
import manifest from "../../version.json";
import fixtures from "./fixtures/versioned-v2.json";
import custom from "./fixtures/custom-v3.json";
import { acceptsVersion, DATA_VERSION, readableVersion } from "../convex/dataVersion";
import { levelContent, levelMeta, pack, replayMeta, unpack, validLevelEnvelope } from "../convex/codec";

const modules = import.meta.glob("../convex/**/*.ts");
const owner = "a".repeat(64), visitor = "b".repeat(64);

describe("shared data versions", () => {
  it("validates current uploads without publishing or starting a cooldown", async () => {
    const t = convexTest(schema, modules);
    const response = await t.fetch("/validate-level", {
      method:"POST", headers:{"Content-Type":"application/json"},
      body:JSON.stringify({levelString:custom.level, publisherId:owner, requestId:"e".repeat(32)}),
    });
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({ok:true, dataVersion:DATA_VERSION});
    await t.run(async ctx => {
      expect(await ctx.db.query("levels").collect()).toEqual([]);
      expect(await ctx.db.query("publishers").collect()).toEqual([]);
    });
    const bad = await t.fetch("/validate-level", {
      method:"POST", headers:{"Content-Type":"application/json"}, body:JSON.stringify({}),
    });
    expect(bad.status).toBe(400);
  });
  it("reads version-3 custom objects and Q-input replays alongside frozen older fixtures", () => {
    const meta = levelMeta(custom.level)!;
    expect(meta).not.toBeNull();
    expect(unpack("CPE2:", custom.level)!.v).toBe(3);
    expect(validLevelEnvelope(meta.l)).toBe(true);
    expect(replayMeta(custom.replay)).not.toBeNull();
    expect(replayMeta(custom.replay)!.frames[1][0]).toBe(1 << 13);
    expect(levelMeta(fixtures.level)).not.toBeNull();
    expect(replayMeta(fixtures.replay)).not.toBeNull();
  });
  it("reads historical Godot level/replay fixtures alongside the new version", () => {
    expect(DATA_VERSION).toBe(manifest.data_version);
    for (const code of [fixtures.level, fixtures.legacy_level]) expect(levelMeta(code)).not.toBeNull();
    for (const code of [fixtures.replay, fixtures.legacy_replay]) expect(replayMeta(code)).not.toBeNull();
    expect(unpack("CPE2:", fixtures.level)!.v).toBe(2);
    expect(replayMeta(fixtures.replay)!.v).toBe(2);
    expect(replayMeta(fixtures.legacy_replay)!.v).toBe(1);
  });

  it.each([0, -1, 1.5, "2", true, null, DATA_VERSION + 1])("rejects invalid/future version %s", v => {
    expect(readableVersion(v)).toBe(false);
    expect(levelMeta(pack("CPE2:", {...unpack("CPE2:", fixtures.level), v}))).toBeNull();
    expect(replayMeta(pack("CPR1:", {...unpack("CPR1:", fixtures.replay), v}))).toBeNull();
  });

  it("only assumes legacy v for old community metadata, not saves or replays", () => {
    expect(acceptsVersion({}, true)).toBe(true);
    expect(acceptsVersion({})).toBe(false);
    const replay = unpack("CPR1:", fixtures.replay)!;
    delete replay.v;
    expect(replayMeta(pack("CPR1:", replay))).toBeNull();
  });

  it("checks the version inside packed levels as well as their outer metadata", () => {
    const meta = levelMeta(fixtures.level)!;
    const bytes = Uint8Array.from(atob(meta.l.slice(5)), c => c.charCodeAt(0));
    new DataView(bytes.buffer).setUint16(0, DATA_VERSION + 1, true);
    const future = "CPE3:" + btoa(String.fromCharCode(...bytes));
    expect(validLevelEnvelope(future)).toBe(false);
    expect(levelMeta(pack("CPE2:", {...meta, l:future}))).toBeNull();
    expect(replayMeta(pack("CPR1:", {...unpack("CPR1:", fixtures.replay), l:pack("CPE2:", {...meta, l:future})}))).toBeNull();
  });

  it("preserves likes/replays and accepts an older in-flight replay after a version-only upgrade", async () => {
    const t = convexTest(schema, modules);
    const post = (path: string, data: unknown, method = "POST") => t.fetch(path, {
      method, headers: {"Content-Type":"application/json"}, body:JSON.stringify(data),
    });
    const response = await post("/levels", {levelString:fixtures.legacy_level, publisherId:owner, requestId:"a".repeat(32)});
    expect(response.status).toBe(201);
    const {levelId} = await response.json();
    expect((await post("/complete", {levelId, publisherId:visitor, runId:"b".repeat(32), revision:1, vote:1, replayString:fixtures.legacy_replay})).status).toBe(200);
    await t.run(async ctx => {
      const publisher = (await ctx.db.query("publishers").first())!;
      await ctx.db.patch(publisher._id, {nextPublishAt:0});
    });
    const oldMeta = levelMeta(fixtures.legacy_level)!;
    const upgraded = pack("CPE2:", {...oldMeta, v:DATA_VERSION, l:levelMeta(fixtures.level)!.l});
    expect(levelContent(oldMeta.l)).toBe(levelContent(levelMeta(upgraded)!.l));
    expect((await post("/level", {levelId, publisherId:owner, requestId:"c".repeat(32), revision:1, levelString:upgraded}, "PATCH")).status).toBe(200);
    const listed = await (await t.fetch("/levels?sort=hot")).json();
    expect(listed.levels[0]).toMatchObject({likes:2, revision:1});
    expect((await (await t.fetch(`/replays?levelId=${levelId}`)).json()).replays).toHaveLength(1);
    expect((await post("/complete", {levelId, publisherId:visitor, runId:"d".repeat(32), revision:1, replayString:fixtures.legacy_replay})).status).toBe(200);
  });
});
