extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ")+message)
	if not value: failures+=1
func run() -> void:
	create_timer(20,true).timeout.connect(func(): quit(99))
	var progress := root.get_node("Progress")
	progress.save_root="res://.godot/main-autosave-test"
	var uid := ResourceLoader.get_resource_uid("res://scenes/main.tscn")
	ProjectSettings.set_setting("application/run/main_scene",ResourceUID.id_to_text(uid))
	var game: Node2D=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	var player: CharacterBody2D=get_first_node_in_group("player")
	player.set_physics_process(false)
	for i in 12: await process_frame
	check(progress.level==game and not progress.restoring,"A main scene configured by UID automatically binds progress")
	root.get_node("Dialogue").stop()
	if "--read" in OS.get_cmdline_user_args():
		check(player.position==Vector2(-100,-130),"A new game process automatically restores the last autosave")
		progress.enabled=false
		current_scene=null
		game.queue_free()
		await process_frame
		quit(failures)
		return
	player.position=Vector2(-100,-130)
	# Step the actual autosave timer, without manually binding the level.
	progress._process(5.1)
	var saved: Dictionary=progress.read_file(progress.save_root+"/current.cps")
	check(not saved.is_empty() and saved.player==[-100.0,-130.0],"The five-second autosave writes the current player position in the authored main scene")
	player.position=Vector2(56,313)
	check(progress.apply_state(saved) and player.position==Vector2(-100,-130),"The authored main scene restores its autosave, including JSON elevator directions")
	if not saved.is_empty():
		var invalid := saved.duplicate(true)
		invalid.elevators[0].direction=0.5
		check(not progress.valid(invalid),"Invalid elevator directions are still rejected")
	progress.enabled=false
	current_scene=null
	game.queue_free()
	await process_frame
	quit(failures)
