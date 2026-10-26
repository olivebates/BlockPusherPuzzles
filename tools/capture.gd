extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var scene: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 30: await process_frame
	if "--audio" in OS.get_cmdline_user_args(): scene.get_node("AudioSettings").menu.popup_centered()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://preview.png")
	paused = false
	quit()
