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
	if not Engine.is_editor_hint():
		add_to_group("pads")
		set_notify_transform(true)
		PuzzleOccupancy.invalidate(self,"pads")
func _notification(what: int) -> void:
	if what==NOTIFICATION_TRANSFORM_CHANGED and not Engine.is_editor_hint() and is_inside_tree(): PuzzleOccupancy.invalidate(self,"pads")
func _exit_tree() -> void:
	if not Engine.is_editor_hint(): PuzzleOccupancy.invalidate(self,"pads")
func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	var occupied := false
	for block in PuzzleOccupancy.nearby(self,"blocks"):
		if block.block_color==block_color and block.global_position.distance_squared_to(global_position)<4 and block.is_settled():
			occupied=true
			break
	if occupied and not filled:
		Juice.sound("pad",1+block_color*0.12)
		Juice.burst(global_position,PuzzlePalette.color_for(block_color),8)
	filled = occupied
	var previous_energy := energy
	energy = move_toward(energy,1.0 if filled else 0.0,delta*5)
	if previous_energy!=energy:
		if material: material.set_shader_parameter("energy",energy)
		queue_redraw()
func _draw() -> void:
	preload("res://scripts/puzzle_art.gd").draw_pad(self,PuzzlePalette.color_for(block_color),energy)
