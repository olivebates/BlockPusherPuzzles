extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ")+message)
	if not value: failures+=1
func frames(count: int) -> void:
	for i in count: await physics_frame
func run() -> void:
	create_timer(25,true).timeout.connect(func(): quit(99))
	var game: Node2D=load("res://tools/test_world.gd").new().level()
	for child in game.get_node("Objects").get_children(): child.free()
	var objects := game.get_node("Objects")
	var player: CharacterBody2D=load(LevelData.SCENES[1]).instantiate()
	player.position=Vector2(56,313)
	objects.add_child(player)
	root.add_child(game)
	current_scene=game
	await frames(12)
	check(player.safety.ground_history.size()==1 and player.safety.ground_history[0].distance_to(Vector2(56,320))<0.2,"Ground history records the centered tile under the player's feet")
	player.set_physics_process(false)
	for x in 105: player.safety.remember(Vector2(x*16+8,320))
	check(player.safety.ground_history.size()==100 and player.safety.ground_history[0].x==88,"Ground history retains only the last 100 distinct support tiles")
	player.safety.restore_history([[56,320],[72,320],[88,320]])
	var obstruction: CharacterBody2D=load(LevelData.SCENES[2]).instantiate()
	obstruction.position=Vector2(88,312)
	objects.add_child(obstruction)
	var walls: TileMapLayer=game.get_node("Walls")
	walls.erase_cell(Vector2i(4,20))
	await frames(4)
	player.position=Vector2(216,240)
	check(player.safety.return_to_ground() and player.position.distance_to(Vector2(56,313.95))<0.2,"Lightning recall skips occupied and missing recent floors and centers the player on an older safe tile")
	check(player.velocity==Vector2.ZERO and player.safety.ground_history.size()==1,"Safe recall clears velocity and discards invalid newer history")
	player.safety.lightning_grace=0
	var emitter: Node2D=load(LevelData.SCENES[18]).instantiate()
	emitter.position=Vector2(200,240)
	emitter.max_length_tiles=4
	objects.add_child(emitter)
	player.position=Vector2(216,236)
	player.force_update_transform()
	await frames(3)
	check(player.position.distance_to(Vector2(56,313.95))<0.2,"Touching an enabled lightning beam triggers the safe return automatically")
	emitter.enabled=false
	player.position=Vector2(88,312)
	player.force_update_transform()
	check(player.safety.recover_embedded() and PuzzlePhysics.clear_at(player,player.position,[player.get_rid()],5),"A player embedded in a box moves to a clear nearby tile")
	player.position=Vector2(168,328)
	player.force_update_transform()
	check(player.safety.recover_embedded() and player.position.y<320,"A player embedded in solid tiles is lifted to the nearest clear grid cell")
	player.noclip=true
	player.position=Vector2(168,328)
	check(not player.safety.recover_embedded() and player.position==Vector2(168,328),"Noclip mode is exempt from automatic unsticking")
	player.noclip=false
	player.position=Vector2(56,313.95)
	player.force_update_transform()
	var progress := root.get_node("Progress")
	progress.level=game
	var data: Dictionary=progress.snapshot()
	player.safety.ground_history.clear()
	check(progress.apply_state(data) and player.safety.ground_history.size()==1,"Ground history survives saved-progress restore")
	current_scene=null
	game.queue_free()
	await process_frame
	quit(failures)
