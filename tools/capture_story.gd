extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	root.get_node("Progress").enabled=false
	var scene: Node2D=load("res://scenes/story_demo.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	for i in 5: await process_frame
	var player: Node2D=get_first_node_in_group("player")
	player.position=Vector2(344,313)
	var camera: Camera2D=scene.get_node("Camera")
	camera.position=Vector2(344,280)
	camera.force_update_scroll()
	root.get_node("Dialogue").begin("",StoryLines.ENCOUNTER)
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/story-preview.png")
	quit()
