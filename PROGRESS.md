Pip is the player fox; Sunny is the yellow NPC fox.

The story objects have individual scenes:
`large_door.tscn`, `collectible.tscn`, `indicator.tscn`, `npc_fox.tscn`, and
`dialogue_trigger.tscn`. `large_door_encounter.tscn` groups Sunny, a door, three
indicators, and three pickups. `story_demo.tscn` is a playable example; the
authored main scene is preserved.

Place the large door with its origin eight pixels above the floor. It occupies
32 x 64 pixels, extending 56 pixels above its origin. All indicators within
320 pixels of its origin must be lit; a door without indicators stays closed.
Each pickup lights the nearest unlit indicator. Set persistent IDs on pickups
or dialogue triggers when you need stable identities while moving them in a level.

Space, Enter, E, or the dialogue arrow advances text. Talk defaults to E and can
be rebound in settings. Opening, NPC introductions, and challenge triggers run
once per progress save. An unfinished conversation resumes at its saved line.

The main game saves every five seconds to `user://progress/current.cps`, retains
a previous atomic save, keeps 20 ten-minute backups and 5 launch saves, and saves
when the application loses focus. Settings > Backups restores a selected backup.
Delete Progresse requires three separate confirmations and deletes progress and
backups, retaining audio settings and keybindings.
Shift+Z+M performs the same deletion immediately without confirmation, including
while a dialogue or settings menu is open.

TAB opens Map Teleport. WASD or arrow keys select a visited platform; Space
teleports to it, including off-screen destinations. TAB or a click outside the
panel closes the map. The world pauses while it is open. Each wall tile is one
pixel in the underlying nearest-filtered map texture, which fits the panel.
The Map hint object (`map_trigger.tscn`) is a one-time shared tutorial trigger:
it shows TAB above Pip, changes to TAB - Teleport after a map visit without a
teleport, and disappears permanently after the first successful map teleport.
These tutorial flags are included in progress saves and backups.

Files contain compact JSON, the smallest result among Godot's four supported
lossless codecs, and a SHA-256 checksum. They use Godot FileAccess/DirAccess on
both desktop and Web, with JavaScriptBridge.force_fs_sync() on Web writes.
Browser persistence uses IndexedDB and requires browser storage to be allowed.
The single-thread Web export preset uses the Compatibility renderer and does
not require cross-origin isolation headers. Export templates must be installed
in Godot before exporting `Web` to `build/web/index.html`.
