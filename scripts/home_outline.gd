extends Node2D
var hue := 0
var circular := false
var white := false
var failure_flash := 0.0
func flash_failure() -> void:
	failure_flash = 0.65
	z_index = 2
	queue_redraw()
func _process(delta: float) -> void:
	if failure_flash>0:
		failure_flash = maxf(0,failure_flash-delta)
		if failure_flash==0: z_index = -1
		queue_redraw()
func _ready() -> void:
	z_index = -1
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/surface.gdshader")
func _draw() -> void:
	if failure_flash>0:
		var red := Color(1,0.12,0.15,minf(1,failure_flash*4)*(0.55+0.45*absf(sin(failure_flash*20))))
		draw_line(Vector2(-4,-4),Vector2(4,4),red,2)
		draw_line(Vector2(4,-4),Vector2(-4,4),red,2)
	var color := PuzzlePalette.color_for(hue)
	if white: color = Color.WHITE
	color.a = 0.55
	if circular:
		for i in 16:
			draw_arc(Vector2.ZERO,7.5,i*TAU/16,i*TAU/16+0.17,3,color,0.8,true)
		return
	for side in 4:
		for segment in 4:
			var a := Vector2(-7+segment*4,-7).rotated(side*PI/2)
			var b := Vector2(-5+segment*4,-7).rotated(side*PI/2)
			# At the editor's 1x play scale, subpixel lines on integer coordinates
			# can miss every pixel center. Antialiasing keeps the dashes visible.
			draw_line(a,b,color,0.8,true)
