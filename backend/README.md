# Community levels and replays

The Godot client uses `https://uncommon-dachshund-960.convex.site`.
This backend provides puzzle publishing, browsing, owner updates/deletion,
completion tracking, votes, and compressed replay storage.

## Deploy

Use Node.js 22 or newer, then run from this folder:

```sh
npm ci
npx convex login
npx convex dev --once
```

Select the **existing project** containing `uncommon-dachshund-960`.
The CLI writes deployment settings to the ignored `.env.local`.
For its production deployment run `npm run deploy`; for its development
deployment run `npx convex dev --once`. In CI, set `CONVEX_DEPLOY_KEY` for the
exact target deployment and run `npm run deploy`. The HTTP host ending in
`.convex.site` differs from the CLI's `.convex.cloud` endpoint.

An OPTIONS request to `/levels` should return 204 after deployment. Deploy
keys belong in your local environment or CI, never in the game or web build.
The repository's backend is excluded from Godot scans by `.gdignore`.

## API

All routes include CORS headers and accept browser preflight requests.

| Method | Path | Behavior |
| --- | --- | --- |
| GET | `/levels?sort=hot&search=&cursor=` | Up to 50 matching entries, plus next-page cursor |
| POST | `/levels` | Publish a level and add the uploader's initial like |
| GET | `/level?id=...` | Fetch a puzzle code and revision |
| PATCH | `/level` | Owner update, with expected revision and request ID |
| DELETE | `/level` | Owner deletion; batched removal of related records |
| POST | `/attempt` | Count a level start once per player/run ID |
| POST | `/complete` | Record a completion; optionally vote and save a replay |
| GET | `/replays?levelId=...&cursor=` | Up to 50 replays with metadata and duration |
| GET | `/replay?id=...` | Fetch one compressed replay |

Publish body:

```json
{
  "levelString": "CPE2:...",
  "publisherId": "64 lowercase hexadecimal characters",
  "requestId": "32 lowercase hexadecimal characters"
}
```

Updates add `levelId` and `revision`; deletes need `levelId` and
`publisherId`. Completion requests contain `levelId`, `revision`,
`publisherId`, and a unique `runId` (32 hexadecimal characters).
Optional `vote` is -1, 0, or 1; optional `replayString` is a CPR1 code.
Omitting a vote leaves the existing vote unchanged.
Play attempts use `levelId`, `revision`, `publisherId`, and `runId` too.
The counter increments when community play starts, even if the player never
finishes. Retries reuse the same run ID. Replay viewing and editor tests do not
count. Play counts persist across edits; existing puzzles start at zero.

Publishing and updates share a five-minute cooldown. Successful responses
include `retryAfterSeconds`; a cooldown rejection returns HTTP 429 with both
that field and `Retry-After`. Retries reuse a request ID to avoid duplicate
levels or updates. A replay run ID similarly prevents duplicate completions
and replay uploads.

## Storage and sorting

Names, authors, and descriptions are stored only inside the level code.
Replay names, authors, and comments are stored only inside the replay code.
The database stores the small numeric fields needed for ranking, revision
control, completion counts, and replay durations separately.

Votes are unique per anonymous installation and level. New levels receive
a +1 vote from their uploader. Likes are the net vote count, with a display
minimum of zero; ranking still uses the signed count.

Hot uses the [published Reddit formula](https://github.com/reddit-archive/reddit/blob/master/r2/r2/lib/db/_sorts.pyx):
`sign(score) * log10(max(abs(score), 1)) + (uploadSeconds - 1134028003) / 45000`,
rounded to seven decimal places. No Completions filters the current revision
to zero completions, then uses Hot. Top Today/Week/Month/Year rank net likes
among levels uploaded in the last 1/7/30/365 days respectively.

Search is a case-insensitive substring match against the embedded name or
author. Queries walk ranking indexes and decode metadata until they find a
page of matching entries, rather than duplicating the text in search columns.
This favors compact storage; very large catalogues may eventually need a
separate search index to remain within Convex query read limits.

Edits preserve the level ID and original publication time. Uploading a changed
puzzle increments its revision, resets likes to the uploader's initial like,
resets completion counts, and removes old replays and votes. Old replays are
hidden immediately and permanently removed in batches. Opening the editor,
canceling an edit, and uploads that only change name/author/description preserve
likes, completions, and replays. Completions for an outdated puzzle revision are
rejected. Deletion hides the level
immediately and permanently removes its replays, votes, and completion rows
in scheduled batches.

## Codes and playback

CPE1 packed puzzle codes remain readable. CPE2 wraps a CPE1 code with
`{n: name, a: author, d: description, l: puzzleCode}`.
CPR1 contains `{v, n, a, c, l, fps, kinds, frames}`: version, puzzle name,
replay author, comment, level snapshot, tick rate, object types, and frames.
An empty replay author becomes Anonymous.

Both envelopes use Base64 over a one-byte codec tag, a four-byte
little-endian uncompressed length, and gzip-compressed UTF-8 JSON (or raw
JSON if smaller). Names allow 80 characters, authors 40, descriptions 100,
and new replay comments 40. Older replay codes with
comments up to 100 characters remain readable. The replay menu reserves enough
column width for every newly submitted comment.

A replay records held and newly pressed actions at 60 physics ticks per
second, plus quantized changes to visible player, block, key, and rotator
state. Playback consumes this recorded track with live gameplay input and
physics disabled. The state track preserves the exact recorded movement
across engine/platform differences; checkpoints reconstructed every 120
frames make forward/backward scrubbing immediate without simulating from
the start. Playback keeps the first five seconds of each input-free interval
and skips the remaining idle time to the next input (or the final frame).
Original timestamps, completion duration, and all recorded frames remain intact
for timeline scrubbing. The timeline includes Pause/Play and Back to the replay list.
Replay duration is derived from the frame count, not a client-provided score.
Recordings are bounded to 30 minutes, 32 MiB expanded, and 900,000 encoded
characters; a larger run can complete and vote but cannot upload a replay.

## Browser ownership

Each uploaded level sets a `cp_level_<id>` cookie containing its ID, scoped
to the game origin for 400 days. These cookies control the web Edit/Delete
buttons. Native builds use the ownership list in
`user://level_publishing.cfg`. The same settings preserve the random
publisher identity and cooldown. The server verifies that identity before
allowing edits/deletion; knowing a public level ID alone is insufficient.

This is anonymous, browser-local ownership and voting, not an account
system. Clearing application data loses that identity. Completion is checked
by the game; the API validates recording structure but does not independently
prove a solution by simulating it.

## Tests

```sh
npm run typecheck
npm test
```

Backend tests use an in-memory Convex database and never upload to the live
deployment. `tests/fixtures/godot.json` contains real Godot-generated codes
for cross-language compatibility tests.

From the repository root, run the bundled Godot executable with
`--headless --path . --script` and one of:

- `tools/test_community.gd`: browsing, real completion, replay capture,
  metadata, seeking, keyboard isolation, and main-game restoration.
- `tools/test_level_publishing.gd`: completion gate, publishing form,
  real local HTTP requests, retry IDs, and cooldown persistence.
- `tools/test_level_editor.gd`: existing editor regressions.

The community test uses a fake cloud service. Add `-- --capture` and omit
`--headless` to capture the browser, completion prompt, and replay viewer
under `.godot/`. It also writes `.godot/community-fixtures.json` for
regenerating the compatibility fixture.
