extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ")+message)
	if not value: failures+=1
func run() -> void:
	var progress := root.get_node("Progress")
	progress.enabled=false
	var game: Node2D=load("res://tools/test_world.gd").new().level()
	root.add_child(game)
	current_scene=game
	progress.level=game
	for i in 5: await physics_frame
	var player: CharacterBody2D=get_first_node_in_group("player")
	player.set_physics_process(false)
	var objects := game.get_node("Objects")
	var door: StaticBody2D=load(LevelData.SCENES[12]).instantiate()
	door.position=Vector2(400,312)
	objects.add_child(door)
	door.set_physics_process(false)
	var indicator: Node2D=load(LevelData.SCENES[14]).instantiate()
	indicator.position=Vector2(400,240)
	indicator.lit=true
	objects.add_child(indicator)
	player.position=Vector2(370,313)
	door._physics_process(1.0/60)
	check(door.opened and not door.passed_through,"Opening the large door leaves it awaiting passage")
	player.position.x=400
	door._physics_process(1.0/60)
	player.position.x=370
	door._physics_process(1.0/60)
	check(not door.passed_through,"Entering and backing out does not count as passing through")
	player.position.x=430
	door._physics_process(1.0/60)
	check(not door.passed_through,"Jumping directly across without entering does not count as passage")
	player.position.x=400
	player.recall_freeze_frames=2
	door._physics_process(1.0/60)
	player.position.x=370
	player.recall_freeze_frames=0
	door._physics_process(1.0/60)
	check(not door.passed_through,"Teleport arrival inside a doorway does not count as passage")
	player.position.x=400
	door._physics_process(1.0/60)
	player.position.x=430
	door._physics_process(1.0/60)
	check(door.passed_through,"Crossing the open doorway from one side to the other records passage")
	var saved: Dictionary=progress.snapshot()
	door.passed_through=false
	check(progress.apply_state(saved) and door.passed_through,"Door passage survives progress save and restore")
	saved.erase("passed_doors")
	check(progress.apply_state(saved) and not door.passed_through,"Older saves without passage data remain compatible")
	var map := game.get_node("TeleportMap")
	check(map.open_map() and map.marker_layer.layer>game.get_node("HueShift").layer,"Map markers draw above the hue effect to preserve orange, red and yellow")
	map.close_map()
	check(not map.marker_layer.visible,"Closing the map hides its marker overlay")
	current_scene=null
	game.queue_free()
	await process_frame
	quit(failures)
