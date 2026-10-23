extends SceneTree
func _initialize() -> void:
	var root: Node = load("res://scenes/main.tscn").instantiate()
	load("res://tools/demo_objects.gd").new().add_examples(root)
	for child in root.get_node("Objects").get_children():
		if child is StaticBody2D and child.get_script() == load("res://scripts/door.gd"):
			child.get_node("CollisionShape2D").shape = RectangleShape2D.new()
			child.get_node("CollisionShape2D").shape.size = Vector2(16,16)
			child.get_node("CollisionShape2D").position = Vector2.ZERO
	var scene := PackedScene.new()
	scene.pack(root)
	ResourceSaver.save(scene,"res://scenes/main.tscn")
	root.free()
	print("Updated existing level with new example objects.")
	quit()
