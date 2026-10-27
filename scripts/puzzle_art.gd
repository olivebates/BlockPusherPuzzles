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

static func draw_portal(canvas: CanvasItem, icon: int) -> void:
	var orange := Color("ffac59")
	canvas.draw_rect(Rect2(-6.5,-6.5,13,13),Color(orange,0.07))
	canvas.draw_rect(Rect2(-6.5,-6.5,13,13),orange,false,1)
	match icon:
		0: canvas.draw_rect(Rect2(-3,-3,6,6),orange,false,0.8)
		1: canvas.draw_arc(Vector2.ZERO,3.5,0,TAU,24,orange,0.8,true)
		2: canvas.draw_polyline(PackedVector2Array([Vector2(0,-4),Vector2(4,3),Vector2(-4,3),Vector2(0,-4)]),orange,0.8,true)
		3:
			var points := PackedVector2Array()
			for i in 11: points.append(Vector2.from_angle(-PI/2+i*PI/5)*(4.5 if i%2 == 0 else 2.0))
			canvas.draw_polyline(points,orange,0.8,true)

static func draw_recall_platform(canvas: CanvasItem) -> void:
	canvas.draw_rect(Rect2(-8,-2,16,4),Color("7d8da4"))
	canvas.draw_line(Vector2(-7,-2),Vector2(7,-2),Color("e4f4ff"),1)

static func draw_one_way(canvas: CanvasItem, color: Color) -> void:
	canvas.draw_rect(Rect2(-8,-8,16,4),color)
	canvas.draw_line(Vector2(-7,-7),Vector2(7,-7),color.lightened(0.485),1)

static func draw_pass_through(canvas: CanvasItem, edges: Array) -> void:
	for direction: Vector2 in edges:
		for dash in range(0,16,4):
			var point := Vector2(-8+dash,-8 if direction.y<0 else 7) if direction.y!=0 else Vector2(-8 if direction.x<0 else 7,-8+dash)
			canvas.draw_rect(Rect2(point,Vector2(2,1) if direction.y!=0 else Vector2(1,2)),Color.WHITE)
