@tool
class_name WeldOutline
extends Node2D
static func draw_pivot(canvas: CanvasItem, center: Vector2) -> void:
	var color := Color(1,0.83,0.2)
	var origin := center.round()-Vector2(2,2)
	# Five-pixel circle, with one-pixel sides and clipped corner pixels.
	canvas.draw_rect(Rect2(origin+Vector2(1,0),Vector2(3,1)),color)
	canvas.draw_rect(Rect2(origin+Vector2(1,4),Vector2(3,1)),color)
	canvas.draw_rect(Rect2(origin+Vector2(0,1),Vector2(1,3)),color)
	canvas.draw_rect(Rect2(origin+Vector2(4,1),Vector2(1,3)),color)
## Trace the actual union, then inset its closed contours for continuous miters.
static func contours(offsets: Array[Vector2]) -> Array[PackedVector2Array]:
	var cells := {}
	for point in offsets: cells[Vector2i(round(point/16))]=true
	var edges := {}
	var directions := [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]
	var corners := [Vector2i(-8,-8),Vector2i(8,-8),Vector2i(8,8),Vector2i(-8,8)]
	for cell in cells:
		for side in 4:
			if cells.has(cell+directions[side]): continue
			var start: Vector2i=cell*16+corners[side]
			var end: Vector2i=cell*16+corners[(side+1)%4]
			if not edges.has(start): edges[start]=[]
			edges[start].append(end)
	var result: Array[PackedVector2Array]=[]
	while not edges.is_empty():
		var start: Vector2i=edges.keys()[0]
		var point := start
		var incoming := Vector2i.RIGHT
		var loop := PackedVector2Array()
		while true:
			loop.append(Vector2(point))
			if not edges.has(point): break
			var next: Vector2i=edges[point][0]
			var best := -10
			for candidate in edges[point]:
				var direction: Vector2i=(candidate-point)/16
				var cross := incoming.x*direction.y-incoming.y*direction.x
				var score := 3 if cross>0 else 2 if incoming.x*direction.x+incoming.y*direction.y>0 else 1
				if score>best:
					best=score
					next=candidate
			edges[point].erase(next)
			if edges[point].is_empty(): edges.erase(point)
			incoming=(next-point)/16
			point=next
			if point==start: break
		if loop.size()<3: continue
		var area := 0.0
		for i in loop.size(): area+=loop[i].cross(loop[(i+1)%loop.size()])
		var inset := Geometry2D.offset_polygon(loop,-0.5 if area>0 else 0.5,Geometry2D.JOIN_MITER)
		for polygon in inset:
			polygon.append(polygon[0])
			result.append(polygon)
	return result
func _draw() -> void:
	var body := get_parent()
	if body.leader!=body: return
	var offsets: Array[Vector2]=[]
	for member in body.members: offsets.append(member.weld_offset)
	var color := PuzzlePalette.color_for(body.block_color)
	if body.recall_available: color=color.lightened(0.42)
	for contour in contours(offsets): draw_polyline(contour,color,1,false)
	var pivot: Node2D=body.rotation_pivot_member()
	draw_pivot(self,body.to_local(pivot.global_position))
