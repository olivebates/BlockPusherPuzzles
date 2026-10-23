@tool
extends CharacterBody2D
@export_range(8,240,1) var speed := 48.0
const YELLOW := Color(1,0.83,0.2)
var home: Vector2
var leader: CharacterBody2D
var members: Array[Node2D]=[]
var weld_offset := Vector2.ZERO
var next_direction := 1
var direction := 1
var moving := false
var was_player_on := false
class JoinedOutline extends Node2D:
	func _draw() -> void:
		var body := get_parent()
		if body.leader!=body: return
		var offsets: Array[Vector2]=[]
		for member in body.members: offsets.append(member.weld_offset)
		for contour in WeldOutline.contours(offsets): draw_polyline(contour,Color("705518"),1,false)
func _ready() -> void:
	if Engine.is_editor_hint(): return
	add_to_group("elevators")
	home=global_position
	leader=self
	members=[self]
	platform_floor_layers=0
	platform_wall_layers=0
	var outline := JoinedOutline.new()
	outline.z_index=1
	add_child(outline)
	call_deferred("fuse_neighbors")
func fuse_neighbors() -> void:
	if leader!=self: return
	var changed := true
	while changed:
		changed=false
		for other in get_tree().get_nodes_in_group("elevators"):
			if other==self or other.leader!=other: continue
			var touching := false
			for member in members:
				for candidate in other.members:
					var gap: Vector2=(member.home-candidate.home).abs()
					if (absf(gap.x-16)<0.2 and gap.y<0.2) or (absf(gap.y-16)<0.2 and gap.x<0.2): touching=true
			if not touching: continue
			for member in other.members.duplicate():
				member.leader=self
				member.weld_offset=member.home-home
				member.set_physics_process(false)
				for shape in PuzzlePhysics.colliders(member): shape.disabled=true
				members.append(member)
			changed=true
	for member in members:
		if member==self: continue
		var shape := CollisionShape2D.new()
		shape.shape=$CollisionShape2D.shape
		shape.position=member.weld_offset
		add_child(shape)
	sync_members()
func sync_members() -> void:
	for member in members:
		if member!=self: member.global_position=global_position+member.weld_offset
		member.queue_redraw()
	for child in get_children():
		if child is JoinedOutline: child.queue_redraw()
func convoy() -> Array[CharacterBody2D]:
	var bodies := SupportCarry.convoy(self)
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player and not player.noclip and player.velocity.y>=0:
		for body in bodies:
			if SupportCarry.supports(body,player):
				bodies.append(player)
				break
	return bodies
func body_rids() -> Array[RID]:
	var result: Array[RID]=[]
	for member in members: result.append(member.get_rid())
	return result
func travel_distance(sign_y: int, bodies: Array[CharacterBody2D]) -> float:
	var distance := BlockFall.axis_distance(self,Vector2(0,sign_y*8192),bodies)
	if sign_y<0 and distance<8192: distance=maxf(0,distance-16)
	return distance
func start() -> bool:
	var bodies := convoy()
	direction=next_direction
	if travel_distance(direction,bodies)<0.2: direction*=-1
	if travel_distance(direction,bodies)<0.2: return false
	next_direction=-direction
	moving=true
	velocity=Vector2.ZERO
	Juice.sound("push",0.8)
	return true
func stop(bodies: Array[CharacterBody2D]) -> void:
	moving=false
	velocity=Vector2.ZERO
	var grid_y := home.y+roundf((global_position.y-home.y)/16)*16
	if absf(grid_y-global_position.y)<0.25: SupportCarry.move(self,Vector2(0,grid_y-global_position.y),bodies)
	sync_members()
	Juice.sound("land",0.7)
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or leader!=self: return
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	var player_on: bool=player!=null and not player.noclip and player.velocity.y>=0 and SupportCarry.supports(self,player)
	if player_on and not was_player_on and not moving: start()
	was_player_on=player_on
	if not moving: return
	var bodies := convoy()
	var distance := travel_distance(direction,bodies)
	if distance<0.15:
		stop(bodies)
		return
	var target_speed := minf(speed,sqrt(2*180*distance))
	velocity.y=move_toward(velocity.y,direction*target_speed,180*delta)
	var motion := Vector2(0,direction*minf(absf(velocity.y)*delta,distance))
	var blocked := SupportCarry.move(self,motion,bodies)
	sync_members()
	if blocked:
		stop(bodies)
func _draw() -> void:
	draw_rect(Rect2(-8,-8,16,16),YELLOW)
	if Engine.is_editor_hint(): draw_rect(Rect2(-7.5,-7.5,15,15),Color("705518"),false,1)
