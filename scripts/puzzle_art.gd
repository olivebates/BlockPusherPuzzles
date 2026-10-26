extends RefCounted
# Shared runtime/editor drawing. Keep this independent of gameplay and autoloads.
static func draw_block(canvas: CanvasItem, color: Color, on_key := false) -> void:
	canvas.draw_rect(Rect2(-8,-8,16,16),color.darkened(0.35))
	if on_key: canvas.draw_rect(Rect2(-5,-5,10,10),Color.WHITE,false,0.6)

static func draw_pad(canvas: CanvasItem, color: Color, glow := 0.0) -> void:
	canvas.draw_rect(Rect2(-6,-6,12,12),Color(color,0.08+glow*0.22))
	canvas.draw_rect(Rect2(-6,-6,12,12),color,false,1)
	if glow > 0: canvas.draw_rect(Rect2(-7.5,-7.5,15,15),Color(color,glow*0.4),false,0.6)

static func draw_rotator(canvas: CanvasItem, clockwise: bool, color := Color(1,0.83,0.2)) -> void:
	canvas.draw_rect(Rect2(-7.5,-7.5,15,15),color,false,1)
	var points := PackedVector2Array()
	var direction := 1.0 if clockwise else -1.0
	for i in 29: points.append(Vector2.from_angle(-PI/2+direction*(0.25+float(i)/28*(TAU-0.8)))*5.5)
	canvas.draw_polyline(points,color,1.2,true)
	var tip := points[-1]
	var tangent := Vector2.from_angle(-PI/2+direction*(TAU-0.55)+direction*PI/2)
	canvas.draw_colored_polygon(PackedVector2Array([tip+tangent*1.5,tip-tangent*2+tangent.orthogonal()*2,tip-tangent*2-tangent.orthogonal()*2]),color)
