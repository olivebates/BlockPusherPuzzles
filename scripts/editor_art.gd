class_name EditorArt
extends RefCounted
static func attach(node: Node, kind: int) -> void:
	if node.has_node("EditorIcon"): return
	var sprite := Sprite2D.new()
	sprite.name = "EditorIcon"
	if kind == 3: sprite.scale = Vector2.ONE*0.75
	sprite.texture = load("res://assets/editor/"+LevelData.ICONS[kind]+".svg")
	sprite.set_script(load("res://scripts/editor_icon.gd"))
	node.add_child(sprite)
	sprite.owner = node
