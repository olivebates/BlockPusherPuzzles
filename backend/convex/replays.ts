import { internalMutation, internalQuery } from "./_generated/server";
import { v } from "convex/values";
import { levelMeta, replayMeta, MAX_REPLAY_COMMENT } from "./codec";
import { hotScore, validIdentity, validRequest } from "./validation";

export const complete = internalMutation({
  args: { levelId: v.id("levels"), publisherId: v.string(), runId: v.string(), revision: v.number(),
    vote: v.optional(v.number()), replayString: v.optional(v.string()) },
  handler: async (ctx, args) => {
    if (!validIdentity(args.publisherId) || !validRequest(args.runId) ||
        (args.vote !== undefined && ![-1, 0, 1].includes(args.vote))) return { error: "Invalid completion." };
    const level = await ctx.db.get(args.levelId);
    if (!level || level.deleted) return { error: "This puzzle has been deleted." };
    if (level.revision !== args.revision) return { error: "This puzzle changed. Reopen it before saving a replay." };
    const replay = args.replayString ? replayMeta(args.replayString) : null;
    if (replay && [...replay.c].length > MAX_REPLAY_COMMENT) return { error: "Replay comments must be 40 characters or fewer." };
    if (args.replayString && (!replay || levelMeta(replay.l)?.l !== levelMeta(level.levelString)?.l || replay.n !== levelMeta(replay.l)?.n)) return { error: "Invalid replay." };
    const oldReplay = args.replayString ? await ctx.db.query("replays").withIndex("by_run", q =>
      q.eq("levelId", level._id).eq("publisherId", args.publisherId).eq("runId", args.runId)).unique() : null;
    const legacyRevision = level.resetRevision ? 1 : level.revision;
    if (oldReplay && (oldReplay.revision ?? legacyRevision) === level.revision && oldReplay.replayString !== args.replayString) return { error: "This run already has a saved replay." };
    const completed = await ctx.db.query("completions").withIndex("by_level_run", q =>
      q.eq("levelId", level._id).eq("publisherId", args.publisherId).eq("runId", args.runId)).unique();
    let completions = level.completions;
    if (!completed || completed.revision !== level.revision) {
      if (completed) await ctx.db.patch(completed._id, { revision: level.revision });
      else await ctx.db.insert("completions", { levelId: level._id, publisherId: args.publisherId, runId: args.runId, revision: args.revision });
      completions++;
    }
    let likes = level.likes;
    if (args.vote !== undefined) {
      const previous = await ctx.db.query("votes").withIndex("by_level_publisher", q => q.eq("levelId", level._id).eq("publisherId", args.publisherId)).unique();
      likes += args.vote - (previous && (previous.revision ?? legacyRevision) === level.revision ? previous.value : 0);
      if (previous) await ctx.db.patch(previous._id, { value: args.vote, revision: level.revision });
      else await ctx.db.insert("votes", { levelId: level._id, publisherId: args.publisherId, value: args.vote, revision: level.revision });
    }
    await ctx.db.patch(level._id, { likes, hot: hotScore(likes, level.publishedAt), completions });
    if (replay && args.replayString) {
      const record = { levelId: level._id, publisherId: args.publisherId, runId: args.runId, revision: level.revision,
        replayString: args.replayString, duration: (replay.frames.length - 1) / replay.fps, publishedAt: Date.now() };
      if (!oldReplay) await ctx.db.insert("replays", record);
      else if ((oldReplay.revision ?? legacyRevision) !== level.revision) await ctx.db.patch(oldReplay._id, record);
    }
    return { ok: true, likes: Math.max(0, likes) };
  },
});
export const list = internalQuery({
  args: { levelId: v.id("levels"), cursor: v.optional(v.string()) },
  handler: async (ctx, args) => {
    const level = await ctx.db.get(args.levelId);
    if (!level || level.deleted) return { error: "This puzzle has been deleted." };
    const result = await ctx.db.query("replays").withIndex("by_level", q => q.eq("levelId", args.levelId))
      .filter(q => q.or(q.eq(q.field("revision"), level.revision),
        q.and(q.eq(q.field("revision"), undefined), q.eq(level.resetRevision, undefined))))
      .order("desc").paginate({ numItems: 50, cursor: args.cursor || null });
    return { replays: result.page.map(row => {
      const replay = replayMeta(row.replayString)!;
      return { id: row._id, name: replay.n, author: replay.a, comment: replay.c, time: row.duration };
    }), cursor: result.isDone ? "" : result.continueCursor };
  },
});
export const get = internalQuery({
  args: { replayId: v.id("replays") },
  handler: async (ctx, args) => {
    const row = await ctx.db.get(args.replayId);
    const level = row && await ctx.db.get(row.levelId);
    if (!row || !level || level.deleted || (row.revision ?? (level.resetRevision ? 1 : level.revision)) !== level.revision) return { error: "This replay is no longer available." };
    return { replayString: row.replayString };
  },
});
