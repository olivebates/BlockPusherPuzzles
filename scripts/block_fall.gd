class_name BlockFall
extends RefCounted
## Full-size boxes can share an edge with a wall. That zero-area contact
## does not support their weight, even if a native sweep reports a corner hit.
const EPSILON := 0.001
static func floor_distance(body: CharacterBody2D, distance: float) -> float:
	return axis_distance(body,Vector2(0,distance),[],body.collision_mask & ~2)
static func axis_distance(body: CharacterBody2D, motion: Vector2, ignored: Array[CharacterBody2D]=[], mask := -1) -> float:
	var horizontal := absf(motion.x)>absf(motion.y)
	var amount := motion.x if horizontal else motion.y
	var sign_axis := signf(amount)
	var distance := absf(amount)
	var result := distance
	var excluded: Array[RID]=body.body_rids()
	for other in ignored:
		if not excluded.has(other.get_rid()): excluded.append(other.get_rid())
	for other in body.get_collision_exceptions():
		if not excluded.has(other.get_rid()): excluded.append(other.get_rid())
	for collider in PuzzlePhysics.colliders(body):
		var rect := SupportCarry.bounds(collider)
		var swept := rect.merge(Rect2(rect.position+motion,rect.size)).grow(EPSILON)
		var query := PhysicsShapeQueryParameters2D.new()
		var shape := RectangleShape2D.new()
		shape.size=swept.size
		query.shape=shape
		query.transform=Transform2D(0,swept.get_center())
		query.collision_mask=body.collision_mask if mask<0 else mask
		query.exclude=excluded
		var maps_seen := {}
		# Tile edits are visible immediately, before their physics quadrants
		# rebuild. Inspect the authored wall cells as well as native query hits.
		var scene := body.get_tree().current_scene
		var walls := scene.get_node_or_null("Walls") as TileMapLayer if scene else null
		if walls:
			result=minf(result,map_distance(walls,rect,swept,distance,horizontal,sign_axis))
			maps_seen[walls]=true
		for hit in body.get_world_2d().direct_space_state.intersect_shape(query,128):
			var obstacle: Node2D=hit.collider
			if obstacle is TileMapLayer:
				if maps_seen.has(obstacle): continue
				maps_seen[obstacle]=true
				result=minf(result,map_distance(obstacle,rect,swept,distance,horizontal,sign_axis))
			else:
				for other in PuzzlePhysics.colliders(obstacle):
					if other.one_way_collision and (horizontal or sign_axis<0): continue
					if other.shape is CircleShape2D:
						var radius: float=other.shape.radius
						var offset := clampf(other.global_position.y,rect.position.y,rect.end.y)-other.global_position.y if horizontal else clampf(other.global_position.x,rect.position.x,rect.end.x)-other.global_position.x
						if absf(offset)>=radius-EPSILON: continue
						var center: float=other.global_position.x if horizontal else other.global_position.y
						var surface := center-sign_axis*sqrt(radius*radius-offset*offset)
						var edge: float=(rect.end.x if sign_axis>0 else rect.position.x) if horizontal else (rect.end.y if sign_axis>0 else rect.position.y)
						var gap := (surface-edge)*sign_axis
						if gap>=-EPSILON: result=minf(result,maxf(0,gap))
					else:
						result=minf(result,rect_distance(rect,SupportCarry.bounds(other),distance,horizontal,sign_axis))
	return result
static func map_distance(walls: TileMapLayer, rect: Rect2, swept: Rect2, distance: float, horizontal: bool, direction: float) -> float:
	var result := distance
	var first := walls.local_to_map(walls.to_local(swept.position))
	var last := walls.local_to_map(walls.to_local(swept.end))
	for x in range(first.x-1,last.x+2):
		for y in range(first.y-1,last.y+2):
			var cell := Vector2i(x,y)
			if walls.get_cell_source_id(cell)<0: continue
			var center := walls.to_global(walls.map_to_local(cell))
			result=minf(result,rect_distance(rect,Rect2(center-Vector2(8,8),Vector2(16,16)),distance,horizontal,direction))
	return result
static func rect_distance(box: Rect2, obstacle: Rect2, distance: float, horizontal: bool, direction: float) -> float:
	var overlap := minf(box.end.y,obstacle.end.y)-maxf(box.position.y,obstacle.position.y) if horizontal else minf(box.end.x,obstacle.end.x)-maxf(box.position.x,obstacle.position.x)
	if overlap<=EPSILON: return distance
	var gap: float
	if horizontal: gap=obstacle.position.x-box.end.x if direction>0 else box.position.x-obstacle.end.x
	else: gap=obstacle.position.y-box.end.y if direction>0 else box.position.y-obstacle.end.y
	if gap< -EPSILON:
		var ahead := (obstacle.get_center().x-box.get_center().x)*direction if horizontal else (obstacle.get_center().y-box.get_center().y)*direction
		return 0.0 if ahead>0 else distance
	return minf(distance,maxf(0,gap))
