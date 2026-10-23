class_name PuzzlePhysics
extends RefCounted
## Atomic teleport: validate the whole compound body and reserve a safe player exit.
static func colliders(body: Node2D) -> Array[CollisionShape2D]:
	var result: Array[CollisionShape2D] = []
	for child in body.get_children():
		if child is CollisionShape2D and not child.disabled: result.append(child)
	return result
static func clear_at(body: Node2D, point: Vector2, excluded: Array[RID], mask := -1) -> bool:
	if mask<0: mask=body.collision_mask
	for collider in colliders(body):
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = collider.shape
		# Exact edge contact is valid placement, not an occupied destination.
		if collider.shape is RectangleShape2D:
			query.shape = collider.shape.duplicate()
			query.shape.size -= Vector2(0.02,0.02)
		query.transform = Transform2D(0,point+collider.position)
		query.collision_mask = mask
		query.exclude = excluded
		if not body.get_world_2d().direct_space_state.intersect_shape(query).is_empty(): return false
	return true
static func pivot_rider_position(player: CharacterBody2D, pivot: Vector2, footprints: Array[Rect2], excluded: Array[RID], feet: float) -> Vector2:
	var query := PhysicsShapeQueryParameters2D.new()
	var tile := RectangleShape2D.new()
	tile.size=Vector2(15.98,15.98)
	query.shape=tile
	query.collision_mask=player.collision_mask
	query.exclude=excluded
	for step in range(1,footprints.size()+2):
		var center := pivot+Vector2(0,-16*step)
		query.transform=Transform2D(0,center)
		# Own welded cells may be crossed. Any other solid ends the search;
		# the player must never be transported through a ceiling or another box.
		if not player.get_world_2d().direct_space_state.intersect_shape(query).is_empty(): return Vector2.INF
		var occupied := false
		var cell := Rect2(center-Vector2(7.99,7.99),Vector2(15.98,15.98))
		for rect in footprints:
			if rect.intersects(cell): occupied=true
		if occupied: continue
		var candidate := Vector2(center.x,center.y+8-feet-0.2)
		return candidate if clear_at(player,candidate,excluded) else Vector2.INF
	return Vector2.INF
static func teleport(body: CharacterBody2D, point: Vector2, excluded: Array[RID], rider_override := -1, recall_pivot := Vector2.INF) -> bool:
	var player := body.get_tree().get_first_node_in_group("player") as CharacterBody2D
	var exclusions: Array[RID] = excluded.duplicate()
	if player: exclusions.append(player.get_rid())
	if not clear_at(body,point,exclusions): return false
	var footprints: Array[Rect2] = []
	for collider in colliders(body):
		var rect := collider.shape.get_rect()
		rect.position += point+collider.position
		footprints.append(rect)
	if player:
		var riding := SupportCarry.supports(body,player) if rider_override<0 else rider_override==1
		var player_shapes := colliders(player)
		var player_rect := SupportCarry.bounds(player_shapes[0])
		for shape in player_shapes.slice(1): player_rect=player_rect.merge(SupportCarry.bounds(shape))
		var left_extent := player.global_position.x-player_rect.position.x
		var right_extent := player_rect.end.x-player.global_position.x
		var feet := player_rect.end.y-player.global_position.y
		var overlapping := false
		var bounds := footprints[0]
		for rect in footprints:
			bounds = bounds.merge(rect)
			if rect.intersects(player_rect): overlapping = true
		if overlapping or riding:
			# Preserve the authored spawn exactly. Lift the player vertically onto
			# the actual destination footprint under their feet, never shift the body.
			var preferred_x: float = point.x+player.global_position.x-body.global_position.x if riding else player.global_position.x
			var candidates: Array[Vector2] = []
			# Search toward the center before falling back to either side. This
			# clears nearby ledges while keeping the recalled body at its exact home.
			var steps := maxi(1,int(ceilf(absf(preferred_x-bounds.get_center().x))))
			for i in range(steps+1):
				var x := lerpf(preferred_x,bounds.get_center().x,float(i)/steps)
				var standing_y := INF
				for rect in footprints:
					if x+right_extent>rect.position.x and x-left_extent<rect.end.x: standing_y = minf(standing_y,rect.position.y-feet-0.2)
				if is_finite(standing_y): candidates.append(Vector2(x,standing_y))
			for rect in footprints: candidates.append(Vector2(rect.get_center().x,rect.position.y-feet-0.2))
			if not riding or overlapping:
				candidates.append_array([Vector2(bounds.position.x-maxf(8.1,right_extent+0.2),bounds.get_center().y),Vector2(bounds.end.x+maxf(8.1,left_extent+0.2),bounds.get_center().y)])
			if riding and recall_pivot.is_finite():
				candidates.clear()
				var pivot_candidate := pivot_rider_position(player,recall_pivot,footprints,exclusions,feet)
				if pivot_candidate.is_finite(): candidates.append(pivot_candidate)
			var safe := false
			for candidate in candidates:
				if not clear_at(player,candidate,exclusions): continue
				var next_rect := Rect2(player_rect.position+candidate-player.global_position,player_rect.size)
				var overlaps := false
				for rect in footprints:
					if rect.intersects(next_rect): overlaps = true
				if overlaps: continue
				player.global_position = candidate
				player.velocity = Vector2.ZERO
				player.recall_freeze_frames = 2
				player.force_update_transform()
				player.reset_physics_interpolation()
				safe = true
				break
			# A rider without room at the destination stays behind while the body
			# returns. An occupant of the destination still needs a safe exit.
			if not safe and overlapping: return false
	body.global_position = point
	body.velocity = Vector2.ZERO
	body.recall_freeze_frames = 2
	body.force_update_transform()
	body.reset_physics_interpolation()
	return true
