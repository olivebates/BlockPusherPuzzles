import { internalMutation, internalQuery } from "./_generated/server";
import { internal } from "./_generated/api";
import { v } from "convex/values";
import { COOLDOWN_MS, hotScore, validatePublish, validIdentity, validRequest } from "./validation";
import { levelMeta } from "./codec";
export const publish = internalMutation({
  args: { levelString: v.string(), publisherId: v.string(), requestId: v.string() },
  handler: async (ctx, args) => {
    const input = validatePublish(args);
    if (!input) return { ok: false, error: "Invalid puzzle submission." };
    const now = Date.now();
    const owner = await ctx.db.query("publishers").withIndex("by_publisher", q => q.eq("publisherId", input.publisherId)).unique();
    const old = await ctx.db.query("levels").withIndex("by_publisher_request", q => q.eq("publisherId", input.publisherId).eq("requestId", input.requestId)).unique();
    if (old) return old.levelString === input.levelString && !old.deleted
      ? { ok: true, levelId: old._id, retryAfterSeconds: Math.max(0, Math.ceil(((owner?.nextPublishAt ?? 0)-now)/1000)) }
      : { ok: false, error: "Request ID already used." };
    if (owner && owner.nextPublishAt > now) return { ok: false, error: "Please wait before publishing another puzzle.", retryAfterSeconds: Math.ceil((owner.nextPublishAt-now)/1000) };
    const levelId = await ctx.db.insert("levels", { ...input, publishedAt: now, revision: 1, likes: 1,
      hot: hotScore(1, now), completions: 0, plays: 0, deleted: false });
    await ctx.db.insert("votes", { levelId, publisherId: input.publisherId, value: 1, revision: 1 });
    if (owner) await ctx.db.patch(owner._id, { nextPublishAt: now + COOLDOWN_MS });
    else await ctx.db.insert("publishers", { publisherId: input.publisherId, nextPublishAt: now + COOLDOWN_MS });
    return { ok: true, levelId, retryAfterSeconds: 300 };
  },
});
export const list = internalQuery({
  args: { sort: v.string(), search: v.string(), cursor: v.optional(v.string()) },
  handler: async (ctx, args) => {
    const windows: Record<string, number> = { today: 1, week: 7, month: 30, year: 365 };
    const rankedByLikes = args.sort in windows;
    const field = rankedByLikes ? "likes" : "hot";
    let query = args.sort === "uncompleted"
      ? ctx.db.query("levels").withIndex("by_uncompleted", q => q.eq("deleted", false).eq("completions", 0))
      : rankedByLikes
        ? ctx.db.query("levels").withIndex("by_likes", q => q.eq("deleted", false))
        : ctx.db.query("levels").withIndex("by_hot", q => q.eq("deleted", false));
    let cursor: number[] | null = null;
    try { cursor = args.cursor ? JSON.parse(args.cursor) : null; } catch { return { error: "Invalid page." }; }
    if (cursor && (!Array.isArray(cursor) || cursor.length !== 2 || !cursor.every(Number.isFinite))) return { error: "Invalid page." };
    if (cursor) query = query.filter(q => q.or(q.lt(q.field(field), cursor![0]),
      q.and(q.eq(q.field(field), cursor![0]), q.lt(q.field("_creationTime"), cursor![1]))));
    if (rankedByLikes) query = query.filter(q => q.gte(q.field("publishedAt"), Date.now() - windows[args.sort] * 86400000));
    const search = args.search.trim().toLowerCase();
    const result = [];
    for await (const row of query.order("desc")) {
      const meta = levelMeta(row.levelString);
      if (!meta || (search && !meta.n.toLowerCase().includes(search) && !meta.a.toLowerCase().includes(search))) continue;
      result.push({ id: row._id, name: meta.n, author: meta.a, description: meta.d,
        likes: Math.max(0, row.likes), plays: row.plays ?? 0, revision: row.revision, publishedAt: row.publishedAt,
        pageKey: [row[field], row._creationTime] });
      if (result.length === 51) break;
    }
    const more = result.length > 50;
    const page = result.slice(0, 50);
    return { levels: page.map(({ pageKey, ...item }) => item),
      cursor: more ? JSON.stringify(page[49].pageKey) : "" };
  },
});
export const get = internalQuery({
  args: { levelId: v.id("levels") },
  handler: async (ctx, { levelId }) => {
    const row = await ctx.db.get(levelId);
    if (!row || row.deleted) return { error: "This puzzle has been deleted." };
    return { id: row._id, levelString: row.levelString, revision: row.revision, likes: Math.max(0, row.likes), plays: row.plays ?? 0 };
  },
});
export const attempt = internalMutation({
  args: { levelId: v.id("levels"), publisherId: v.string(), runId: v.string(), revision: v.number() },
  handler: async (ctx, args) => {
    if (!validIdentity(args.publisherId) || !validRequest(args.runId)) return { error: "Invalid play attempt." };
    const level = await ctx.db.get(args.levelId);
    if (!level || level.deleted) return { error: "This puzzle has been deleted." };
    const old = await ctx.db.query("attempts").withIndex("by_level_run", q =>
      q.eq("levelId", args.levelId).eq("publisherId", args.publisherId).eq("runId", args.runId)).unique();
    if (old) return { ok: true, plays: level.plays ?? 0 };
    if (level.revision !== args.revision) return { error: "This puzzle changed. Reopen it before playing." };
    const plays = (level.plays ?? 0) + 1;
    await ctx.db.insert("attempts", args);
    await ctx.db.patch(level._id, { plays });
    return { ok: true, plays };
  },
});
export const edit = internalMutation({
  args: { levelId: v.id("levels"), publisherId: v.string(), requestId: v.string(), revision: v.number(), levelString: v.string() },
  handler: async (ctx, args) => {
    const row = await ctx.db.get(args.levelId);
    if (!row || row.deleted || !validIdentity(args.publisherId) || row.publisherId !== args.publisherId) return { error: "Only the uploader can edit this puzzle." };
    if (!validRequest(args.requestId)) return { error: "Invalid edit request." };
    const owner = await ctx.db.query("publishers").withIndex("by_publisher", q => q.eq("publisherId", args.publisherId)).unique();
    const now = Date.now();
    if (row.editRequestId === args.requestId && row.levelString === args.levelString)
      return { ok: true, levelId: row._id, revision: row.revision, retryAfterSeconds: Math.max(0, Math.ceil(((owner?.nextPublishAt ?? 0)-now)/1000)) };
    if (row.revision !== args.revision) return { error: "This puzzle changed. Reopen it before editing." };
    const nextMeta = levelMeta(args.levelString);
    if (!nextMeta) return { error: "Invalid puzzle." };
    if (owner && owner.nextPublishAt > now) return { error: "Please wait before publishing again.", retryAfterSeconds: Math.ceil((owner.nextPublishAt-now)/1000) };
    const modified = nextMeta.l !== levelMeta(row.levelString)?.l;
    const revision = row.revision + (modified ? 1 : 0);
    await ctx.db.patch(row._id, { levelString: args.levelString, revision, editRequestId: args.requestId,
      ...(modified ? { likes: 1, hot: hotScore(1, row.publishedAt), completions: 0, resetRevision: revision } : {}) });
    if (modified) {
      const vote = await ctx.db.query("votes").withIndex("by_level_publisher", q => q.eq("levelId", row._id).eq("publisherId", args.publisherId)).unique();
      if (vote) await ctx.db.patch(vote._id, { value: 1, revision });
      else await ctx.db.insert("votes", { levelId: row._id, publisherId: args.publisherId, value: 1, revision });
      await ctx.scheduler.runAfter(0, internal.levels.purgePreviousRevision, { levelId: row._id });
    }
    if (owner) await ctx.db.patch(owner._id, { nextPublishAt: now + COOLDOWN_MS });
    else await ctx.db.insert("publishers", { publisherId: args.publisherId, nextPublishAt: now + COOLDOWN_MS });
    return { ok: true, levelId: row._id, revision, retryAfterSeconds: 300 };
  },
});
// Old records disappear immediately from reads; clean them up in bounded batches.
// Reading the latest revision each time also makes consecutive edits safe.
export const purgePreviousRevision = internalMutation({
  args: { levelId: v.id("levels") },
  handler: async (ctx, { levelId }) => {
    const level = await ctx.db.get(levelId);
    if (!level || level.deleted) return;
    const rows = [
      ...await ctx.db.query("replays").withIndex("by_level", q => q.eq("levelId", levelId))
        .filter(q => q.neq(q.field("revision"), level.revision)).take(100),
      ...await ctx.db.query("votes").withIndex("by_level_publisher", q => q.eq("levelId", levelId))
        .filter(q => q.neq(q.field("revision"), level.revision)).take(100),
      ...await ctx.db.query("completions").withIndex("by_level_run", q => q.eq("levelId", levelId))
        .filter(q => q.neq(q.field("revision"), level.revision)).take(100),
    ];
    for (const row of rows) await ctx.db.delete(row._id);
    if (rows.length) await ctx.scheduler.runAfter(0, internal.levels.purgePreviousRevision, { levelId });
  },
});
export const remove = internalMutation({
  args: { levelId: v.id("levels"), publisherId: v.string() },
  handler: async (ctx, args) => {
    const row = await ctx.db.get(args.levelId);
    if (!row || !validIdentity(args.publisherId) || row.publisherId !== args.publisherId) return { error: "Only the uploader can delete this puzzle." };
    await ctx.db.patch(row._id, { deleted: true });
    await ctx.scheduler.runAfter(0, internal.levels.purge, { levelId: row._id });
    return { ok: true };
  },
});
export const purge = internalMutation({
  args: { levelId: v.id("levels") },
  handler: async (ctx, { levelId }) => {
    const level = await ctx.db.get(levelId);
    if (!level?.deleted) return;
    const rows = [
      ...await ctx.db.query("replays").withIndex("by_level", q => q.eq("levelId", levelId)).take(100),
      ...await ctx.db.query("votes").withIndex("by_level_publisher", q => q.eq("levelId", levelId)).take(100),
      ...await ctx.db.query("completions").withIndex("by_level_run", q => q.eq("levelId", levelId)).take(100),
      ...await ctx.db.query("attempts").withIndex("by_level_run", q => q.eq("levelId", levelId)).take(100),
    ];
    for (const row of rows) await ctx.db.delete(row._id);
    if (rows.length) await ctx.scheduler.runAfter(0, internal.levels.purge, { levelId });
    else await ctx.db.delete(levelId);
  },
});
