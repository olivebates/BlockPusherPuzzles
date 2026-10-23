@tool
extends StaticBody2D
var tile_color := Color("333333")
func _ready() -> void:
	if not Engine.is_editor_hint(): add_to_group("one_way_blocks")
func _draw() -> void:
	draw_rect(Rect2(-8,-8,16,16),Color(tile_color,0.3))
	draw_rect(Rect2(-8,-8,16,4),tile_color)
	draw_line(Vector2(-7,-7),Vector2(7,-7),tile_color.lightened(0.485),1)
