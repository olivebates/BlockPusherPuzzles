extends ColorRect
func _ready() -> void:
	add_to_group("post_fx")
func set_impact(value: float) -> void:
	material.set_shader_parameter("impact",value)
