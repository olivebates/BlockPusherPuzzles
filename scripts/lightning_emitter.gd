@tool
extends Node2D
## Horizontal electricity returns the player to a previously visited safe floor.
@export_enum("Right", "Left") var direction := 0:
	set(value):
		direction=value
		queue_redraw()
@export_range(1,512,1) var max_length_tiles := 128
@export var beam_color := Color("8adfff"):
	set(value):
		beam_color=value
		queue_redraw()
@export var enabled := true:
	set(value):
		enabled=value
		queue_redraw()
var beam_end := Vector2.ZERO
var beam_start := Vector2.ZERO
var source_face := Vector2.ZERO
var end_face := Vector2.ZERO
var mounted := false
var hit_wall := false
var bolts: Array[PackedVector2Array]=[]
var animation_wait := 0.0
var previous_end := Vector2.INF
var previous_start := Vector2.INF
var rng := RandomNumberGenerator.new()
func _ready() -> void:
	z_index=2
	rng.randomize()
	if not Engine.is_editor_hint(): add_to_group("lightning_emitters")
func update_endpoint() -> void:
	if has_meta("editor_beam_cells"):
		# Editor hazards occupy the same symmetric, wall-bounded cells in play.
		var span: Rect2i=get_meta("editor_beam_cells")
		source_face=Vector2(span.position.x*16-position.x,0)
		end_face=Vector2(span.end.x*16-position.x,0)
		beam_start=source_face+Vector2(4,0)
		beam_end=end_face-Vector2(4,0)
		mounted=true
		hit_wall=true
		return
	var axis := Vector2(1 if direction==0 else -1,0)
	var back := ray_hit(global_position,global_position-axis*max_length_tiles*16)
	mounted=not back.is_empty()
	var start_world := global_position
	if mounted: start_world=wall_face(back,axis.x)
	source_face=to_local(start_world if mounted else global_position-axis*4)
	beam_start=to_local(start_world+axis*4 if mounted else global_position)
	var destination := start_world+axis*max_length_tiles*16
	var hit := ray_hit(start_world+axis*0.05,destination)
	hit_wall=not hit.is_empty()
	end_face=to_local(hit.position if hit_wall else destination)
	beam_end=end_face
	# Work in local coordinates while keeping the authored emitter horizontal.
	if hit_wall: beam_end=to_local(hit.position-axis*4)
	if (beam_end-beam_start).dot(to_local(global_position+axis)-to_local(global_position))<=0:
		beam_end=beam_start
func ray_hit(from: Vector2, to: Vector2) -> Dictionary:
	var ray := PhysicsRayQueryParameters2D.create(from,to,1)
	ray.collide_with_areas=false
	ray.hit_from_inside=true
	return get_world_2d().direct_space_state.intersect_ray(ray)
func wall_face(hit: Dictionary, facing: float) -> Vector2:
	if hit.normal!=Vector2.ZERO: return hit.position
	var actor: Node2D=hit.collider
	if actor is TileMapLayer:
		var cell: Vector2i=actor.local_to_map(actor.to_local(hit.position))
		return actor.to_global(actor.map_to_local(cell)+Vector2(facing*8,0))
	for collider in PuzzlePhysics.colliders(actor):
		var rect := SupportCarry.bounds(collider)
		if rect.grow(0.01).has_point(hit.position): return Vector2(rect.end.x if facing>0 else rect.position.x,hit.position.y)
	return hit.position
func touches_player(player: CharacterBody2D, point: Vector2) -> bool:
	if not enabled or beam_start.is_equal_approx(beam_end): return false
	var a := to_global(beam_start)
	var b := to_global(beam_end)
	var beam := Rect2(Vector2(minf(a.x,b.x),a.y-2),Vector2(absf(b.x-a.x),4))
	for collider in PuzzlePhysics.colliders(player):
		var rect := SupportCarry.bounds(collider)
		rect.position+=point-player.global_position
		if rect.intersects(beam): return true
	return false
func regenerate_bolts() -> void:
	bolts.clear()
	if beam_start.distance_to(beam_end)<0.1: return
	var segments := maxi(1,int(ceil(beam_start.distance_to(beam_end)/5)))
	for branch in 2:
		var points := PackedVector2Array([beam_start])
		for i in range(1,segments):
			var point := beam_start.lerp(beam_end,float(i)/segments)
			point.y+=rng.randi_range(-2,2) if branch==0 else rng.randi_range(-3,3)
			points.append(point.round())
		points.append(beam_end)
		bolts.append(points)
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	update_endpoint()
	if not enabled:
		bolts.clear()
		queue_redraw()
		return
	animation_wait-=delta
	if bolts.is_empty() or (animation_wait<=0 and not Juice.reduced_motion) or not beam_end.is_equal_approx(previous_end) or not beam_start.is_equal_approx(previous_start):
		animation_wait=0.07
		previous_end=beam_end
		previous_start=beam_start
		regenerate_bolts()
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player and not player.noclip and touches_player(player,player.global_position): player.safety.return_to_ground()
	queue_redraw()
func draw_terminal(face: Vector2, facing: float) -> void:
	var left := face.x if facing>0 else face.x-4
	draw_rect(Rect2(left,face.y-6,4,12),beam_color.darkened(0.65))
	draw_rect(Rect2(left+0.5,face.y-5.5,3,11),beam_color,false,1)
	draw_rect(Rect2(left+(3 if facing>0 else 0),face.y-2,1,4),Color.WHITE if enabled else beam_color.darkened(0.5))
func _draw() -> void:
	var sign_x := 1 if direction==0 or has_meta("editor_beam_cells") else -1
	if Engine.is_editor_hint():
		draw_terminal(Vector2(-sign_x*4,0),sign_x)
		draw_dashed_line(Vector2(sign_x*5,0),Vector2(sign_x*32,0),Color(beam_color,0.5),1,3)
		return
	draw_terminal(source_face,sign_x)
	if hit_wall: draw_terminal(end_face,-sign_x)
	if not enabled: return
	for points in bolts:
		draw_polyline(points,Color(beam_color,0.10),7,false)
		draw_polyline(points,Color(beam_color,0.30),3,false)
		draw_polyline(points,beam_color if points==bolts[0] else Color(1,1,1,0.65),1,false)
