extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	root.get_node("Progress").enabled=false
	var game: Node2D=load("res://tools/test_world.gd").new().level()
	for child in game.get_node("Objects").get_children(): child.free()
	root.add_child(game)
	current_scene=game
	var objects := game.get_node("Objects")
	var player: Node2D=load(LevelData.SCENES[1]).instantiate()
	player.position=Vector2(248,313)
	objects.add_child(player)
	var walls: TileMapLayer=game.get_node("Walls")
	for y in range(12,20):
		walls.set_cell(Vector2i(12,y),0,Vector2i.ZERO)
		walls.set_cell(Vector2i(32,y),0,Vector2i.ZERO)
	for point in [Vector2(280,280),Vector2(296,280),Vector2(312,280)]:
		var elevator: Node2D=load(LevelData.SCENES[19]).instantiate()
		elevator.position=point
		objects.add_child(elevator)
	for point in [Vector2(392,312),Vector2(408,312),Vector2(408,296)]:
		var phase: Node2D=load(LevelData.SCENES[20]).instantiate()
		phase.position=point
		objects.add_child(phase)
	walls.set_cell(Vector2i(26,19),0,Vector2i.ZERO)
	var emitter: Node2D=load(LevelData.SCENES[18]).instantiate()
	emitter.position=Vector2(280,232)
	objects.add_child(emitter)
	var box: Node2D=load(LevelData.SCENES[2]).instantiate()
	box.position=Vector2(392,280)
	objects.add_child(box)
	var camera: Camera2D=game.get_node("Camera")
	camera.set_process(false)
	camera.position=Vector2(360,252)
	camera.force_update_scroll()
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/safety-objects-preview.png")
	quit()
