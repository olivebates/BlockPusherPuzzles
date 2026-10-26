import { httpRouter } from "convex/server";
import { httpAction } from "./_generated/server";
import { internal } from "./_generated/api";
import { MAX_CODE } from "./codec";
import { validatePublish } from "./validation";

const http = httpRouter();
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PATCH, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
  "Access-Control-Expose-Headers": "Retry-After",
};
function json(body: unknown, status = 200, extra: Record<string, string> = {}) {
  return new Response(JSON.stringify(body), { status,
    headers: { ...cors, "Content-Type": "application/json", ...extra } });
}
const paths = ["/levels", "/level", "/attempt", "/complete", "/replays", "/replay"];
for (const path of paths) {
  http.route({ path, method: "OPTIONS", handler: httpAction(async () =>
    new Response(null, { status: 204, headers: cors })) });
}
for (const path of ["/levels", "/level", "/replays", "/replay"]) {
  http.route({ path, method: "GET", handler: httpAction(async (ctx, request) => {
    const q = new URL(request.url).searchParams;
    try {
      let result;
      if (path === "/levels") {
        const sort = q.get("sort") || "hot";
        if (!["hot","uncompleted","today","week","month","year"].includes(sort)) return json({error:"Unknown sort."},400);
        result = await ctx.runQuery(internal.levels.list, { sort, search: (q.get("search") || "").slice(0,100), cursor: q.get("cursor") || undefined });
      } else if (path === "/level") result = await ctx.runQuery(internal.levels.get, {levelId: q.get("id") as any});
      else if (path === "/replays") result = await ctx.runQuery(internal.replays.list, {levelId: q.get("levelId") as any, cursor:q.get("cursor") || undefined});
      else result = await ctx.runQuery(internal.replays.get, {replayId:q.get("id") as any});
      return json(result, "error" in result ? 400 : 200);
    } catch { return json({ error: "Couldn't load this page. Please try again." }, 400); }
  }) });
}
for (const [path, method] of [["/levels","POST"],["/level","PATCH"],["/level","DELETE"],["/attempt","POST"],["/complete","POST"]] as const) {
  http.route({ path, method, handler: httpAction(async (ctx, request) => {
    if (request.headers.get("Content-Type")?.split(";")[0].trim().toLowerCase() !== "application/json") return json({error:"Expected application/json."},415);
    const reader = request.body?.getReader();
    if (!reader) return json({error:"Missing submission."},400);
    let size = 0, body = "";
    const decoder = new TextDecoder();
    let input: any;
    try {
      while (true) {
        const chunk = await reader.read();
        if (chunk.done) break;
        size += chunk.value.byteLength;
        if (size > MAX_CODE + 4096) { await reader.cancel(); return json({error:"Submission too large."},413); }
        body += decoder.decode(chunk.value, { stream: true });
      }
      input = JSON.parse(body + decoder.decode());
      if (!input || typeof input !== "object" || Array.isArray(input)) return json({error:"Invalid submission."},400);
    } catch { return json({error:"Invalid JSON submission."},400); }
    try {
      let result;
      if (path === "/levels") {
        const valid = validatePublish(input);
        if (!valid) return json({error:"Invalid puzzle submission."},400);
        result = await ctx.runMutation(internal.levels.publish, valid);
      } else if (path === "/attempt") result = await ctx.runMutation(internal.levels.attempt, input);
      else if (path === "/complete") result = await ctx.runMutation(internal.replays.complete, input);
      else if (method === "PATCH") result = await ctx.runMutation(internal.levels.edit, input);
      else result = await ctx.runMutation(internal.levels.remove, input);
      if ("retryAfterSeconds" in result && !result.ok) return json(result,429,{"Retry-After":String(result.retryAfterSeconds)});
      return json(result, result.ok ? (path === "/levels" ? 201 : 200) : 400);
    } catch { return json({error:"Couldn't save this submission. Please try again."},400); }
  }) });
}
export default http;
