extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ")+message)
	if not value: failures += 1
func frames(count: int) -> void:
	for i in count: await physics_frame
func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func obstacle(parent: Node, point: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size=Vector2(16,16)
	collider.shape=shape
	body.add_child(collider)
	body.position=point
	parent.add_child(body)
	return body
func run() -> void:
	create_timer(25,true).timeout.connect(func(): quit(99))
	var game: Node2D=load("res://tools/test_world.gd").new().level()
	root.add_child(game)
	current_scene=game
	await frames(10)
	var player: CharacterBody2D=get_first_node_in_group("player")
	var controls:=root.get_node("InputBindings")
	check(game.background_color.is_equal_approx(Color(0.6,0.6,0.6,1)),"Background defaults to 40 percent darkness")
	check(game.tile_color.is_equal_approx(Color(0.2,0.2,0.2,1)),"Wall tiles default to 80 percent darkness")
	var base: float=player.position.y
	key(KEY_UP,true)
	await frames(3)
	key(KEY_UP,false)
	var apex: float=player.position.y
	for i in 45:
		await frames(1)
		apex=minf(apex,player.position.y)
	check(absf(base-apex-40)<0.8,"Up tap jumps exactly 2.5 tiles")
	key(KEY_SPACE,true)
	apex=player.position.y
	for i in 45:
		await frames(1)
		apex=minf(apex,player.position.y)
	key(KEY_SPACE,false)
	check(absf(base-apex-40)<0.8,"Held Space has the same jump height as Up")
	await frames(4)
	player.set_physics_process(false)
	player.position=Vector2(-100,-100)
	await frames(65)
	check(game.get_node("Camera").position.x<0 and game.get_node("Camera").position.y<0,"Camera follows beyond the room origin")
	var guide:=game.get_node("PlatformGuide")
	check(guide.nearest==null,"Unvisited platforms are not selectable")
	guide.nearest=game.get_node("Objects/RecallPlatformB")
	check(not guide.recall(),"Unvisited platform rejects teleport")
	var platform: StaticBody2D=load(LevelData.SCENES[7]).instantiate()
	platform.position=Vector2(728,200)
	game.get_node("Objects").add_child(platform)
	await frames(3)
	check(absf(platform.position.y-318)<0.1,"Floating platform snaps down flush with nearest floor")
	player.position=platform.arrival_position()
	game.get_node("Camera").position=platform.position
	game.get_node("Camera").force_update_scroll()
	await frames(4)
	check(platform.activated and guide.nearest==platform,"Touching a platform permanently activates it for this run")
	check(controls.prompt("recall_player")=="Q","Active platform prompt uses Q by default")
	player.position=Vector2(700,300)
	await frames(3)
	check(guide.recall() and player.position.distance_to(platform.arrival_position())<0.1,"Activated platform can be recalled to after leaving it")
	var block: CharacterBody2D=game.get_node("Objects/Block_0")
	block.position.x+=32
	player.position=block.home
	player.update_recall_target()
	check(not player.show_recall_prompt,"Unblocked moved box does not show an R prompt at its spawn")
	var sphere: CharacterBody2D=game.get_node("Objects/WhiteSphere")
	sphere.position.x+=32
	player.position=sphere.home
	player.update_recall_target()
	check(player.show_recall_prompt and player.recall_prompt_color==Color.WHITE,"Circle spawn shows white recall prompt")
	var test_block: CharacterBody2D=load(LevelData.SCENES[2]).instantiate()
	test_block.position=Vector2(312,312)
	game.get_node("Objects").add_child(test_block)
	await frames(3)
	test_block.position=Vector2(344,312)
	var wall:=obstacle(game,Vector2(360,312))
	player.position=Vector2(330,313)
	await frames(3)
	player.update_recall_target()
	check(test_block.side_blocked() and player.show_recall_prompt,"Touching a side-blocked box shows recall prompt away from spawn")
	wall.queue_free()
	await frames(3)
	player.update_recall_target()
	check(not test_block.side_blocked() and not player.show_recall_prompt,"An unblocked displaced box hides its recall prompt when touched")
	var one_way: StaticBody2D=load(LevelData.SCENES[8]).instantiate()
	one_way.position=Vector2(904,264)
	game.get_node("Objects").add_child(one_way)
	player.position=Vector2(904,288)
	player.recall_freeze_frames=0
	player.velocity=Vector2(0,-240)
	player.set_physics_process(true)
	apex=player.position.y
	for i in 70:
		await frames(1)
		apex=minf(apex,player.position.y)
	check(apex<249,"Player passes upward through one-way block")
	var player_collider: CollisionShape2D=player.get_node("CollisionShape2D")
	var feet_offset := player_collider.position.y+player_collider.shape.get_rect().end.y
	check(player.is_on_floor() and absf(player.position.y-(one_way.position.y-8-feet_offset))<0.3,"Player lands on one-way block from above")
	var trigger: Area2D=load(LevelData.SCENES[9]).instantiate()
	trigger.hex_color="#9955ff"
	trigger.color=Color.GREEN
	check(trigger.selected_color().is_equal_approx(Color("9955ff")),"Hex color takes precedence over picker")
	trigger.hex_color=""
	check(trigger.selected_color()==Color.GREEN,"Empty hex field uses editor color picker")
	trigger.hex_color="#9955ff"
	trigger.position=player.position
	game.get_node("Objects").add_child(trigger)
	await frames(30)
	check(absf(game.background_color.h-Color("9955ff").h)<0.01 and game.background_color.s>0,"Touching color trigger changes background hue")
	check(absf(game.tile_color.h-Color("9955ff").h)<0.01 and game.tile_color.s>0,"Color trigger changes tile hue while keeping tiles dark")
	var data:=LevelData.capture(game)
	var decoded:=LevelData.decode(LevelData.encode(data))
	var kinds:=[]
	for item in decoded.objects: kinds.append(int(item[0]))
	check(kinds.has(8) and kinds.has(9),"New objects survive compressed save/load")
	var settings:=game.get_node("AudioSettings")
	check(settings.binding_buttons.size()==9 and settings.binding_buttons.jump.size()==3,"Settings provide three binding slots for every gameplay action including Talk and Map")
	settings.menu.popup_centered()
	settings.binding_buttons.reset_block[1].pressed.emit()
	var captured:=InputEventKey.new()
	captured.keycode=KEY_X
	captured.physical_keycode=KEY_X
	captured.pressed=true
	settings.capture_binding(captured)
	check(InputMap.action_get_events("reset_block").size()==2 and settings.capture_action.is_empty(),"Settings button captures a new key binding")
	settings.binding_buttons.reset_block[1].pressed.emit()
	captured.keycode=KEY_DELETE
	captured.physical_keycode=KEY_DELETE
	settings.capture_binding(captured)
	check(InputMap.action_get_events("reset_block").size()==1,"Delete clears a keybind slot")
	settings.menu.hide()
	var original:=InputMap.action_get_events("recall_player")
	controls.set_slot("recall_player",0,controls.key_event(KEY_E))
	controls.set_slot("recall_player",1,controls.key_event(KEY_T))
	controls.set_slot("recall_player",2,controls.key_event(KEY_Y))
	controls.set_slot("recall_player",3,controls.key_event(KEY_U))
	check(InputMap.action_get_events("recall_player").size()==3 and controls.prompt("recall_player")=="E","Bindings cap at three and prompts update to remapped key")
	controls.load_bindings()
	check(InputMap.action_get_events("recall_player").size()==3 and controls.prompt("recall_player")=="E","Saved keybinds reload from settings file")
	controls.install("recall_player",original)
	controls.save_bindings()
	await frames(30)
	current_scene=null
	game.queue_free()
	await process_frame
	print("NEW CONTROLS: ","PASS" if failures==0 else "FAIL (%d)" % failures)
	quit(failures)
