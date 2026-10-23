@tool
extends Node2D
@export var block_color: PuzzlePalette.Hue = PuzzlePalette.Hue.CYAN:
	set(value):
		block_color = value
		queue_redraw()
@export var id := "A"
var filled := false
var energy := 0.0
func _ready() -> void:
	if not Engine.is_editor_hint(): add_to_group("pads")
func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	var occupied := false
	for block in get_tree().get_nodes_in_group("blocks"):
		if block.block_color == block_color and block.global_position.distance_to(global_position) < 2.0 and block.is_settled(): occupied = true
	if occupied and not filled:
		Juice.sound("pad",1+block_color*0.12)
		Juice.burst(global_position,PuzzlePalette.color_for(block_color),8)
	filled = occupied
	energy = move_toward(energy,1.0 if filled else 0.0,delta*5)
	if material: material.set_shader_parameter("energy",energy)
	queue_redraw()
func _draw() -> void:
	var color := PuzzlePalette.color_for(block_color)
	draw_rect(Rect2(-6,-6,12,12),Color(color,0.08+energy*0.22))
	draw_rect(Rect2(-6,-6,12,12),color,false,1)
	if energy > 0: draw_rect(Rect2(-7.5,-7.5,15,15),Color(color,energy*0.4),false,0.6)
