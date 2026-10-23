extends SceneTree
func _initialize() -> void:
	for kind in range(8 if "--new" in OS.get_cmdline_user_args() else 1,LevelData.SCENES.size()):
		var node: Node = load(LevelData.SCENES[kind]).instantiate()
		EditorArt.attach(node,kind)
		var packed := PackedScene.new()
		packed.pack(node)
		ResourceSaver.save(packed,LevelData.SCENES[kind])
		node.free()
	print("Installed editor-only object sprites.")
	quit()
