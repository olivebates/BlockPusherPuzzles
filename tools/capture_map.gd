extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	root.get_node("Progress").enabled=false
	var level: Node2D=load("res://scenes/main.tscn").instantiate()
	root.add_child(level)
	current_scene=level
	for group in ["story_npcs","dialogue_triggers"]:
		for node in get_nodes_in_group(group): node.set_process(false)
	for i in 5: await process_frame
	root.get_node("Dialogue").stop()
	for platform in get_nodes_in_group("recall_platforms"): platform.activated=true
	level.get_node("TeleportMap").open_map()
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/map-preview.png")
	quit()
