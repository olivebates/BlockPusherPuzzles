@tool
extends Sprite2D
## Pure editor identification art. The runtime uses the object's own drawing.
func _enter_tree() -> void:
	visible = Engine.is_editor_hint()
	z_index = 20
