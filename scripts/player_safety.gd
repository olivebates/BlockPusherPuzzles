class_name PlayerSafety
extends RefCounted
const HISTORY_LIMIT := 100
var player: CharacterBody2D
var ground_history: Array[Vector2]=[]
var lightning_grace := 0.0
var last_support_key := ""
func _init(body: CharacterBody2D) -> void: player=body
func feet_offset() -> float:
	var result := 0.0
	for collider in PuzzlePhysics.colliders(player):
		result=maxf(result,SupportCarry.bounds(collider).end.y-player.global_position.y)
	return result
func standing_point(surface: Vector2) -> Vector2:
	return Vector2(surface.x,surface.y-feet_offset()-0.05)
func floor_hit(point: Vector2) -> Dictionary:
	var feet := point+Vector2(0,feet_offset())
	var ray := PhysicsRayQueryParameters2D.create(feet-Vector2(0,0.4),feet+Vector2(0,1.2),5,[player.get_rid()])
	return player.get_world_2d().direct_space_state.intersect_ray(ray)
func in_lightning(point: Vector2) -> bool:
	for beam in player.get_tree().get_nodes_in_group("lightning_emitters"):
		if beam.touches_player(player,point): return true
	return false
func surface_available(surface: Vector2) -> bool:
	var point := standing_point(surface)
	if not PuzzlePhysics.clear_at(player,point,[player.get_rid()],5) or in_lightning(point): return false
	var hit := floor_hit(point)
	return not hit.is_empty() and hit.normal.y< -0.9 and absf(hit.position.y-surface.y)<0.4
func remember(surface: Vector2) -> void:
	if not ground_history.is_empty() and ground_history.back().distance_to(surface)<0.2: return
	for i in range(ground_history.size()-1,-1,-1):
		if ground_history[i].distance_to(surface)<0.2: ground_history.remove_at(i)
	ground_history.append(surface)
	if ground_history.size()>HISTORY_LIMIT: ground_history.pop_front()
func record_ground() -> void:
	if player.noclip or not player.is_on_floor() or player.velocity.y<0: return
	var hit := floor_hit(player.global_position)
	if hit.is_empty() or hit.normal.y>=-0.9 or hit.collider.is_in_group("spheres"): return
	var collider: Node2D=hit.collider
	var local_hit := collider.to_local(hit.position+Vector2(0,0.2))
	var support_cell := Vector2i(floor(local_hit/16))
	if collider is TileMapLayer: support_cell=collider.local_to_map(local_hit)
	var support_key := str(collider.get_instance_id(),":",support_cell)
	if support_key==last_support_key: return
	var surface := Vector2(floorf(player.global_position.x/16)*16+8,hit.position.y)
	if surface_available(surface):
		remember(surface)
		last_support_key=support_key
func teleport(point: Vector2) -> void:
	player.global_position=point
	player.velocity=Vector2.ZERO
	player.buffered=0
	player.coyote=0
	player.recall_freeze_frames=2
	player.force_update_transform()
	player.reset_physics_interpolation()
	last_support_key=""
	for camera in player.get_tree().get_nodes_in_group("game_camera"):
		camera.global_position=point
		camera.look=Vector2.ZERO
		camera.trauma=0
		camera.offset=Vector2.ZERO
		camera.reset_smoothing()
		camera.force_update_scroll()
func return_to_ground() -> bool:
	if player.noclip or lightning_grace>0: return false
	for i in range(ground_history.size()-1,-1,-1):
		if not surface_available(ground_history[i]): continue
		var destination := standing_point(ground_history[i])
		ground_history.resize(i+1)
		teleport(destination)
		lightning_grace=0.35
		Juice.sound("reset",1.12)
		Juice.burst(destination,Color("8adfff"),6)
		return true
	# A beam may be encountered before the first landing on a new level.
	var hit := floor_hit(player.spawn_point)
	if not hit.is_empty():
		var surface := Vector2(floorf(player.spawn_point.x/16)*16+8,hit.position.y)
		if surface_available(surface):
			teleport(standing_point(surface))
			lightning_grace=0.35
			return true
	return false
func free_cell(cell: Vector2i) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := RectangleShape2D.new()
	shape.size=Vector2(15.8,15.8)
	query.shape=shape
	query.transform=Transform2D(0,Vector2(cell*16)+Vector2(8,8))
	query.collision_mask=5
	query.exclude=[player.get_rid()]
	return player.get_world_2d().direct_space_state.intersect_shape(query).is_empty()
func nearest_free_tile() -> Vector2:
	var origin := Vector2i(floor(player.global_position/16))
	var best := Vector2.INF
	var distance := INF
	for radius in range(513):
		var cells: Array[Vector2i]=[]
		if radius==0: cells.append(origin)
		else:
			for offset in range(-radius,radius+1):
				cells.append(origin+Vector2i(offset,-radius))
				cells.append(origin+Vector2i(offset,radius))
				if absi(offset)<radius:
					cells.append(origin+Vector2i(-radius,offset))
					cells.append(origin+Vector2i(radius,offset))
		for cell in cells:
			var point := standing_point(Vector2(cell.x*16+8,(cell.y+1)*16))
			var next := point.distance_to(player.global_position)
			if next>=distance or not free_cell(cell) or in_lightning(point): continue
			if not PuzzlePhysics.clear_at(player,point,[player.get_rid()],5): continue
			best=point
			distance=next
		if distance<maxf(0,radius-1)*16: break
	return best
func recover_embedded() -> bool:
	if player.noclip or not player.rotation_locks.is_empty(): return false
	var excluded: Array[RID]=[player.get_rid()]
	# Passing upward through a one-way platform is valid, not an embedding.
	for platform in player.get_tree().get_nodes_in_group("one_way_blocks"): excluded.append(platform.get_rid())
	if PuzzlePhysics.clear_at(player,player.global_position,excluded,5): return false
	var destination := nearest_free_tile()
	if not destination.is_finite(): return false
	teleport(destination)
	return true
func save_history() -> Array:
	var result: Array=[]
	for point in ground_history: result.append([point.x,point.y])
	return result
func restore_history(data: Array) -> void:
	ground_history.clear()
	for point in data.slice(maxi(0,data.size()-HISTORY_LIMIT)):
		if Progress.vector_valid(point): ground_history.append(Vector2(point[0],point[1]))
	lightning_grace=0
	last_support_key=""
