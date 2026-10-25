@tool
extends StaticBody2D
@export_flags("Cyan","Coral","Gold","Lilac") var required_colors := 1:
	set(value):
		required_colors = value
		queue_redraw()
@export var id := "A"
var height_tiles := 1:
	set(value):
		height_tiles = value
		queue_redraw()
var openness := 0.0
var opened := false
var passed_through := false
var passage := preload("res://scripts/door_passage.gd").new()
func _ready() -> void:
	if Engine.is_editor_hint(): return
	add_to_group("doors")
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16,height_tiles*16)
	$CollisionShape2D.shape = shape
	$CollisionShape2D.position.y = -(height_tiles-1)*8
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	var satisfied := required_colors != 0
	for hue in 4:
		if not (required_colors & (1 << hue)): continue
		var count := 0
		for pad in get_tree().get_nodes_in_group("pads"):
			if pad.id == id and pad.block_color == hue:
				count += 1
				if not pad.filled: satisfied = false
		if count == 0: satisfied = false
	if not satisfied and opened and doorway_occupied(): satisfied = true
	if satisfied != opened:
		opened = satisfied
		$CollisionShape2D.set_deferred("disabled",opened)
		Juice.sound("open" if opened else "close")
		Juice.burst(global_position+Vector2(0,-height_tiles*8+8),Color("dcecf3"),12)
		Juice.impact(0.65,global_position)
	openness = move_toward(openness,1.0 if opened else 0.0,delta*4)
	if not passed_through: passed_through=passage.update(self)
	if material: material.set_shader_parameter("energy",1-openness)
	queue_redraw()
func doorway_occupied() -> bool:
	var rect := Rect2(global_position+Vector2(-14,-height_tiles*16+1),Vector2(28,height_tiles*16+14))
	for actor in get_tree().get_nodes_in_group("blocks")+get_tree().get_nodes_in_group("spheres")+get_tree().get_nodes_in_group("player"):
		if rect.has_point(actor.global_position): return true
	return false
func _draw() -> void:
	var colors: Array[Color] = []
	for hue in 4:
		if required_colors & (1 << hue): colors.append(PuzzlePalette.color_for(hue))
	if colors.is_empty(): colors.append(Color("71839a"))
	# Two inset panels share a one-pixel recess in the closed, one-tile door.
	# The whole silhouette contracts to a centered 4x4 marker when passable.
	var scale_factor := lerpf(1.0,0.25,openness)
	var size := 16.0*scale_factor
	var backing := colors[0].darkened(0.75)
	backing.a = 1.0-openness
	draw_rect(Rect2(Vector2.ONE*(-size/2),Vector2.ONE*size),backing)
	for panel in 2:
		var left := (-6.0+panel*6.5)*scale_factor
		for i in colors.size():
			var stripe_height := 12.0*scale_factor/colors.size()
			var panel_color := colors[i].darkened(0.2)
			panel_color.a = 1.0-openness
			draw_rect(Rect2(left,-6.0*scale_factor+i*stripe_height,5.5*scale_factor,stripe_height),panel_color)
	# The outline is inset by half its width so its full footprint is exactly 4x4.
	var corners := [Vector2(-1.5,-1.5),Vector2(1.5,-1.5),Vector2(1.5,1.5),Vector2(-1.5,1.5)]
	for side in 4:
		for i in colors.size():
			var color := Color(colors[i],openness)
			var start: Vector2 = corners[side].lerp(corners[(side+1)%4],float(i)/colors.size())
			var end: Vector2 = corners[side].lerp(corners[(side+1)%4],float(i+1)/colors.size())
			draw_line(start,end,color,1)

