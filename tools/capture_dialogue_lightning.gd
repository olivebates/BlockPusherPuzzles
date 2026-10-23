extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	root.get_node("Progress").enabled=false
	var game: Node2D=load("res://tools/test_world.gd").new().level()
	root.add_child(game)
	current_scene=game
	var objects := game.get_node("Objects")
	var player: Node2D=get_first_node_in_group("player")
	player.position=Vector2(280,313)
	var npc: Node2D=load(LevelData.SCENES[15]).instantiate()
	npc.position=Vector2(328,313)
	objects.add_child(npc)
	npc.set_process(false)
	var emitter: Node2D=load(LevelData.SCENES[18]).instantiate()
	emitter.position=Vector2(200,248)
	emitter.max_length_tiles=12
	objects.add_child(emitter)
	var camera: Camera2D=game.get_node("Camera")
	camera.position=Vector2(300,280)
	camera.force_update_scroll()
	for i in 5: await process_frame
	var dialogue := root.get_node("Dialogue")
	dialogue.begin("",[[StoryLines.NPC,"Heh... Seriously? I've got a theory about that giant door."]])
	dialogue._process(0.2)
	dialogue.finish_line()
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/dialogue-lightning-preview.png")
	quit()
