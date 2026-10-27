# Changelog

Record every substantive change here from this version onward. Add ongoing work
under **Unreleased**, then move it into a dated release section when releasing.
Earlier work predates this log and has no assigned release history.

## Unreleased

### Changed

- Moved the main gameplay "snugglefox.net" credit to the bottom-left corner,
  above the support-button row.

- Added small white "snugglefox.net" text above the main game's three bottom
  buttons, revealed alongside them, and at the bottom left during custom-level
  play. The labels do not intercept mouse input.

- Automatic rainbow hue cycling now changes only the rendered world palette.
  The Tab map keeps the last explicitly chosen target color, including when
  sampling a tile at a new closest approach during the cycle. Normal color
  changers still update the map target. Saved fields and data versions are
  unchanged.

- Renamed the community completion/replay publishing prompt from "Save Replay?"
  to "Rate" while keeping its voting and replay-saving actions.
- Added a synthesized C–E–G–C victory jingle with a soft major-chord finish. It
  follows SFX volume/mute and plays through paused completion dialogs using a
  dedicated voice, even when other sound channels are occupied.
- Play the victory sound when the Rate prompt opens, a replay naturally reaches
  its last frame, or an editor playtest is beaten (including publishing tests).
  Scrubbing is silent; an ended or paused replay cannot repeat the sound.
- Added audio, paused/busy playback, replay-end, and editor-completion regression
  checks. The audio check also exports `.godot/victory-preview.wav` for audition.
  Saved replay fields and data versions remain unchanged; no backend deployment
  or migration is required.

- Closest-visit Tab map samples now use the destination hue palette during a
  color transition, including interrupted transitions. Normal world rendering
  retains the animated blend and continuous hue cycling still updates its target.
- Q platforms and their placement previews now snap flush to supporting floors
  in the editor. Hit testing and erasing use their displayed position while
  stored layout coordinates and old level codes remain unchanged.
- Editor outlined key targets reject every other tile, including matching
  pushable blocks. Placing a key onto an existing object is also blocked so
  placement order cannot create an overlap. Previously saved overlaps remain
  readable; erasing keys and changing their colors still work normally.
- Added a non-mutating `POST /validate-level` endpoint using the exact publishing
  validator. It reports the backend data version and does not create catalogue
  entries, ownership, or cooldowns, allowing real draft validation before upload.
- Added target-palette, platform alignment/erasing, protected-key placement, and
  non-mutating upload validation regression checks. Deploy the current backend
  to the configured community endpoint to enable version-3 publishing and the
  validation route. No new data version or record migration is needed.
- Deployed the compatible backend to the existing `uncommon-dachshund-960`
  development deployment on 2026-10-26. The actual saved draft passed its live
  validation endpoint (HTTP 200, data version 3), and browser preflight returned
  HTTP 204. Validation created no level and did not start a publishing cooldown.

- Editor lightning now expands in both directions, stopping at the closest wall
  on each side or the board boundary. Painting floor tiles over a beam moves
  its terminal to the new wall; painting over its hidden anchor preserves the
  larger remaining side. Other objects remain blocked within the shortened
  footprint. Custom play uses the same span, and existing campaign emitters
  retain their authored direction. Packed emitter fields remain unchanged.
- Added bidirectional lightning, wall insertion, freed space, anchor replacement,
  undo, packed round-trip, and matching playtest extent regression checks.

- The Tab map now records each visible cell's palette-transformed background
  and wall colors when the player reaches a new minimum distance to its center.
  Farther visits and equal-distance hue changes keep the earlier colors;
  movement updates samples even when the camera stays still. These samples
  remain session state, so the saved exploration format and data version do
  not change.
- Fixed editor/community blocks sinking into newly created floors before
  TileMap physics synchronization. Floor and push checks now find the body's
  own ancestor world instead of looking only in the current scene. Added a
  regression for the first physics tick, welded blocks, repeated playtests,
  and pushing without recalling the block.
