@tool
extends Node2D
var used: bool:
	get: return Progress.map_hint_stage>0
func _ready() -> void:
	if not Engine.is_editor_hint(): add_to_group("map_tutorial_triggers")
func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or Progress.restoring or used: return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player or player.noclip: return
	if Rect2(global_position-Vector2(8,8),Vector2(16,16)).intersects(Rect2(player.global_position-Vector2(5,7),Vector2(10,14))):
		Progress.map_hint_stage=2 if Progress.map_opened else 1
		player.queue_redraw()
func _draw() -> void:
	if not Engine.is_editor_hint(): return
	draw_rect(Rect2(-7.5,-7.5,15,15),Color("ffd433"),false,1)
	draw_line(Vector2(-2,-6),Vector2(-2,6),Color("ffd433"),1)
	draw_line(Vector2(2,-6),Vector2(2,6),Color("ffd433"),1)
