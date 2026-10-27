extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ")+message)
	if not value: failures+=1
func run() -> void:
	root.get_node("Progress").enabled=false
	root.get_node("Progress").map_hint_stage=2
	var editor: Node2D=load("res://scenes/level_editor.tscn").instantiate()
	editor.draft_path="res://.godot/custom-object-draft.cpe"
	editor.fit_grid_to_view=false
	editor.initial_level_code=LevelEditorCodec.encode({"v":DataVersion.current(),"grid":[12,8,16],"color":"005155","tiles":[],"objects":[]})
	root.add_child(editor)
	current_scene=editor
	var objects := [[1,136,104],[2,40,104,0,0.2,0.15],[3,152,40,0,"E9_2"],[7,88,104],[8,56,104],[20,40,40],[20,56,40],[5,88,40,1],[5,104,40,2],[5,120,40,3],[18,40,72,0,128,"8adfffff",true]]
	editor.data.objects=objects.duplicate(true)
	for x in 12: editor.data.tiles.append([x,7])
	editor.data.tiles.append_array([[0,4],[11,4],[2,1]])
	editor.sync_controls()
	check(editor.palette_buttons[2].get_meta("kind")==7,"Q platform follows floor tiles in the palette")
	check(editor.palette_buttons.any(func(button): return button.tooltip_text=="Pass through block"),"Editor names the pass through block")
	check(not editor.pass_through_edges(Vector2(40,40)).has(Vector2.RIGHT) and not editor.pass_through_edges(Vector2(40,40)).has(Vector2.UP),"Pass through editor tiling hides edges against neighbors and solid walls")
	var code: String=LevelEditorCodec.encode(editor.data)
	var decoded := LevelEditorCodec.decode(code)
	check(not code.is_empty() and decoded.objects.size()==objects.size(),"All new editor objects round-trip through packed level codes")
	check(LevelEditorCodec.encode(decoded)==code,"Extended packed codes round-trip canonically")
	var legacy_bytes := PackedByteArray([3,0,2,0,1,0,0,81,85,255,2,6])
	var legacy_level := LevelEditorCodec.decode("CPE3:"+Marshalls.raw_to_base64(legacy_bytes))
	check(legacy_level.v==3,"Current packed fixture uses the shared current layout")
	legacy_bytes.encode_u16(0,2)
	legacy_level=LevelEditorCodec.decode("CPE3:"+Marshalls.raw_to_base64(legacy_bytes))
	check(legacy_level.v==2 and legacy_level.objects[1][3]==3,"Frozen version-2 packed block meanings remain unchanged")
	legacy_bytes[-1]=9
	check(LevelEditorCodec.decode("CPE3:"+Marshalls.raw_to_base64(legacy_bytes)).is_empty(),"Version-2 readers never reinterpret new cell values")
	check(editor.save_draft() and LevelEditorCodec.decode(FileAccess.get_file_as_string(editor.draft_path)).objects.size()==objects.size(),"Saving a draft containing every new object succeeds for editor Exit")
	editor.data=decoded
	var community := CommunityCodec.level(code,"Custom objects","Tests","")
	editor.start_play()
	for i in 5: await physics_frame
	var player: CharacterBody2D=get_first_node_in_group("player")
	player.set_physics_process(false)
	check(player.map_hint().is_empty(),"Campaign Tab hint is hidden in custom levels and editor tests")
	var platform := get_first_node_in_group("recall_platforms")
	var guide: Node2D=editor.world.get_node("PlatformGuide")
	player.global_position=Vector2(88,50)
	platform._process(0.1)
	check(not platform.activated,"Custom Q platform stays inactive while player is high above it")
	player.global_position=platform.arrival_position()
	platform._process(0.1)
	player.global_position=Vector2(144,100)
	guide._process(0.1)
	check(platform.activated and platform.nearest and guide.nearest==platform,"Stepping on a custom Q platform activates it and selects its Q prompt")
	var q := InputEventKey.new()
	q.physical_keycode=KEY_Q
	q.keycode=KEY_Q
	q.pressed=true
	Input.parse_input_event(q)
	Input.flush_buffered_events()
	await process_frame
	await process_frame
	q.pressed=false
	Input.parse_input_event(q)
	Input.flush_buffered_events()
	check(player.global_position.is_equal_approx(platform.arrival_position()),"Pressing Q teleports to the closest active custom platform")
	var block: CharacterBody2D=get_first_node_in_group("blocks")
	block.set_physics_process(false)
	block.global_position=Vector2(40,104)
	block.sync_members()
	check(SupportCarry.can_move(block,Vector2(16,0)),"Blocks can enter one-way blocks horizontally")
	SupportCarry.move(block,Vector2(16,0))
	block._physics_process(1.0/60)
	check(block.global_position.is_equal_approx(Vector2(56,104)),"Side-entry overlap does not lift or displace a resting block")
	check(SupportCarry.can_move(block,Vector2(-16,0)),"Blocks can leave a one-way block through the opposite side")
	block.global_position=Vector2(56,80)
	block.force_update_transform()
	check(BlockFall.floor_distance(block,20)<10,"One-way blocks still support boxes falling onto their top")
	var track := ReplayTrack.new()
	track.bind(editor.world)
	track.capture(0)
	track.capture(1<<13)
	var replay := track.encode(community,"Tests","")
	check(not ReplayTrack.decode(replay).is_empty(),"Replays with static custom objects and Q input remain readable")
	FileAccess.open("res://.godot/custom-v3-fixture.json",FileAccess.WRITE).store_string(JSON.stringify({"level":community,"replay":replay}))
	editor.stop_play()
	current_scene=null
	editor.queue_free()
	await process_frame
	quit(failures)
