extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ")+message)
	if not value: failures+=1
func frames(count: int) -> void:
	for i in count: await physics_frame
func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func run() -> void:
	create_timer(25,true).timeout.connect(func(): quit(99))
	var progress := root.get_node("Progress")
	var dialogue := root.get_node("Dialogue")
	var juice := root.get_node("Juice")
	var game: Node2D=load("res://tools/test_world.gd").new().level()
	root.add_child(game)
	current_scene=game
	await frames(15)
	var player: CharacterBody2D=get_first_node_in_group("player")
	player.set_physics_process(false)
	var camera := game.get_node("Camera")
	camera.trauma=0
	juice.reduced_motion=false
	juice.impact(1,Vector2(5000,312))
	check(camera.trauma==0,"Off-screen distant block events cannot shake the camera")
	juice.impact(0.5,player.position)
	check(camera.trauma>0,"Nearby visible impacts still give brief feedback")
	for i in 12: juice.impact(1,player.position)
	check(camera.trauma<=0.75,"Repeated impacts cannot accumulate unlimited camera shake")
	var trigger: Area2D=load(LevelData.SCENES[9]).instantiate()
	trigger.position=player.position
	trigger.hex_color="#ffffff"
	trigger.background_color=Color("243a40")
	trigger.tile_color=Color("13252a")
	game.get_node("Objects").add_child(trigger)
	dialogue.begin("",StoryLines.OPENING)
	await create_timer(0.45,true).timeout
	check(paused and game.background_color.is_equal_approx(trigger.background_color) and game.tile_color.is_equal_approx(trigger.tile_color),"A touched color changer finishes its color transition during dialogue")
	check(camera.trauma==0 and camera.offset==Vector2.ZERO and camera.zoom==Vector2(2,2),"Dialogue clears camera shake and keeps a stable zoom")
	check(game.get_node("Walls").material.get_shader_parameter("tile_color").is_equal_approx(trigger.tile_color),"Paused dialogue still updates the visible tile shader color")
	dialogue.stop()
	await frames(20)
	check(camera.trauma==0 and camera.offset==Vector2.ZERO,"Camera returns to a completely still idle state")
	var walls: TileMapLayer=game.get_node("Walls")
	walls.set_cell(Vector2i(55,40),0,Vector2i.ZERO)
	game.remember_level()
	check(game.get_meta("fall_limit")>=720,"Expanded levels derive their fall boundary from the actual map height")
	progress.save_root="user://tests/instant_delete"
	progress.delete_progress(false)
	progress.level=game
	progress.dialogues={"opening":true,"test":true}
	check(progress.save_now(),"Instant-delete test creates isolated saved progress")
	progress.write_backup("timed",progress.snapshot())
	dialogue.begin("",StoryLines.OPENING)
	progress.enabled=false
	var gentle: bool=juice.reduced_motion
	key(KEY_SHIFT,true)
	key(KEY_Z,true)
	key(KEY_M,true)
	for i in 6: await process_frame
	key(KEY_M,false)
	key(KEY_Z,false)
	key(KEY_SHIFT,false)
	check(not FileAccess.file_exists(progress.save_root+"/current.cps") and progress.list_backups().is_empty(),"Shift+Z+M immediately deletes progress and backups without confirmation")
	check(not dialogue.active and current_scene.scene_file_path=="res://scenes/main.tscn","The shortcut works during dialogue and restarts the game")
	check(juice.reduced_motion==gentle,"The delete shortcut does not also toggle gentle effects")
	var level := current_scene
	current_scene=null
	level.queue_free()
	await process_frame
	quit(failures)
