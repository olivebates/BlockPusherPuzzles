extends SceneTree
var failures := 0
var victories := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ")+message)
	if not value: failures+=1
func key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=true
	return event
func paint(editor: Node2D, kind: int, hue: int, cell: Vector2i) -> void:
	editor.select_tool(kind,hue)
	editor.last_cell=Vector2i(-1,-1)
	editor.stroke_saved=false
	editor.erase=false
	editor.paint_at(cell)
func run() -> void:
	root.get_node("Juice").sound_played.connect(func(kind: String):
		if kind=="victory": victories+=1)
	create_timer(45,true).timeout.connect(func(): quit(99))
	var progress := root.get_node("Progress")
	progress.save_root="res://.godot/level-editor-test-progress"
	var session := root.get_node("LevelEditorSession")
	# Catalogue availability must not make editor regression tests depend on the cloud.
	session.service.endpoint="http://127.0.0.1:1/levels"
	session.draft_path="res://.godot/level-editor-test-draft.cpe"
	if FileAccess.file_exists(session.draft_path): DirAccess.remove_absolute(session.draft_path)
	var game: Node2D=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	for i in 12: await process_frame
	root.get_node("Dialogue").stop()
	var player: CharacterBody2D=get_first_node_in_group("player")
	player.set_physics_process(false)
	player.position=Vector2(56,313)
	var saved_position := player.position
	var support := game.get_node("SupportLinks/SupportBar")
	check(support.get_child_count()==3 and support.get_child(2).caption=="Level Editor","Level Editor sits immediately to the right of Donate")
	session.warned=false
	session.open_menu()
	check(paused and is_instance_valid(session.overlay),"Opening editor pauses gameplay and opens spoiler warning")
	check(session.overlay.rows.get_child(0).text==session.WARNING,"First warning uses the requested text")
	check(session.overlay.actions.get_child(0).text=="Back" and session.overlay.actions.get_child(1).text=="Continue","Warning offers Back and Continue")
	session.close_menu()
	check(not paused and not session.warned,"Back resumes gameplay without accepting the warning")
	session.open_menu()
	session.overlay._input(key(KEY_ESCAPE))
	check(not paused and not is_instance_valid(session.overlay),"Escape closes the warning and resumes gameplay")
	session.open_menu()
	session.accept_warning()
	check(session.warned and session.overlay.actions.get_child_count()==1 and session.overlay.actions.get_child(0).text=="Make Levels","Continue opens a menu containing only Make Levels")
	session.enter_editor()
	for i in 4: await process_frame
	var editor := current_scene
	check(editor!=game and editor.scene_file_path=="res://scenes/level_editor.tscn","Make Levels opens a separate editor scene")
	check(not game.is_inside_tree() and not progress.enabled,"Main game is suspended and editor cannot autosave over progress")
	var saved: Dictionary=progress.read_file(session.TEMP_PATH)
	check(not saved.is_empty() and saved.player==[56.0,313.0],"Temporary file contains the main-game progress")
	check(editor.palette_buttons.size()==19,"Palette includes phase walls, recall platforms, one-way blocks, three teleporters and lightning")
	for symbol in range(1,4):
		paint(editor,5,symbol,Vector2i(1,symbol))
		paint(editor,5,symbol,Vector2i(2,symbol))
		paint(editor,5,symbol,Vector2i(3,symbol))
		check(editor.data.objects.size()==symbol*2 and is_instance_valid(editor.popup) and editor.popup.rows.get_child(0).text=="Only 2 of each teleporter may be used.","Third teleporter of each symbol shows the exact limit message")
		editor._input(key(KEY_SPACE if symbol%2 else KEY_ESCAPE))
		check(not is_instance_valid(editor.popup) and not editor.playing and not paused,"Space or Escape dismisses teleporter warning without starting play")
	editor.data.objects=[]
	paint(editor,0,0,Vector2i(1,5))
	paint(editor,0,0,Vector2i(8,5))
	paint(editor,18,0,Vector2i(3,5))
	check(editor.data.objects.size()==1 and editor.lightning_cells(editor.data.objects[0])==Rect2i(2,5,6,1),"Lightning reserves the full path between walls")
	for kind in [1,2,3,5,7,8,18,20]: paint(editor,kind,1,Vector2i(6,5))
	check(editor.data.objects.size()==1 and not editor.data.tiles.has([6,5]),"Objects cannot be painted over a beam")
	paint(editor,0,0,Vector2i(6,5))
	check(editor.data.tiles.has([6,5]) and editor.lightning_cells(editor.data.objects[0])==Rect2i(2,5,4,1),"Floor tiles can cut a beam and move its opposing terminal to the new wall")
	editor.erase=true
	editor.last_cell=Vector2i(-1,-1)
	editor.paint_at(Vector2i(5,5))
	check(editor.data.objects.is_empty(),"Right click at the far end deletes the whole emitter")
	editor.undo()
	check(editor.data.objects.size()==1,"Undo restores the emitter and full footprint")
	editor.data.objects=[]
	editor.data.tiles=[]
	editor.history.clear()
	editor.sync_controls()
	check(editor.palette_buttons[0].get_meta("kind")==1,"Player is first in the palette")
	var block_preview: Node2D=editor.palette_buttons[3].get_node("Preview").get_child(0)
	check(block_preview.material.shader.resource_path=="res://shaders/surface.gdshader","Palette blocks use the in-game animated holographic shader")
	check(get_nodes_in_group("blocks").is_empty(),"Editor previews do not participate in gameplay physics or welding groups")
	var view_size: Vector2=editor.get_viewport_rect().size
	check(editor.ui.size==view_size and editor.ui.get_node("Toolbar").size.x==view_size.x,"Editor toolbar and palette span the visible viewport")
	check(editor.width_input.max_value==floor((view_size.x-16)/16.0) and editor.height_input.max_value==floor((view_size.y-editor.TOP-editor.BOTTOM-16)/16.0),"Grid limits exclude the toolbar and palette")
	editor.toggle_play()
	check(not editor.playing and is_instance_valid(editor.popup),"Play requires a player spawn and explains how to fix the draft")
	editor.close_popup()
	paint(editor,2,1,Vector2i(3,3))
	paint(editor,3,1,Vector2i(3,3))
	check(editor.data.objects.size()==1,"Key placement cannot overlap an existing pushable block")
	# Previously authored overlapping layouts remain readable and erasable.
	editor.data.objects.append([3,56,56,1,"E3_3"])
	check(LevelEditorCodec.decode(LevelEditorCodec.encode(editor.data)).objects.size()==2,"Historical block/key overlaps remain readable")
	editor.erase=true
	editor.last_cell=Vector2i(-1,-1)
	editor.stroke_saved=false
	editor.paint_at(Vector2i(3,3))
	check(editor.data.objects.is_empty(),"Right click removes every object beneath the mouse")
	editor.undo()
	check(editor.data.objects.size()==2,"Undo restores a deleted block and key")
	paint(editor,1,0,Vector2i(1,1))
	paint(editor,1,0,Vector2i(2,2))
	var players := 0
	for item in editor.data.objects:
		if item[0]==1: players+=1
	check(players==1,"Placing the player again moves its single spawn")
	paint(editor,0,0,Vector2i(3,3))
	check(not editor.data.tiles.has([3,3]) and editor.data.objects.size()==3,"Walls cannot replace a key target or its matching block")
	editor.erase=true
	editor.last_cell=Vector2i(-1,-1)
	editor.paint_at(Vector2i(3,3))
	paint(editor,0,0,Vector2i(3,3))
	check(editor.data.tiles.has([3,3]) and editor.data.objects.size()==1,"Walls replace overlapping objects")
	editor.width_input.value=2
	check(editor.data.grid[0]==2 and editor.data.tiles.is_empty() and editor.data.objects.is_empty(),"Reducing dimensions crops objects outside the new bounds")
	editor.undo()
	check(editor.data.tiles.has([3,3]) and editor.data.objects.size()==1,"Undo restores a resized draft")
	editor.erase=false
	editor.select_tool(0,0)
	editor.last_cell=Vector2i(4,4)
	editor.stroke_saved=false
	editor.paint_at(Vector2i(9,4))
	check(editor.data.tiles.has([5,4]) and editor.data.tiles.has([8,4]),"Fast mouse drags paint intermediate tiles without gaps")
	paint(editor,2,0,Vector2i(5,5))
	paint(editor,2,0,Vector2i(6,5))
	paint(editor,2,0,Vector2i(6,6))
	paint(editor,2,0,Vector2i(7,7))
	paint(editor,2,1,Vector2i(7,6))
	var components := LevelEditorIcons.block_components(editor.data.objects)
	check(components.size()==3 and components[0].points.size()==3,"Only orthogonally connected blocks of the same color merge in the editor")
	var merged: Node2D
	for child in editor.board.content.get_children():
		if child.get_meta("block_cells",0)==3: merged=child
	check(is_instance_valid(merged) and merged.get_child_count()==4,"Merged blocks draw three surfaces with one shared outline and pivot")
	if merged:
		var outline: Node2D=merged.get_child(3)
		check(outline.paths.size()==1 and outline.pivot==Vector2(16,0),"L-shaped editor welds trace a closed contour and choose the game's central pivot")
	editor.data={"v":1,"grid":[30,18,16],"color":"7842a6","tiles":[],"objects":[[1,24,120]]}
	for x in 30: editor.data.tiles.append([x,8])
	for hue in 4:
		paint(editor,2,hue,Vector2i(3+hue*3,7))
		paint(editor,3,hue,Vector2i(4+hue*3,7))
	paint(editor,10,0,Vector2i(16,7))
	paint(editor,11,0,Vector2i(18,7))
	var encoded := LevelEditorCodec.encode(editor.data)
	var decoded := LevelEditorCodec.decode(encoded)
	check(not decoded.is_empty() and LevelEditorCodec.encode(decoded)==encoded,"All palette objects and color round-trip losslessly through a canonical compressed string")
	check(encoded.length()<JSON.stringify(editor.data).length()/2,"Packed/compressed level string is substantially smaller than JSON")
	check(LevelEditorCodec.decode("garbage").is_empty() and LevelEditorCodec.decode("CPE1:!!!!").is_empty(),"Malformed imports are rejected")
	var bad := Marshalls.base64_to_raw(encoded.substr(5))
	bad.encode_u16(2,513)
	check(LevelEditorCodec.decode(LevelEditorCodec.PREFIX+Marshalls.raw_to_base64(bad)).is_empty(),"Oversized compressed payloads are rejected before decompression")
	editor.background_color=Color.html(editor.data.color)
	editor.update_theme()
	editor.layout()
	editor.show_color_picker()
	for i in 3: await process_frame
	check(editor.popup.panel.get_global_rect().end.y<=view_size.y and editor.popup.panel.size.y<view_size.y,"Color picker and its Back button fit inside the viewport")
	editor.close_popup()
	editor.show_export()
	check(editor.popup.rows.get_child(0).text=="Copy this code somewhere safe","Export displays the requested code instruction without a character count")
	var style: StyleBoxFlat=editor.popup.panel.get_theme_stylebox("panel")
	check(style.bg_color==editor.background_color and style.border_width_left==1,"Popups use the current level color with a one-pixel outline")
	editor.popup._input(key(KEY_ESCAPE))
	check(not is_instance_valid(editor.popup),"Escape closes an editor popup safely")
	var empty_level := {"v":1,"grid":[1,1,16],"color":"000000","tiles":[],"objects":[]}
	check(LevelEditorCodec.decode(LevelEditorCodec.encode(empty_level))==DataVersion.stamp(empty_level),"An unfinished draft with no player can still be exported and imported")
	editor.show_import()
	check(editor.popup.rows.get_child(0).text=="Paste a level code","Import displays the requested code instruction")
	var text: TextEdit=editor.popup.rows.get_child(1)
	text.grab_focus()
	var typing := InputEventKey.new()
	typing.keycode=KEY_A
	typing.unicode=97
	typing.pressed=true
	Input.parse_input_event(typing)
	await process_frame
	check(text.text=="a","Import popup accepts keyboard text input")
	text.text="invalid"
	editor.popup.actions.get_child(1).pressed.emit()
	check(editor.popup.rows.get_child(2).text=="Invalid or damaged level string.","Invalid imports show an inline error and retain the draft")
	text.text=encoded
	editor.popup.actions.get_child(1).pressed.emit()
	check(not is_instance_valid(editor.popup) and editor.data.color=="7842a6","Import rebuilds the level and its theme")
	editor.data.objects=[[1,24,120]]
	editor.toggle_play()
	for i in 5: await physics_frame
	check(editor.playing and not is_instance_valid(editor.popup),"A level with no keys does not immediately declare victory")
	editor.stop_play()
	# One solvable key, initially under a block of the wrong color.
	editor.data.objects=[[1,24,120],[2,56,120,1,0.2,0.15],[3,56,120,0,"A"]]
	var original: Dictionary=editor.data.duplicate(true)
	editor._input(key(KEY_SPACE))
	for i in 8: await physics_frame
	check(editor.playing and editor.play_button.text=="Edit","Space enters play mode and mismatched blocks do not win")
	check(editor.objective.visible and editor.objective.text=="Complete the puzzle by filling all the squares." and editor.objective.position.y+editor.objective.size.y<=view_size.y-editor.BOTTOM,"Play mode shows the puzzle instruction at the bottom right above the palette")
	check(not is_instance_valid(editor.popup),"Unfilled keys do not trigger completion")
	editor._input(key(KEY_SPACE))
	await process_frame
	check(not editor.playing and editor.data==original,"Space returns to an unchanged editor draft")
	check(not editor.objective.visible,"Puzzle instruction is hidden while editing")
	editor.toggle_play()
	for i in 4: await physics_frame
	var block := get_first_node_in_group("blocks")
	block.block_color=0
	for i in 10: await process_frame
	check(not editor.playing and is_instance_valid(editor.popup),"Filling every key with its correct block returns to the editor")
	check(victories==1,"Beating an editor playtest plays victory exactly once")
	if is_instance_valid(editor.popup):
		check(editor.popup.rows.get_child(0).text=="Good job!\n\n You beat the level!","Completion uses the requested message")
	editor.close_popup()
	editor.toggle_play()
	check(editor.playing,"Exit can be used during a play test")
	# Verify restoration actually reads the file rather than relying on retained state.
	player.position=Vector2(-100,-100)
	var draft_code := LevelEditorCodec.encode(editor.data)
	session.exit_editor()
	for i in 6: await process_frame
	check(current_scene==game and game.is_inside_tree() and progress.enabled,"Exit resumes the main game and re-enables its autosave")
	check(paused and is_instance_valid(session.overlay) and session.overlay.rows.get_child(0) is CommunityBrowser,"Local editor Exit reopens level selection over the restored game")
	check(player.position==saved_position,"Exit loads the player position from the temporary save")
	check(not FileAccess.file_exists(session.TEMP_PATH),"Exit deletes the temporary save after a successful restore")
	check(get_nodes_in_group("player").size()==1,"Editor playtest objects are removed from gameplay groups")
	check(FileAccess.get_file_as_string(session.draft_path)==draft_code,"Exit saves the authored draft rather than playtest object positions")
	session.open_menu()
	check(session.overlay.actions.get_child(0).text=="Make Levels","Later visits skip the accepted spoiler warning")
	session.enter_editor()
	for i in 4: await process_frame
	editor=current_scene
	check(LevelEditorCodec.encode(editor.data)==draft_code and editor.background_color.to_html(false)=="7842a6","Reopening the editor restores all saved objects, dimensions, and level color")
	paint(editor,2,3,Vector2i(10,6))
	paint(editor,7,0,Vector2i(12,2))
	paint(editor,8,0,Vector2i(13,2))
	paint(editor,20,0,Vector2i(14,2))
	paint(editor,5,1,Vector2i(15,2))
	paint(editor,18,0,Vector2i(12,3))
	draft_code=LevelEditorCodec.encode(editor.data)
	check(not draft_code.is_empty(),"Drafts containing new palette objects can be saved on Exit")
	session.exit_editor()
	for i in 4: await process_frame
	check(current_scene==game,"Exit with Q platforms, one-way/pass through blocks, teleporters and lightning restores the game")
	check(FileAccess.get_file_as_string(session.draft_path)==draft_code,"Later exits replace the previous saved draft")
	session.close_menu()
	progress.enabled=false
	current_scene=null
	game.queue_free()
	await process_frame
	quit(failures)
