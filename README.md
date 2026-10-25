# Chromatic Push

A Godot 4.7 2D platformer and color-block puzzle engine, validated with the included 4.7.2 executable. Open `project.godot` and press **F6** on `scenes/main.tscn`, or **F5** to run the project. Designed on a **16 × 16 pixel tile grid**, with a **960 × 540 base viewport** (1920/2 × 1080/2). Canvas stretching with **Expand** fills the window while keeping the artwork's aspect ratio: different window proportions reveal more world instead of stretching pixels. The camera magnifies the world 2× for readability and follows freely past level boundaries, including the origin. The player uses the supplied `assets/playerSprite.png`, flipping horizontally when moving left and retaining its facing direction when idle. The background is **40% dark / 60% brightness** (`#999999`); wall tiles are **80% dark / 20% brightness** (`#333333`). Color triggers preserve these brightness levels. No downloads or asset packs required.

## Controls

| Action | Keys |
| --- | --- |
| Move | A / D or Left / Right |
| Jump | W, Up, or Space; fixed 40px / 2½-tile height |
| Look down | S or Down |
| Recall nearby block/sphere or its empty spawn | R |
| Teleport player to nearest previously touched recall platform | Q |
| Restart level | Enter |
| Toggle gentle camera / particles | M |
| Open / leave independent level editor | Hold Shift + Z + P |

## In-game level editor

Hold **Shift + Z + P** together to enter `scenes/level_editor.tscn`. This is an independent scene that can also be run directly with F6. Every new editor session starts with a **clear board**, separate from the demo game. Its default dimensions fit the visible drawing area between the toolbar and palette. Build mode pauses simulation. The bottom palette contains Wall, Player, Block, Key tile, Door, Portal, Sphere, Platform, One-way, Theme, and Erase. Select an item, then **left-click or drag** on the grid to place it. **Right-click or drag** erases. Placing a player moves the single player spawn. Different object types can share a cell, allowing blocks on key tiles or portals.

Use the palette's **Color**, **Symbol**, **ID**, and **Door needs** controls before placing the corresponding objects. Select multiple door colors with the checkboxes. Matching keys and doors need the same ID. Adjacent same-color blocks weld when play starts.

**Columns / Rows** control level dimensions in 16px tile units, up to 512 × 512. **Snap px** controls object placement spacing from 1–64px; wall collision tiles remain 16px. Resizing the bounds preserves placed objects instead of deleting them. Use the middle mouse button to pan, the wheel to zoom, or WASD / arrows to move the build view. Click the grid after typing in a field to leave text entry.

Press **Space** to switch between Build and Playtest, or use the mode button. Every test starts from the authored layout, including fresh spawns and welds. Returning to Build preserves your layout and build camera rather than capturing moved puzzle pieces. Enter restarts a custom test level without losing its layout. Close or press Shift+Z+P to return to the demo game. **Save before leaving the editor**; reentering starts another blank board.

**Save** and **Load** are at the top left and open file dialogs for `.cpplevel` files. Saves contain compact JSON tuples compressed with whichever of Zstandard, FastLZ, Deflate, or Gzip produces the smallest result. A small versioned binary header records the codec and decompressed length; no Base64 overhead is added. Loading decompresses, validates, and restores grid dimensions, object positions, colors, link IDs, door requirements, portal symbols, and block/sphere timing settings. Invalid files leave your current layout unchanged. Empty or unfinished boards can be saved; playtesting requires exactly one player. Older level files retain their links because the existing link field is now read as `id`.

## Settings

Color changers expose **Cycle Hue** in the Godot Inspector and the in-game
editor. When enabled, touching the changer starts a continuous 12-second hue
loop. Touch a changer with Cycle Hue disabled to return to a fixed color.

The **gear button at the top right** opens Music and Sound effects sliders and keybind controls. The menu pauses gameplay and restores its previous pause state when closed. Sound effects use the `SFX` bus; a separate `Music` bus is ready for future tracks. Volumes are written immediately to `user://audio.cfg` and restored when the application starts, including after a complete exit.

