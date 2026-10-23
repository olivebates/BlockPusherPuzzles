@tool
extends Node2D
@export var clockwise := true:
	set(value):
		clockwise=value
		queue_redraw()
const DURATION := 0.2
var cooldown := 0
var countdown := 0.0
var countdown_tween: Tween
var failure_flash := 0.0
var body: CharacterBody2D
var pivot := Vector2.ZERO
var source := Vector2.ZERO
var destination := Vector2.ZERO
var old_offsets: Array[Vector2]=[]
var new_offsets: Array[Vector2]=[]
var elapsed := 0.0
var waiting := false
var failed_stamp := ""
var moves := 0
var frozen_player: CharacterBody2D
var player_exception_added := false
func _ready() -> void:
	z_index=4
	if not Engine.is_editor_hint():
		add_to_group("rotators")
		Juice.block_pushed.connect(count_move)
func count_move() -> void:
	moves+=1
	if cooldown<=0: return
	cooldown-=1
	if countdown_tween and countdown_tween.is_valid(): countdown_tween.kill()
	countdown_tween=create_tween()
	countdown_tween.tween_property(self,"countdown",float(cooldown),DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
func center_member(block: CharacterBody2D) -> Node2D:
	return block.rotation_pivot_member()
func touched(block: CharacterBody2D) -> bool:
	for member in block.members:
		if Rect2(member.global_position-Vector2(8,8),Vector2(16,16)).intersects(Rect2(global_position-Vector2(7,7),Vector2(14,14))): return true
	return false
func bounds_at(points: Array[Vector2]) -> Rect2:
	var rect := Rect2(points[0]-Vector2(8,8),Vector2(16,16))
	for point in points: rect=rect.merge(Rect2(point-Vector2(8,8),Vector2(16,16)))
	return rect
func obstacles_at(points: Array[Vector2], block: CharacterBody2D) -> Array:
	var result: Array=[]
	var shape := RectangleShape2D.new()
	shape.size=Vector2(15.98,15.98)
	for point in points:
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape=shape
		query.transform=Transform2D(0,point)
		query.collision_mask=13
		query.exclude=block.body_rids()
		for hit in get_world_2d().direct_space_state.intersect_shape(query,64):
			var actor: Node2D=hit.collider
			if actor is TileMapLayer:
				# Physics quadrants may merge many tiles into one body RID.
				# Resolve the actual occupied cells around this footprint instead.
				var cell: Vector2i=actor.local_to_map(actor.to_local(point))
				for x in range(cell.x-1,cell.x+2):
					for y in range(cell.y-1,cell.y+2):
						if actor.get_cell_source_id(Vector2i(x,y))<0: continue
						var center: Vector2=actor.to_global(actor.map_to_local(Vector2i(x,y)))
						var rect := Rect2(center-Vector2(8,8),Vector2(16,16))
						if rect.intersects(Rect2(point-Vector2(7.99,7.99),Vector2(15.98,15.98))): result.append([point,rect])
			else:
				for collider in PuzzlePhysics.colliders(actor):
					var rect := SupportCarry.bounds(collider)
					if rect.intersects(Rect2(point-Vector2(7.99,7.99),Vector2(15.98,15.98))): result.append([point,rect])
	return result
func resolve(block: CharacterBody2D) -> Dictionary:
	var selected := center_member(block)
	var pivot_point: Vector2=selected.global_position
	var angle := PI/2 if clockwise else -PI/2
	var before: Array[Vector2]=[]
	var points: Array[Vector2]=[]
	for member in block.members:
		before.append(member.global_position)
		points.append(pivot_point+(member.global_position-pivot_point).rotated(angle).snapped(Vector2.ONE))
	var original := bounds_at(before)
	var correction := Vector2.ZERO
	var visited := {}
	for attempt in range(block.members.size()*4+16):
		var shifted: Array[Vector2]=[]
		for point in points: shifted.append(point+correction)
		var hits := obstacles_at(shifted,block)
		if hits.is_empty(): return {"pivot":pivot_point,"points":shifted,"correction":correction}
		if visited.has(correction): return {}
		visited[correction]=true
		var up := 0.0
		for hit in hits:
			var obstacle: Rect2=hit[1]
			# Ground is below the shape's original feet. Lift in whole tiles.
			if obstacle.position.y>=original.end.y-0.3:
				up=minf(up,obstacle.position.y-(hit[0].y+8))
		if up<0:
			correction.y-=ceilf(-up/16)*16
			continue
		var horizontal := 0.0
		for hit in hits:
			var obstacle: Rect2=hit[1]
			if obstacle.end.y<=original.position.y+0.3: return {}
			var direction := signf(pivot_point.x-obstacle.get_center().x)
			if direction==0: direction=signf(global_position.x-obstacle.get_center().x)
			if direction==0: return {}
			var amount: float = obstacle.end.x-(hit[0].x-8) if direction>0 else obstacle.position.x-(hit[0].x+8)
			var shift := direction*ceilf(absf(amount)/16)*16
			if horizontal!=0 and signf(horizontal)!=direction: return {}
			if absf(shift)>absf(horizontal): horizontal=shift
		if horizontal==0: return {}
		correction.x+=horizontal
	return {}
func player_clear(points: Array[Vector2]) -> bool:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if not player or player.noclip: return true
	return player_clear_at(points,player.global_position)
func player_clear_at(points: Array[Vector2], point: Vector2) -> bool:
	var rect := Rect2(point-Vector2(5,7),Vector2(10,14))
	for tile_point in points:
		if rect.intersects(Rect2(tile_point-Vector2(8,8),Vector2(16,16))): return false
	return true
func prepare_player(points: Array[Vector2]) -> bool:
	if player_clear(points): return true
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	var excluded: Array[RID]=body.body_rids()
	excluded.append(player.get_rid())
	for offset in [Vector2.UP*16,Vector2.LEFT*16,Vector2.RIGHT*16]:
		var point: Vector2=player.global_position+offset
		if not player_clear_at(points,point) or not PuzzlePhysics.clear_at(player,point,excluded): continue
		player.global_position=point
		player.velocity=Vector2.ZERO
		player.force_update_transform()
		player.reset_physics_interpolation()
		return true
	return false
func freeze_player() -> void:
	if is_instance_valid(frozen_player): return
	frozen_player=get_tree().get_first_node_in_group("player") as CharacterBody2D
	if not frozen_player: return
	frozen_player.rotation_locks[get_instance_id()]=true
	frozen_player.velocity=Vector2.ZERO
	player_exception_added=not body.get_collision_exceptions().has(frozen_player)
	if player_exception_added: body.add_collision_exception_with(frozen_player)
func release_player() -> void:
	if is_instance_valid(frozen_player):
		frozen_player.rotation_locks.erase(get_instance_id())
		frozen_player.velocity=Vector2.ZERO
		if player_exception_added and is_instance_valid(body): body.remove_collision_exception_with(frozen_player)
	frozen_player=null
	player_exception_added=false
func _exit_tree() -> void:
	if not Engine.is_editor_hint(): release_player()
func activate(block: CharacterBody2D) -> bool:
	if cooldown>0 or is_instance_valid(body) or block.rotating or block.sliding: return false
	var solution := resolve(block)
	if solution.is_empty():
		failure_flash=0.6
		Juice.sound("reject")
		return false
	body=block
	body.rotating=true
	body.rotation_controller=self
	body.velocity=Vector2.ZERO
	body.charge=0
	source=body.global_position
	pivot=solution.pivot
	destination=solution.points[0]
	old_offsets.clear()
	new_offsets.clear()
	for i in body.members.size():
		old_offsets.append(body.members[i].weld_offset)
		new_offsets.append(solution.points[i]-destination)
	elapsed=0
	waiting=not prepare_player(solution.points)
	if not waiting:
		freeze_player()
		Juice.sound("rotate")
	return true
func cancel() -> void:
	release_player()
	if is_instance_valid(body):
		body.global_position=source
		body.rotation=0
		for i in body.members.size():
			body.members[i].rotation=0
			body.members[i].weld_offset=old_offsets[i]
		body.rotating=false
		body.rotation_controller=null
		body.resting_x=source.x
		body.sync_members()
	body=null
	waiting=false
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	failure_flash=maxf(0,failure_flash-delta)
	queue_redraw()
	if is_instance_valid(body):
		var targets: Array[Vector2]=[]
		for offset in new_offsets: targets.append(destination+offset)
		if not prepare_player(targets):
			waiting=true
			release_player()
			return
		if waiting:
			waiting=false
			freeze_player()
			Juice.sound("rotate")
		elapsed+=delta
		var fraction := clampf(elapsed/DURATION,0,1)
		var smooth := fraction*fraction*(3-2*fraction)
		var angle := (PI/2 if clockwise else -PI/2)*smooth
		var correction := destination-(pivot+(source-pivot).rotated(PI/2 if clockwise else -PI/2))
		body.global_position=pivot+(source-pivot).rotated(angle)+correction*smooth
		body.rotation=angle
		for i in body.members.size():
			if body.members[i]==body: continue
			body.members[i].global_position=body.global_position+old_offsets[i].rotated(angle)
			body.members[i].rotation=angle
		body.force_update_transform()
		if fraction>=1:
			body.global_position=destination
			body.rotation=0
			for i in body.members.size():
				body.members[i].rotation=0
				body.members[i].weld_offset=new_offsets[i].snapped(Vector2.ONE)
			body.rebuild_weld_shapes()
			body.rotating=false
			body.rotation_controller=null
			body.resting_x=destination.x
			body.supported_by_player=false
			body.has_moved=true
			body.recall_freeze_frames=1
			body.sync_members()
			release_player()
			body=null
			cooldown=3
			countdown=3
			Juice.impact(0.4,global_position)
		return
	release_player()
	body=null
	if cooldown>0 or countdown>0.001: return
	var contact_seen := false
	for candidate in get_tree().get_nodes_in_group("blocks"):
		if candidate.leader!=candidate or candidate.rotating or not candidate.is_settled() or not touched(candidate): continue
		contact_seen=true
		var stamp := str(candidate.get_instance_id(),moves)
		if stamp==failed_stamp: continue
		if not activate(candidate): failed_stamp=stamp
		break
	if not contact_seen: failed_stamp=""
func _draw() -> void:
	var alpha := 0.28 if cooldown>0 or countdown>0.001 else 1.0
	var color := Color(1,0.83,0.2,alpha)
	draw_rect(Rect2(-7.5,-7.5,15,15),color,false,1)
	var points := PackedVector2Array()
	var direction := 1.0 if clockwise else -1.0
	for i in 29: points.append(Vector2.from_angle(-PI/2+direction*(0.25+float(i)/28*(TAU-0.8)))*5.5)
	draw_polyline(points,color,1.2,true)
	var tip := points[-1]
	var tangent := Vector2.from_angle(-PI/2+direction*(TAU-0.55)+direction*PI/2)
	draw_colored_polygon(PackedVector2Array([tip+tangent*1.5,tip-tangent*2+tangent.orthogonal()*2,tip-tangent*2-tangent.orthogonal()*2]),color)
	if countdown>0.001: draw_arc(Vector2.ZERO,6.8,-PI/2,-PI/2+TAU*countdown/3,48,Color(1,0.83,0.2,0.7),1,true)
	if failure_flash>0:
		var red := Color(1,0.12,0.15,minf(1,failure_flash*4))
		draw_line(Vector2(-4,-4),Vector2(4,4),red,2)
		draw_line(Vector2(4,-4),Vector2(-4,4),red,2)
