extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var editor_preview := "--build" in OS.get_cmdline_user_args()
	var scene: Node2D = load("res://scenes/level_editor.tscn" if editor_preview else "res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in 30: await process_frame
	if editor_preview:
		for i in 5: await process_frame
	if "--audio" in OS.get_cmdline_user_args(): scene.get_node("AudioSettings").menu.popup_centered()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://editor-preview.png" if editor_preview else "res://preview.png")
	paused = false
	quit()
