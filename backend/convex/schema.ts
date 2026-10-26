import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";
export default defineSchema({
  levels: defineTable({
    levelString: v.string(), publisherId: v.string(), requestId: v.string(),
    publishedAt: v.number(), revision: v.number(), likes: v.number(), hot: v.number(),
    completions: v.number(), deleted: v.boolean(),
    plays: v.optional(v.number()),
    editRequestId: v.optional(v.string()),
    resetRevision: v.optional(v.number()),
  }).index("by_publisher_request", ["publisherId", "requestId"])
    .index("by_hot", ["deleted", "hot"])
    .index("by_likes", ["deleted", "likes"])
    .index("by_uncompleted", ["deleted", "completions", "hot"]),
  publishers: defineTable({ publisherId: v.string(), nextPublishAt: v.number() })
    .index("by_publisher", ["publisherId"]),
  votes: defineTable({ levelId: v.id("levels"), publisherId: v.string(), value: v.number(), revision: v.optional(v.number()) })
    .index("by_level_publisher", ["levelId", "publisherId"]),
  completions: defineTable({ levelId: v.id("levels"), publisherId: v.string(), runId: v.string(), revision: v.number() })
    .index("by_level_run", ["levelId", "publisherId", "runId"]),
  attempts: defineTable({ levelId: v.id("levels"), publisherId: v.string(), runId: v.string(), revision: v.number() })
    .index("by_level_run", ["levelId", "publisherId", "runId"]),
  replays: defineTable({ levelId: v.id("levels"), publisherId: v.string(), runId: v.string(),
    replayString: v.string(), duration: v.number(), publishedAt: v.number(), revision: v.optional(v.number()) })
    .index("by_level", ["levelId"])
    .index("by_run", ["levelId", "publisherId", "runId"]),
});
