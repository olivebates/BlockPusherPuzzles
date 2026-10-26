import { afterEach, describe, expect, it, vi } from "vitest";
import { convexTest } from "convex-test";
import schema from "../convex/schema";
import { internal } from "../convex/_generated/api";
import { hotScore } from "../convex/validation";
import { levelMeta, pack, replayMeta } from "../convex/codec";
import type { Id } from "../convex/_generated/dataModel";
import godot from "./fixtures/godot.json";
const modules = import.meta.glob("../convex/**/*.ts");
const owner = "a".repeat(64), visitor = "b".repeat(64), runId = "c".repeat(32);
const raw = "CPE1:" + btoa(String.fromCharCode(3,0,1,0,0,81,85,255,2,3,16));
const code = (n="Test puzzle",a="Fox",d="Description") => pack("CPE2:",{n,a,d,l:raw});
const changedCode = () => pack("CPE2:",{n:"Edited",a:"Fox",d:"Description",
  l:"CPE1:" + btoa(String.fromCharCode(3,0,1,0,1,81,85,255,2,3,16))});
const input = {levelString:code(),publisherId:owner,requestId:"d".repeat(32)};
const makeTest = () => convexTest(schema, modules);
type Test = ReturnType<typeof makeTest>;
async function request(t: Test, path: string, method: string, data: unknown) {
  return t.fetch(path,{method,headers:{"Content-Type":"application/json"},body:JSON.stringify(data)});
}
async function publish(t: Test) {
  const response = await request(t,"/levels","POST",input);
  return (await response.json()).levelId as Id<"levels">;
}
async function list(t: Test, sort="hot", search="", cursor="") {
  return (await t.fetch(`/levels?sort=${sort}&search=${encodeURIComponent(search)}&cursor=${encodeURIComponent(cursor)}`)).json();
}
function replay(levelString: string, extra={}) {
  return pack("CPR1:",{v:1,n:levelMeta(levelString)!.n,a:"Anonymous",c:"Nice puzzle!",l:levelString,fps:60,
    kinds:[1,2,3], frames:[[0,[[0,800,800,0,1,0,100,100,0,0,0,0],[1,2400,800,0,0,0,0,0,0,0,0],[2,4000,800,0,0,0]]],[2,[]]],...extra});
}
afterEach(()=>vi.useRealTimers());

