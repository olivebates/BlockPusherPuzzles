extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.get_node("Progress").enabled=false
	var game: Node2D=load("res://tools/test_world.gd").new().level()
	root.add_child(game)
	current_scene=game
	var rotator: Node2D=load(LevelData.SCENES[10]).instantiate()
	rotator.position=Vector2(280,280)
	game.get_node("Objects").add_child(rotator)
	var camera := game.get_node("Camera") as Camera2D
	camera.set_process(false)
	camera.zoom=Vector2.ONE
	camera.position=Vector2(480,270)
	for i in 8: await process_frame
	for node in get_nodes_in_group("player")+get_nodes_in_group("blocks")+get_nodes_in_group("spheres"): node.set_physics_process(false)
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/hue-before.png")
	game.change_theme(Color.from_hsv(0.5,1,1))
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/hue-after.png")
	game.hue_exempt_view.get_texture().get_image().save_png("res://.godot/hue-mask.png")
	quit()