- Removed the translucent square behind one-way platforms. Their shared game
  and editor drawing now shows only the light-gray top strip and highlight.

- Fixed editor Exit failing to save levels containing the newly exposed objects.
  Data version 3 extends unused packed-cell values for Q platforms, one-way and
  pass through blocks, all portal symbols, and default lightning emitters.
  Versions 1–2 retain their original meanings and remain readable. Godot and
  Convex share the updated manifest; new native/backend regression fixtures sit
  alongside historical fixtures. Deploy the updated Convex backend before
  distributing clients that publish version-3 levels or replays. Existing cloud
  records need no migration; older drafts upgrade when next saved.
- Hid the campaign Tab hint in custom levels and editor playtests. Custom Q
  platforms activate on first contact, show Q on the closest active visible
  platform, and support recall through a guide in each custom play world.
- Added Q recall input to new replay recordings and allowed static editor
  objects alongside recorded actors without changing older replay tracks.
- Renamed the editor's phase wall to "Pass through block", enabled its connected
  edge tiling, and moved the Q platform immediately after floor tiles.
- Shared runtime/editor drawing for Q platforms, one-way and pass through blocks,
  and teleporters. Teleporter outlines are inset one more pixel; one-way blocks
  use light gray. Side-entry boxes pass through one-way platforms without gaining
  a false floor, while boxes falling onto the top remain supported.

- Fixed the Tab map's interaction with the global hue shader: each visible cell
  captures its current palette-transformed background and tile colors, and the
  map renders after the hue pass so later hue changes cannot recolor old cells.
  Hue transitions and cycling refresh visible cells even with a stationary camera.

- Map cells remember their last visible background and wall colors during play,
  including color changes while the camera stays still. Saved exploration keeps
  its existing format; historical colors are rebuilt as areas are revisited
  after loading a save. No data-version change or deployment is required.
- The level editor offers phase walls, Q teleport platforms, one-way blocks,
  circle/triangle/star teleporters, and lightning emitters. Square teleporters
  remain readable in existing levels but are omitted from the palette.
- Placing a third teleporter of one symbol shows "Only 2 of each teleporter may
  be used." Space or Escape dismisses this warning.
- Lightning reserves its complete wall-to-wall path in the editor. Placement
  cannot overlap other objects, and right-clicking any beam cell deletes the
  whole emitter. Undo restores the emitter and its footprint.
- Added editor placement, popup keyboard, and map color-memory regression checks.

## 1.0.0 — 2026-10-26

### Added

- One central `version.json` for the game release, current data version (2),
  oldest readable data version (1), and implicit legacy version (1).
- Shared version checks for Godot saves, level snapshots, editor/community
  levels, replay recordings, and Convex validation.
- Explicit versions in new saves, levels, and replays; packed editor levels
  now use `CPE3:` with a two-byte data-version header. Metadata stays compressed
  inside `CPE2:` codes; replay recordings keep their `CPR1:` container.
- Compatibility tests for legacy/current data and invalid/future versions.
- Repository instructions requiring changelog updates for subsequent changes.
- Versioning documentation and native, backend, and browser regression checks,
  including version persistence across browser reloads.

### Compatibility

- Existing version-1 `CPS1`, `CPP1`, `CPE1:`, `CPE2:`, and `CPR1:` data remains
  readable. Writers use the current version without modifying input data.
- Unsupported versions are rejected instead of being silently relabeled.
- Opening unsupported-version saves or editor drafts blocks automatic saving
  and offers Back, preserving the original files and backups.
- A level's version-header upgrade alone does not reset likes or replays.
- Older in-flight replay uploads still belong to the same puzzle after a
  version-only upgrade; unsupported replay records are skipped in listings.
- The shared manifest is included in the Web export and the browser test
  project. No database migration or bulk rewrite of cloud levels is needed.