describe("level catalogue",()=>{
  it("reads real Godot-compressed levels and input replay tracks",()=>{
    expect(levelMeta(godot.level)).toMatchObject({n:"Puzzle 0",a:"Fox",d:"A description with æ and 😀"});
    const recorded=replayMeta(godot.replay)!;
    expect(recorded).toMatchObject({a:"Anonymous",c:"Nice!",fps:60});
    expect(recorded.frames.some((frame:any[])=>frame[0]&2)).toBe(true);
  });
  it("paginates 50 rows at a time without duplicate or missing ties",async()=>{
    const t=convexTest(schema,modules);
    await t.run(async ctx=>{
      for(let i=0;i<123;i++) await ctx.db.insert("levels",{...input,levelString:code(`Puzzle ${i}`),requestId:i.toString(16).padStart(32,"0"),publishedAt:Date.now(),revision:1,likes:1,hot:1,completions:0,deleted:false});
    });
    const first=await list(t), second=await list(t,"hot","",first.cursor), third=await list(t,"hot","",second.cursor);
    expect(first.levels).toHaveLength(50); expect(second.levels).toHaveLength(50); expect(third.levels).toHaveLength(23);
    expect(third.cursor).toBe("");
    expect(new Set([...first.levels,...second.levels,...third.levels].map(x=>x.id)).size).toBe(123);
    expect(first.levels[0]).not.toHaveProperty("publisherId");
  });
  it("searches substrings in names and authors, ignoring case",async()=>{
    const t=convexTest(schema,modules); await publish(t);
    expect((await list(t,"hot","EST PUZ")).levels).toHaveLength(1);
    expect((await list(t,"hot","OX")).levels).toHaveLength(1);
    expect((await list(t,"hot","Description")).levels).toHaveLength(0);
  });
  it("uses the Reddit hot formula with negative scores intact",()=>{
    const epoch=1134028003*1000;
    expect(hotScore(100,epoch)).toBe(2);
    expect(hotScore(-100,epoch)).toBe(-2);
    expect(hotScore(1,epoch+45000000)).toBe(1);
  });
  it("filters each Top period by upload time and orders by net likes",async()=>{
    vi.useFakeTimers(); vi.setSystemTime(new Date("2026-10-26T12:00:00Z"));
    const t=convexTest(schema,modules);
    await t.run(async ctx=>{
      for(const [days,likes] of [[0,2],[2,3],[8,4],[40,5],[400,100]]) {
        const publishedAt=Date.now()-days*86400000;
        await ctx.db.insert("levels",{...input,levelString:code(`Day ${days}`),requestId:days.toString(16).padStart(32,"0"),publishedAt,likes,hot:hotScore(likes,publishedAt),revision:1,completions:0,deleted:false});
      }
    });
    for(const [sort,names] of Object.entries({today:["Day 0"],week:["Day 2","Day 0"],month:["Day 8","Day 2","Day 0"],year:["Day 40","Day 8","Day 2","Day 0"]}))
      expect((await list(t,sort)).levels.map((r:any)=>r.name)).toEqual(names);
  });
});
describe("completions, votes and replays",()=>{
  it("counts starts before completion, makes retries idempotent, and counts separate runs",async()=>{
    const t=makeTest(),levelId=await publish(t);
    const attempt={levelId,publisherId:visitor,runId,revision:1};
    expect((await list(t)).levels[0].plays).toBe(0);
    for (const response of await Promise.all([request(t,"/attempt","POST",attempt),request(t,"/attempt","POST",attempt)]))
      expect(response.status).toBe(200);
    expect((await list(t)).levels[0].plays).toBe(1);
    expect((await list(t,"uncompleted")).levels).toHaveLength(1);
    expect((await request(t,"/attempt","POST",{...attempt,runId:"e".repeat(32)})).status).toBe(200);
    expect((await (await t.fetch(`/level?id=${levelId}`)).json()).plays).toBe(2);
    expect((await request(t,"/attempt","POST",{...attempt,runId:"f".repeat(32),revision:0})).status).toBe(400);
    expect((await request(t,"/attempt","POST",{...attempt,publisherId:"invalid"})).status).toBe(400);
    expect((await list(t)).levels[0].plays).toBe(2);
    expect((await t.fetch("/attempt",{method:"OPTIONS"})).status).toBe(204);
  });
  it("starts older puzzles at zero plays and preserves lifetime play counts across edits",async()=>{
    vi.useFakeTimers();
    const t=makeTest(),levelId=await publish(t);
    await t.run(ctx=>ctx.db.patch(levelId,{plays:undefined}));
    expect((await list(t)).levels[0].plays).toBe(0);
    await request(t,"/attempt","POST",{levelId,publisherId:visitor,runId,revision:1});
    vi.advanceTimersByTime(300000);
    await request(t,"/level","PATCH",{levelId,publisherId:owner,requestId:"e".repeat(32),revision:1,levelString:changedCode()});
    expect((await list(t)).levels[0]).toMatchObject({plays:1,revision:2});
    await request(t,"/attempt","POST",{levelId,publisherId:visitor,runId:"f".repeat(32),revision:2});
    expect((await list(t)).levels[0].plays).toBe(2);
  });
  it("limits new comments to 40 Unicode characters while keeping older replays readable",async()=>{
    const t=makeTest(),levelId=await publish(t);
    const base={levelId,publisherId:visitor,runId,revision:1};
    const tooLong=await request(t,"/complete","POST",{...base,replayString:replay(input.levelString,{c:"W".repeat(41)})});
    expect(tooLong.status).toBe(400);
    expect((await tooLong.json()).error).toContain("40 characters");
    expect((await list(t,"uncompleted")).levels).toHaveLength(1);
    expect((await request(t,"/complete","POST",{...base,replayString:replay(input.levelString,{c:"😀".repeat(40)})})).status).toBe(200);
    expect(replayMeta(replay(input.levelString,{c:"x".repeat(100)}))).not.toBeNull();
  });
  it("counts a completion even without saving a replay and removes it from No Completions",async()=>{
    const t=convexTest(schema,modules), levelId=await publish(t);
    const completion={levelId,publisherId:visitor,runId,revision:1};
    expect((await list(t,"uncompleted")).levels).toHaveLength(1);
    await request(t,"/complete","POST",completion);
    await request(t,"/complete","POST",completion);
    expect((await list(t,"uncompleted")).levels).toHaveLength(0);
    expect((await t.run(ctx=>ctx.db.get(levelId)))!.completions).toBe(1);
  });
  it("starts with the owner's like, changes votes atomically, and clamps only the display",async()=>{
    const t=convexTest(schema,modules),levelId=await publish(t);
    const completion={levelId,publisherId:owner,runId,revision:1};
    await request(t,"/complete","POST",{...completion,vote:1});
    expect((await list(t)).levels[0].likes).toBe(1);
    await request(t,"/complete","POST",{...completion,vote:-1});
    expect((await list(t)).levels[0].likes).toBe(0);
    expect((await t.run(ctx=>ctx.db.get(levelId)))!.likes).toBe(-1);
    await request(t,"/complete","POST",{...completion,vote:1});
    expect((await list(t)).levels[0].likes).toBe(1);
  });
  it("stores compressed comments/authors and returns the replay metadata and duration",async()=>{
    const t=convexTest(schema,modules),levelId=await publish(t);
    const replayString=replay(input.levelString);
    const submission={levelId,publisherId:visitor,runId,revision:1,vote:1,replayString};
    expect((await request(t,"/complete","POST",submission)).status).toBe(200);
    await request(t,"/complete","POST",submission);
    expect((await request(t,"/complete","POST",{...submission,replayString:replay(input.levelString,{c:"Changed comment"})})).status).toBe(400);
    const result=await (await t.fetch(`/replays?levelId=${levelId}`)).json();
    expect(result.replays).toHaveLength(1);
    expect(result.replays[0]).toMatchObject({name:"Test puzzle",author:"Anonymous",comment:"Nice puzzle!",time:1/60});
    const stored=await t.run(ctx=>ctx.db.query("replays").first());
    expect(stored).not.toHaveProperty("author"); expect(stored).not.toHaveProperty("comment");
    expect((await (await t.fetch(`/replay?id=${result.replays[0].id}`)).json()).replayString).toBe(replayString);
    expect(replayMeta(replay(input.levelString,{c:"x".repeat(101)}))).toBeNull();
  });
  it("rejects malformed frame tracks and stale revisions without counting a completion",async()=>{
    const t=convexTest(schema,modules),levelId=await publish(t);
    const base={levelId,publisherId:visitor,runId,revision:1};
    expect((await request(t,"/complete","POST",{...base,replayString:replay(input.levelString,{frames:[[0,[]],[1,[]]]})})).status).toBe(400);
    expect((await request(t,"/complete","POST",{...base,revision:0})).status).toBe(400);
    expect((await list(t,"uncompleted")).levels).toHaveLength(1);
  });
});
describe("ownership",()=>{
  it("keeps replays and votes created before revision tracking until the next puzzle edit",async()=>{
    const t=makeTest(),levelId=await publish(t);
    await request(t,"/complete","POST",{levelId,publisherId:visitor,runId,revision:1,vote:1,replayString:replay(input.levelString)});
    const recorded=await t.run(async ctx=>{
      await ctx.db.patch(levelId,{revision:2});
      const row=(await ctx.db.query("replays").first())!;
      await ctx.db.patch(row._id,{revision:undefined});
      for(const vote of await ctx.db.query("votes").collect()) await ctx.db.patch(vote._id,{revision:undefined});
      return row;
    });
    expect((await (await t.fetch(`/replays?levelId=${levelId}`)).json()).replays).toHaveLength(1);
    expect((await t.fetch(`/replay?id=${recorded._id}`)).status).toBe(200);
    expect((await request(t,"/complete","POST",{levelId,publisherId:visitor,runId:"f".repeat(32),revision:2,vote:1})).status).toBe(200);
    expect(await t.run(ctx=>ctx.db.get(levelId))).toMatchObject({likes:2});
  });
  it("permanently removes replays, votes, and completion records in batches",async()=>{
    vi.useFakeTimers();
    const t=convexTest(schema,modules),levelId=await publish(t);
    await request(t,"/complete","POST",{levelId,publisherId:visitor,runId,revision:1,replayString:replay(input.levelString)});
    await request(t,"/attempt","POST",{levelId,publisherId:visitor,runId,revision:1});
    await request(t,"/level","DELETE",{levelId,publisherId:owner});
    await t.finishAllScheduledFunctions(()=>vi.runAllTimers());
    expect(await t.run(ctx=>ctx.db.get(levelId))).toBeNull();
    for(const table of ["replays","votes","completions","attempts"] as const)
      expect(await t.run(ctx=>ctx.db.query(table).collect())).toHaveLength(0);
  });
  it("only lets the owner edit/delete and applies the cooldown and idempotent edits",async()=>{
    vi.useFakeTimers();
    const t=convexTest(schema,modules),levelId=await publish(t);
    await request(t,"/complete","POST",{levelId,publisherId:visitor,runId,revision:1});
    const edit={levelId,publisherId:owner,requestId:"e".repeat(32),revision:1,levelString:changedCode()};
    expect((await request(t,"/level","PATCH",{...edit,publisherId:visitor})).status).toBe(400);
    expect((await request(t,"/level","DELETE",{levelId,publisherId:visitor})).status).toBe(400);
    expect((await request(t,"/level","PATCH",edit)).status).toBe(429);
    vi.advanceTimersByTime(300000);
    expect((await request(t,"/level","PATCH",edit)).status).toBe(200);
    const row=(await list(t,"uncompleted")).levels[0];
    expect(row).toMatchObject({name:"Edited",likes:1,revision:2});
    expect((await request(t,"/level","PATCH",edit)).status).toBe(200);
    expect((await request(t,"/level","PATCH",{...edit,requestId:"f".repeat(32)})).status).toBe(400);
    expect((await request(t,"/level","DELETE",{levelId,publisherId:owner})).status).toBe(200);
    expect((await list(t)).levels).toHaveLength(0);
    expect((await t.fetch(`/level?id=${levelId}`)).status).toBe(400);
  });
  it("preserves likes, completions and replays for metadata-only and unchanged uploads",async()=>{
    vi.useFakeTimers();
    const t=makeTest(),levelId=await publish(t);
    await request(t,"/complete","POST",{levelId,publisherId:visitor,runId,revision:1,vote:1,replayString:replay(input.levelString)});
    for (const [i,levelString] of [code("New name","New author","New description"),code("New name","New author","New description")].entries()) {
      vi.advanceTimersByTime(300000);
      const edit={levelId,publisherId:owner,requestId:String(i+1).repeat(32),revision:1,levelString};
      expect((await request(t,"/level","PATCH",edit)).status).toBe(200);
      expect((await request(t,"/level","PATCH",edit)).status).toBe(200);
      expect(await t.run(ctx=>ctx.db.get(levelId))).toMatchObject({likes:2,completions:1,revision:1});
      expect((await (await t.fetch(`/replays?levelId=${levelId}`)).json()).replays).toHaveLength(1);
    }
    // An in-progress run from before a rename still belongs to the same puzzle.
    expect((await request(t,"/complete","POST",{levelId,publisherId:visitor,runId:"f".repeat(32),revision:1,replayString:replay(input.levelString)})).status).toBe(200);
  });
  it("resets changed puzzles to the owner's like and deletes old replays without erasing new runs",async()=>{
    vi.useFakeTimers();
    const t=makeTest(),levelId=await publish(t);
    await request(t,"/complete","POST",{levelId,publisherId:visitor,runId,revision:1,vote:1,replayString:replay(input.levelString)});
    const oldReplay=await t.run(ctx=>ctx.db.query("replays").first());
    // Existing deployed rows without revision fields remain compatible.
    await t.run(async ctx=>{
      await ctx.db.patch(oldReplay!._id,{revision:undefined});
      const vote=await ctx.db.query("votes").withIndex("by_level_publisher",q=>q.eq("levelId",levelId).eq("publisherId",visitor)).unique();
      await ctx.db.patch(vote!._id,{revision:undefined});
    });
    vi.advanceTimersByTime(300000);
    const edit={levelId,publisherId:owner,requestId:"e".repeat(32),revision:1,levelString:changedCode()};
    expect((await request(t,"/level","PATCH",edit)).status).toBe(200);
    expect(await t.run(ctx=>ctx.db.get(levelId))).toMatchObject({likes:1,completions:0,revision:2});
    expect((await (await t.fetch(`/replays?levelId=${levelId}`)).json()).replays).toHaveLength(0);
    expect((await t.fetch(`/replay?id=${oldReplay!._id}`)).status).toBe(400);
    expect((await request(t,"/complete","POST",{levelId,publisherId:visitor,runId,revision:1})).status).toBe(400);
    const nextRun={levelId,publisherId:visitor,runId:"f".repeat(32),revision:2,vote:1,replayString:replay(edit.levelString)};
    expect((await request(t,"/complete","POST",nextRun)).status).toBe(200);
    await t.finishAllScheduledFunctions(()=>vi.runAllTimers());
    expect(await t.run(ctx=>ctx.db.get(oldReplay!._id))).toBeNull();
    expect(await t.run(ctx=>ctx.db.get(levelId))).toMatchObject({likes:2,completions:1});
    expect(await t.run(ctx=>ctx.db.query("votes").collect())).toHaveLength(2);
    expect(await t.run(ctx=>ctx.db.query("completions").collect())).toHaveLength(1);
    expect((await (await t.fetch(`/replays?levelId=${levelId}`)).json()).replays).toHaveLength(1);
  });
});
