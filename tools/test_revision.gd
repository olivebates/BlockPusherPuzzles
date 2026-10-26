extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	print(("PASS: " if condition else "FAIL: ")+message)
	if not condition: failures += 1
func frames(count: int) -> void:
	for i in count: await physics_frame
func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func run() -> void:
	create_timer(30,true).timeout.connect(func(): quit(99))
	var game: Node2D = load("res://tools/test_world.gd").new().level()
	root.add_child(game)
	current_scene = game
	await frames(10)
	check(not game.has_node("EditorShortcut") and not game.has_node("LevelEditor"),"Gameplay starts without level editor components")
	var player := get_first_node_in_group("player")
	var block := game.get_node("Objects/Block_0")
	var sphere := game.get_node("Objects/WhiteSphere")
	check(player.get_node("Visual").texture.resource_path=="res://assets/playerSprite.png","Supplied PNG player sprite imported")
	check(player.platform_floor_layers==0 and player.platform_on_leave==CharacterBody2D.PLATFORM_ON_LEAVE_DO_NOTHING,"Recall cannot transfer platform teleport velocity to player")
	var aligned := true
	for attempt in 4:
		block.global_position = block.home+Vector2(32,0)
		block.force_update_transform()
		await frames(2)
		player.global_position = block.home+Vector2(2,0)
		player.velocity = Vector2.ZERO
		player.force_update_transform()
		Input.action_press("reset_block")
		await frames(1)
		Input.action_release("reset_block")
		await frames(12)
		if absf(block.position.x-block.home.x)>0.1 or absf(block.position.y-block.home.y)>0.2: aligned = false
	check(aligned,"Occupied-spawn recall stays on grid across repeated live physics resets")
	player.global_position = block.home+Vector2(0,-15.1)
	player.velocity = Vector2.ZERO
	await frames(3)
	var top_y: float = player.position.y
	Input.action_press("reset_block")
	await frames(1)
	Input.action_release("reset_block")
	var apex := top_y
	for i in 15:
		await frames(1)
		apex = minf(apex,player.position.y)
	check(apex>=top_y-0.5,"Recalling block beneath standing player never launches player")
	player.global_position = sphere.home+Vector2(0,-15.1)
	player.velocity = Vector2.ZERO
	player.force_update_transform()
	Input.action_press("reset_block")
	await frames(1)
	Input.action_release("reset_block")
	var sphere_top: float = sphere.home.y-15.1
	apex = player.position.y
	for i in 15:
		await frames(1)
		apex = minf(apex,player.position.y)
	check(apex>=sphere_top-0.5 and sphere.position.distance_to(sphere.home)<0.2,"Recalling sphere beneath standing player never launches player")
	check(game.has_node("AudioSettings/AudioSettingsButton"),"Gear button available in top-right game UI")
	check(AudioServer.get_bus_index("Music")>=0 and AudioServer.get_bus_index("SFX")>=0,"Separate music and effects buses exist")
	game.get_node("AudioSettings").menu.popup_centered()
	check(paused,"Audio menu pauses active gameplay")
	game.get_node("AudioSettings").menu.hide()
	check(not paused,"Closing audio menu restores prior play state")
	var juice := root.get_node("Juice")
	var old_music: float = juice.volumes.Music
	var old_sfx: float = juice.volumes.SFX
	juice.set_volume("SFX",0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")),"SFX slider can completely mute effects")
	juice.set_volume("Music",0.35)
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))),0.35),"Music volume is independently adjustable")
	juice.set_volume("SFX",old_sfx)
	juice.set_volume("Music",old_music)
	key(KEY_SHIFT,true)
	key(KEY_Z,true)
	key(KEY_P,true)
	await frames(5)
	key(KEY_P,false)
	key(KEY_Z,false)
	key(KEY_SHIFT,false)
	check(current_scene==game and not paused,"Shift+Z+P keeps gameplay running in the current scene")
	check(LevelData.apply(game,load("res://tools/test_fixture.gd").new().board()),"Hand-authored board loads for gameplay")
	await frames(8)
	var guide := game.get_node("PlatformGuide")
	get_first_node_in_group("player").position=get_first_node_in_group("pads").position+Vector2(0,-16)
	await frames(1)
	check(guide.key_links().size()==1 and guide.key_canvas.z_index+guide.z_index>0,"Nearby ID-linked key/door guides are drawn above walls")
	var key_tile := get_first_node_in_group("pads")
	var gate := get_first_node_in_group("doors")
	check(key_tile.id==gate.id,"Key and door expose matching IDs")
	var actor := get_first_node_in_group("blocks")
	actor.position=key_tile.position
	await frames(5)
	check(gate.opened,"Matching ID and filled key open the door")
	key_tile.id="different"
	await frames(5)
	check(not gate.opened and guide.key_links().is_empty(),"Different IDs disconnect both logic and guide line")
	key_tile.id=gate.id
	await frames(5)
	check(gate.opened,"Restoring matching IDs reconnects door")
	player=get_first_node_in_group("player")
	Input.action_press("left")
	await frames(3)
	Input.action_release("left")
	check(player.get_node("Visual").flip_h,"Sprite flips while moving left")
	Input.action_press("right")
	await frames(3)
	Input.action_release("right")
	check(not player.get_node("Visual").flip_h,"Sprite faces right while moving right")
	check(game.get_node("GameHUD").get_child_count()==0,"Gameplay HUD has no text")
	paused = false
	await frames(30)
	current_scene = null
	game.queue_free()
	await process_frame
	print("REVISION CHECKS: ","PASS" if failures==0 else "FAIL (%d)" % failures)
	quit(failures)