Each gameplay action supports **up to three keyboard keys or mouse buttons**. Click a slot, then press its replacement. Delete/Backspace clears the slot; Escape cancels capture. The reset button restores defaults. Keybinds save immediately to `user://keybinds.cfg` and remain intact across level changes and application sessions. Gameplay has no persistent HUD text; contextual recall prompts use the first assigned key, so rebinding Q or R updates their displayed prompts.

Every reusable object scene now includes an **EditorIcon** sprite using a generated SVG identification icon from `assets/editor/`. These sprites appear in the Godot editor and as palette/build previews; they stay hidden during normal gameplay. `tools/install_editor_icons.gd` can reinstall them if you replace the object scenes. The block's small white inner rectangle appears only while settled on a matching key tile.

## Build your level

The **Fireworks area** palette object creates a dark gray backdrop and launches
fireworks from the bottom of the screen while the player is inside. Place the
separate **Completion text** object over it for the completion message and clickable
Discord invite. Edit the wording only in `scripts/ending_message.gd`: its named
title, victory, request, Discord URL, and closing fields keep their formatting
regardless of wording or line breaks. Scene overrides and saved levels no longer
store extra copies of this message. Both objects expose their dimensions in the Godot Inspector and
survive custom level saves. The sixteen-pixel support bar along the bottom links to
Discord and [Donate](https://ko-fi.com/snugglefox).

Open `scenes/main.tscn`. Select **Walls** and use the TileMap editor to paint the dark gray solid tile. Its TileSet is `assets/walls.tres`, including collision. Drag any reusable object scene from `scenes/` into **Objects**, including `one_way_block.tscn` and `color_trigger.tscn`. The included demo is editable; nothing overwrites your level at runtime.

Set editor move snapping to **16 × 16** with **8 × 8 offset** for block, pad, portal, sphere, and door centers. A floor tile at row 20 starts at y=320; blocks/pads sit at y=312 and the player's center at y=313. Place objects without overlapping solid walls. Doors occupy exactly **one 16 × 16 tile**, including their collider. Recall platforms are 16 × 4 and sit on the floor (center y=318 for this floor).

Choose each block/pad's **Block Color** dropdown: Cyan, Coral, Gold, Lilac. Colors distinguish the objects without extra color-count symbols. Starting positions automatically leave a permanent same-color dotted outline when play starts. Push while grounded for **more than 0.2 seconds**; the grounded block eases exactly **one tile** in **0.15 seconds**, then gravity resumes. Holding repeats the delay for every tile. A filled circle shrinks during charging. Push completion emits four small sparks from the lower leading corner, moving in the push direction within a **25-degree cone**, rather than a radial burst.

**Welding:** same-color blocks touching along an edge at startup automatically become a single compound body, including connected shapes extending horizontally or vertically. Diagonal contact does not weld, and later contact does not create new welds. Every constituent tile still counts toward matching pads and retains its dotted home marker. Push, gravity, teleport, and recall affect the whole group; recalling any member restores every member's original arrangement.

**Stack carrying:** pushing a box carries all boxes supported on it, recursively, including welded riders and overhangs. Sliding circles carry their supported stacks in any travel direction. Support is checked against the circle's curved surface. The whole stack is tested for obstacles; an obstructed upper box prevents a box push or stops a sliding circle. Riders keep their relative arrangement and remain independent objects unless welded at startup. Carrying does not transfer recall/teleport velocity, and matching keys/portals wait until carried boxes settle. Collision checks use Godot's native body motion tests to preserve one-way platform behavior.

**R recall:** stand near a block/sphere or its original dotted marker. Blocks allow **five extra pixels beyond contact**; the selected target becomes brighter. Only the closest eligible target is recalled. The object always returns to its exact authored spawn. If the player occupies that spawn, the player is lifted vertically just enough to stand on top, preserving their horizontal position. Left/right placement remains a fallback if the overhead space is blocked. If all exits are obstructed, or another solid object occupies the destination, recall is refused without overlapping bodies. A brief two-physics-frame settling period refreshes collision transforms, and teleport velocity is never inherited as player platform motion. Resting boxes preserve their grid column and snap out tiny vertical recovery errors, preventing drifting and unwanted launches. Recall effects and the blocked tone communicate the result.

**Symbol portals:** place two or more `symbol_portal.tscn` instances and choose **Symbol** from the Square / Circle / Triangle / Star Inspector dropdown. They have orange outlines and the chosen symbol. A block pushed onto one teleports to the nearest other portal with the same symbol; the full welded shape must fit. A lock prevents immediate bouncing between portals until the group leaves them. Blocks initially placed on portals stay put until pushed. A blocked nearest destination prevents teleporting rather than silently selecting a farther portal.

**White spheres:** `sliding_sphere.tscn` has no gravity. Player contact from any side starts a **0.2-second shake**, then a cardinal slide away from the contacted side. It stops on blocks, spheres, or solid walls. Continued contact does not repeatedly retrigger the charge; separate and touch again. White dotted circular home markers support R recall with the same safe player placement rules.

**Recall platforms:** placement drops each platform down to the nearest solid floor beneath its center, with the sprite's bottom flush to that surface. The player must touch a platform before it becomes eligible for teleporting. Among visited platforms, the nearest emits an upward glow and receives the dotted guide. It displays a gray **Q at 40% opacity** (or the remapped key). Q teleports the player onto it if the landing space is clear. Visits last until the level restarts. Selection follows straight-line distance, so visited platforms can be reached through walls. A blocked destination plays the blocked tone.

**Recall prompts:** standing inside a block/circle's original spawn displays **R above the player at 40% opacity**, in the object's color (white for spheres). Touching a box whose welded body is blocked on either horizontal side also displays the same prompt. The collision check excludes the player so ordinary contact does not count as a blocked side. Prompts follow remapped recall keys.

**One-way blocks:** `one_way_block.tscn` uses Godot's one-way collision. The player can jump through it from underneath and stand on its upper surface. Use the **One-way** palette item for placement.

**Color triggers:** `color_trigger.tscn` is an invisible, non-solid trigger in gameplay. Its diamond/icon remains visible in the Godot editor and build palette. Touching it changes background and tile hue. Its exported **Hex Color** accepts a hex code such as `#9955ff`; when empty or invalid, the exported **Color** uses Godot's native color picker. In the in-game editor, choose **Theme** and set Theme hex or the adjacent color picker. Background and tile brightness remain 60% and 20% while transitioning smoothly to the selected hue. One-way blocks receive the tile tint too. Both objects and trigger color settings survive compressed level saves.

For each door, select **Required Colors** (multiple checkboxes) and set its exported **id** string. Give matching key tiles the same exported **id**. Every key of each requested color with that ID must be filled by that color, and at least one key must exist for every requested color. Keys with different IDs do not affect that door. Pads use a 2px center tolerance and wait until the block finishes sliding. A missing color never opens a door. Multiple doors may share an ID. Faint gray dotted lines connect linked keys to their doors, using the same style as the player/platform guide; they render behind tiles and objects in gameplay and the build view. Doors use a recessed metal gate frame with retracting vertical bars in the required colors. They have no white center line. Gates close when a required key empties, waiting for actors to leave the doorway before closing.

The demo's A door needs **two Cyan pads AND one Coral pad**. B needs one Gold pad. It also includes an adjacent Lilac pair, a floating white sphere, two Square portals, and two recall platforms. All four block colors and all four portal symbols are available for new levels. The far end has one- and two-tile steps for jump practice. Falling below the level recalls the player or block. Enter restores the entire puzzle.

## Movement and camera satisfaction list — implemented

- Responsive ground acceleration and strong release friction; slightly softer air control.
- Every jump reaches **40px / 2½ tiles** using gravity-derived launch speed and a discrete-step correction.
- Up, W, Space, early releases, and remapped jump keys share the same jump height.
- **100ms coyote time** lets a late edge jump succeed; **120ms jump buffering** remembers a jump just before landing.
- Floor snapping keeps descending slopes and platform contacts stable; terminal velocity limits long falls.
- Jump stretch, landing squash, directional lean, dust bursts, and distinct jump/landing tones communicate motion without changing collision shapes.
- Exponential camera following remains consistent across frame rates.
- Smooth facing look-ahead, fall look-ahead, and manual downward look help plan jumps.
- A vertical dead zone keeps small jumps from bouncing the view; tracking continues freely beyond level edges and (0,0).
- Brief decaying impact shake and tiny zoom pulses emphasize landings, pushes, recalls, and doors. M disables these and particle bursts.

## Shader satisfaction list — implemented

- **Player:** a gentle moving highlight increases with vertical speed, complementing jump stretch.
- **Walls:** a fine bevel along each dark gray tile's upper edge helps read the surface, and color triggers can tint it.
- **Blocks:** moving surface highlights grow during push charge and recall flash, reinforcing the shrinking solid charge circle. Recall availability brightens the selected block or welded group.
- **Home outlines:** a subtle animated sheen keeps the dotted origin visible without suggesting a solid obstacle.
- **Matching pads:** animated highlights intensify as a correct block settles; a fading halo shows activation.
- **Doors:** colored bands carry a moving sheen; the energy decreases as the panels retract and returns as they close.
- **Whole scene:** a restrained vignette focuses the play area, very faint scanline texture adds cohesion, and short chromatic impact pulses emphasize contact. The HUD is rendered after the effect so text stays crisp.

Surface ShaderMaterials are local to each scene instance, so block/pad/door effects stay independent. Adjust `shaders/surface.gdshader` and `shaders/world.gdshader` to tune the look. Objects use SVG/vector drawing, with the supplied PNG for the player. All sound effects are generated as enveloped PCM sine/harmonic sweeps by `scripts/juice.gd`, with a 12-voice pool and no external audio files.

## Validation and maintenance

Run `Godot_v4.7.2-stable_win64.exe --headless --path . --script tools/test_game.gd` for 17 real physics checks: wall collision, push delay/distance, recall, fixed jump height for taps and holds, repeated and mixed pad requirements, door closing/safety, and block gravity.

Run the same command with `tools/test_new_mechanics.gd` for 23 additional checks covering welding, compound collision and movement, recall range/highlights and player exit order, nearest matching portals and blocked destinations, welded teleportation, sphere charging/sliding/recall, nearest platform selection and teleport, one-tile doors, and window stretching.

Use `tools/test_level_editor.gd` for 29 additional checks: a clear independent board, defaults fitted to its usable area, blank saves, hidden identification sprites, the Shift+Z+P shortcut, grid placement/erasing, snapping, the new palette objects and color fields, compressed file round trips, file validation, board dimensions, and repeatable Space switching without accidental jumping.

Use `tools/test_revision.gd` for 27 checks covering the supplied PNG and horizontal flipping, repeated live occupied-spawn recall, standing recalls without launches, audio buses/menu/volume, the independent editor, ID-based door logic and guide links, and the empty gameplay HUD.

Use `tools/test_new_controls.gd` for 27 additional checks covering gray defaults, fixed jump height, the unrestricted camera, touch activation and floor snapping, recall prompts, one-way physics, trigger hue changes, new object serialization, binding capture/clearing, three-slot limits, and saved keybinds.

Use `tools/test_stacks.gd` for 19 checks covering recursive carrying, left/right pushes, welded and overhanging riders, circle support geometry, horizontal/up/down movement, overhead obstructions, restored collision exclusions, darkness levels, and invisible color triggers. **All six suites total 142 checks.** Physics tests use `tools/test_world.gd` as an isolated fixture so changing the demo layout does not change the test results.

`tools/test_audio_persistence.gd -- --write` writes test volumes and three recall keybinds; running the same script again without `--write` verifies them in a new process. Use an isolated APPDATA directory for this test to keep personal preferences unchanged.

`tools/build_level.gd` creates the reusable scenes, TileSet, and sample level. **It overwrites these assets**, so use only when deliberately rebuilding the demo. Normal editing does not need it. `tools/capture.gd` saves a gameplay preview; add `-- --build` for the blank editor or `-- --audio` for the audio menu.
