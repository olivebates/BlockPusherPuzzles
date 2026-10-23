class_name DottedLinks
extends RefCounted
static func draw(canvas: Node2D, start: Vector2, end: Vector2) -> void:
	var distance := start.distance_to(end)
	if distance<1: return
	for segment in range(0,int(distance),6):
		canvas.draw_circle(start.lerp(end,float(segment)/distance),0.45,Color(0.65,0.68,0.73,0.25))
