@tool
extends Node2D
var lit := false
var energy := 0.0
func _ready() -> void:
	if not Engine.is_editor_hint(): add_to_group("collectible_indicators")
func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	energy=move_toward(energy,1.0 if lit else 0.0,delta*4)
	queue_redraw()
func _draw() -> void:
	var color := Color("ffe38b")
	draw_circle(Vector2.ZERO,5,Color("25272a"))
	draw_arc(Vector2.ZERO,5,0,TAU,24,color.darkened(0.5),1,true)
	draw_circle(Vector2.ZERO,3.5,color.darkened(0.8).lerp(color,energy))
	if energy>0: draw_circle(Vector2.ZERO,7,Color(color,energy*0.1))
