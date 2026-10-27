@tool
extends StaticBody2D
var tile_color := Color("cccccc")
func _ready() -> void:
	if not Engine.is_editor_hint(): add_to_group("one_way_blocks")
func _draw() -> void:
	preload("res://scripts/puzzle_art.gd").draw_one_way(self,tile_color)
