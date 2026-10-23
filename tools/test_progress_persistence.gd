extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var progress := root.get_node("Progress")
	progress.save_root="user://tests/progress_process"
	var game: Node2D=load("res://tools/test_world.gd").new().level()
	root.add_child(game)
	current_scene=game
	for i in 8: await physics_frame
	progress.level=game
	var player: CharacterBody2D=get_first_node_in_group("player")
	player.set_physics_process(false)
	var block := game.get_node("Objects/Block_0")
	var sphere := game.get_node("Objects/WhiteSphere")
	var weld := game.get_node("Objects/WeldedLilac0")
	var passed := false
	if "--write" in OS.get_cmdline_user_args():
		player.position=Vector2(680,280)
		block.position=Vector2(136,312)
		sphere.position=Vector2(432,240)
		weld.members[1].weld_offset=Vector2(0,-16)
		weld.rebuild_weld_shapes()
		weld.sync_members()
		progress.dialogues={"opening":true,"test_trigger":true}
		passed=progress.save_now()
	else:
		var data: Dictionary=progress.read_file(progress.save_root+"/current.cps")
		passed=progress.apply_state(data)
		passed=passed and player.position==Vector2(680,280) and block.position==Vector2(136,312) and sphere.position==Vector2(432,240)
		passed=passed and weld.members[1].weld_offset==Vector2(0,-16) and progress.dialogues.has("test_trigger")
	print(("PASS: " if passed else "FAIL: ")+"Progress persists across independent game processes")
	progress.enabled=false
	current_scene=null
	game.queue_free()
	await process_frame
	quit(0 if passed else 1)
