@tool
extends CharacterBody2D
@export var block_color: PuzzlePalette.Hue = PuzzlePalette.Hue.CYAN:
	set(value):
		block_color = value
		queue_redraw()
@export var push_delay := 0.2
@export var slide_duration := 0.15
var home: Vector2
var charge := 0.0
var last_push_frame := -100
var pushing_direction := 0.0
var sliding := false
var push_riders: Array[CharacterBody2D] = []
var slide_from: Vector2
var slide_to: Vector2
var slide_time := 0.0
var flash := 0.0
var recall_available := false
var leader: CharacterBody2D
var members: Array[Node2D] = []
var weld_offset := Vector2.ZERO
var portal_locked := false
var has_moved := false
var on_key_tile := false
var recall_freeze_frames := 0
var resting_x := 0.0
var carried_frame := -1
var supported_by_player := false
var grounded := false
var supporting_member: Node2D
var push_contact: Node2D
var home_marker: Node2D
var automatic_recall_wait := 0.0
var rotating := false
var rotation_controller: Node2D
var outline: Node2D
func _ready() -> void:
	if Engine.is_editor_hint(): return
	add_to_group("blocks")
	safe_margin=0
	floor_snap_length=0
	collision_mask|=8
	home = global_position
	resting_x = home.x
	platform_floor_layers = 0
	platform_wall_layers = 0
	platform_on_leave = CharacterBody2D.PLATFORM_ON_LEAVE_DO_NOTHING
	var ghost := Node2D.new()
	home_marker = ghost
	ghost.set_script(load("res://scripts/home_outline.gd"))
	ghost.set("hue",block_color)
	ghost.position = home
	get_parent().add_child.call_deferred(ghost)
	leader = self
	members = [self]
	outline = WeldOutline.new()
	outline.z_index = 1
	add_child(outline)
	call_deferred("weld_start_neighbors")
func weld_start_neighbors() -> void:
	if leader != self: return
	var found := true
	while found:
		found = false
		for other in get_tree().get_nodes_in_group("blocks"):
			if other.leader != other or other == self or other.block_color != block_color: continue
			var touching := false
			for member in members:
				for candidate in other.members:
					var gap: Vector2 = (member.home-candidate.home).abs()
					if (absf(gap.x-16)<0.2 and gap.y<0.2) or (absf(gap.y-16)<0.2 and gap.x<0.2): touching = true
			if not touching: continue
			for candidate in other.members.duplicate():
				candidate.leader = self
				candidate.weld_offset = candidate.home-home
				candidate.set_physics_process(false)
				candidate.get_node("CollisionShape2D").disabled = true
				var collider := CollisionShape2D.new()
				collider.shape = candidate.get_node("CollisionShape2D").shape
				collider.position = candidate.weld_offset
				add_child(collider)
				members.append(candidate)
			# Transfer only the original per-tile shapes, never old compound shapes.
			for collider in other.get_children():
				if collider is CollisionShape2D and collider.name != "CollisionShape2D": collider.disabled = true
			found = true
func sync_members() -> void:
	for member in members:
		if member != self:
			member.global_position = global_position+member.weld_offset
			member.sliding = sliding
			member.flash = flash
		if member.material: member.material.set_shader_parameter("energy",maxf(flash,charge/push_delay))
		member.queue_redraw()
	if is_instance_valid(outline): outline.queue_redraw()
func rebuild_weld_shapes() -> void:
	for collider in get_children():
		if collider is CollisionShape2D and collider.name!="CollisionShape2D": collider.free()
	for member in members:
		if member==self: continue
		var collider := CollisionShape2D.new()
		collider.shape=$CollisionShape2D.shape
		collider.position=member.weld_offset
		add_child(collider)
func spark_corner() -> Vector2:
	var corner := global_position+Vector2(pushing_direction*7,7)
	for member in members:
		var candidate: Vector2 = global_position+member.weld_offset+Vector2(pushing_direction*7,7)
		if candidate.y > corner.y+0.1 or (absf(candidate.y-corner.y)<0.1 and candidate.x*pushing_direction>corner.x*pushing_direction): corner = candidate
	return corner
func body_rids() -> Array[RID]:
	var result: Array[RID] = []
	for member in members: result.append(member.get_rid())
	return result
func rotation_pivot_member() -> Node2D:
	if leader!=self: return leader.rotation_pivot_member()
	var center := Vector2.ZERO
	for member in members: center+=member.weld_offset
	center/=members.size()
	var chosen: Node2D=members[0]
	for member in members:
		if member.weld_offset.distance_squared_to(center)<chosen.weld_offset.distance_squared_to(center)-0.01: chosen=member
	return chosen
func side_blocked() -> bool:
	for direction in [-1,1]:
		if BlockFall.axis_distance(self,Vector2(direction*16,0),[],13)<15.999: return true
	return false
func _draw() -> void:
	var color := PuzzlePalette.color_for(block_color)
	if recall_available: color = color.lightened(0.42)
	preload("res://scripts/puzzle_art.gd").draw_block(self,color,on_key_tile)
	if Engine.is_editor_hint():
		draw_rect(Rect2(-7.5,-7.5,15,15),color,false,1)
		WeldOutline.draw_pivot(self,Vector2.ZERO)
	var owner_charge: float = leader.charge if is_instance_valid(leader) else charge
	if owner_charge > 0 and is_instance_valid(leader) and leader.push_contact==self: draw_circle(Vector2.ZERO,10*maxf(0,1-owner_charge/leader.push_delay),Color(color,0.65))
	if flash > 0: draw_rect(Rect2(-8,-8,16,16),Color(1,1,1,flash*0.6))
func welded_neighbor(direction: Vector2) -> bool:
	if not is_instance_valid(leader): return false
	for member in leader.members:
		if member!=self and (member.weld_offset-weld_offset-direction*16).length()<0.2: return true
	return false
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if rotating: return
	if automatic_recall_wait>0:
		automatic_recall_wait = maxf(0,automatic_recall_wait-delta)
		velocity = Vector2.ZERO
		return
	if carried_frame==Engine.get_physics_frames():
		velocity = Vector2.ZERO
		sync_members()
		for member in members: member.update_key_tile()
		return
	if recall_freeze_frames>0:
		recall_freeze_frames -= 1
		velocity = Vector2.ZERO
		sync_members()
		return
	# Explicit script/editor teleports may change the resting column. Recovery
	# inside move_and_slide below may not.
	if not sliding and absf(global_position.x-resting_x)>0.001: resting_x = global_position.x
	flash = move_toward(flash,0,delta*4)
	if material: material.set_shader_parameter("energy",maxf(flash,charge/push_delay))
	if Engine.get_physics_frames()-last_push_frame > 1: charge = 0
	if sliding:
		var next_time := minf(slide_time+delta,slide_duration)
		var fraction := minf(next_time/slide_duration,1)
		var target := slide_from.lerp(slide_to,fraction*fraction*(3-2*fraction))
		# Recheck a push that has not moved yet: a new neighboring box may
		# have arrived since the charge finished and now needs to move too.
		if global_position.distance_squared_to(slide_from)<0.000001:
			push_riders=SupportCarry.push_convoy(self,slide_to-global_position)
		var blocked := SupportCarry.move(self,target-global_position,push_riders)
		# A changing obstacle can interrupt an already accepted push. Keep
		# its original tile target and animation time rather than discarding
		# the charge, reporting success, or requiring another push animation.
		if not blocked: slide_time=next_time
		if not blocked and fraction >= 1:
			sliding = false
			resting_x = global_position.x
			Juice.sound("push")
			Juice.push_sparks(spark_corner(),PuzzlePalette.color_for(block_color),pushing_direction)
			Juice.impact(0.55,global_position)
			Juice.block_pushed.emit()
	else:
		var was_floor := grounded or supported_by_player
		var fall_speed := velocity.y
		velocity.x = 0
		velocity.y = minf(velocity.y+650*delta,280)
		var support_y := player_support_y()
		supported_by_player = is_finite(support_y) and global_position.y+velocity.y*delta+floor_snap_length>=support_y
		if supported_by_player:
			velocity.y = maxf(0,(support_y-global_position.y)/delta)
		if not supported_by_player or absf(global_position.y-support_y)>0.2:
			# Head support is resolved on the grid above. Native corner recovery
			# against the player's sides must not arrest a vertical fall.
			var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
			var ignore_player := player!=null and not get_collision_exceptions().has(player)
			if ignore_player: add_collision_exception_with(player)
			var desired := maxf(0,velocity.y*delta)
			var travel := BlockFall.floor_distance(self,desired+BlockFall.EPSILON)
			grounded=travel<=desired
			global_position.y+=minf(desired,travel)
			force_update_transform()
			if grounded:
				var floor_y := global_position.y
				move_and_slide()
				global_position.y=floor_y
				velocity.y=0
			if ignore_player: remove_collision_exception_with(player)
		else: grounded=false
		if supported_by_player and absf(global_position.y-support_y)<0.2:
			global_position.y = support_y
			velocity.y = 0
		# Vertical settling must not let collision recovery nudge a box sideways.
		global_position.x = resting_x
		if grounded:
			var tile_y := home.y+roundf((global_position.y-home.y)/16)*16
			# Keep the exact support height. Snapping a fractional spawn offset
			# back above the floor can drop grounded contact and reset push charge.
			if absf(global_position.y-tile_y)<BlockFall.EPSILON: global_position.y = tile_y
		if (grounded or supported_by_player) and not was_floor and fall_speed > 40:
			Juice.sound("land",0.8)
			Juice.impact(0.8,global_position)
			Juice.burst(global_position+Vector2(0,7),PuzzlePalette.color_for(block_color),8)
	var scene := get_tree().current_scene
	if scene and global_position.y > scene.get_meta("fall_limit",480):
		if not reset_home(true): automatic_recall_wait = 0.5
	sync_members()
	check_portals()
	for member in members: member.update_key_tile()
	queue_redraw()
func player_support_y() -> float:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if not player or player.noclip: return INF
	if supported_by_player and is_instance_valid(supporting_member):
		var gap: Vector2 = player.global_position-supporting_member.global_position
		# A jump beneath the box must not restart its gravity or lift it off-grid.
		if overlaps_player_horizontally(supporting_member,player) and gap.y>=0 and gap.y<=18.2: return global_position.y
	var target := INF
	supporting_member = null
	for member in members:
		if not overlaps_player_horizontally(member,player): continue
		if member.global_position.y+8>player.global_position.y-7+0.2: continue
		var tile_y: float = member.home.y+floorf((player.global_position.y-14.9-member.home.y)/16)*16
		var leader_y: float = tile_y-member.weld_offset.y
		if leader_y>=global_position.y-0.2 and leader_y<target:
			target = leader_y
			supporting_member = member
	return target
func overlaps_player_horizontally(member: Node2D, player: CharacterBody2D) -> bool:
	# Only actual overlap can support a falling box. The wider interaction
	# distance also includes players standing beside its collision shape.
	for collider in PuzzlePhysics.colliders(player):
		var rect := SupportCarry.bounds(collider)
		if minf(member.global_position.x+8,rect.end.x)-maxf(member.global_position.x-8,rect.position.x)>0.25: return true
	return false
func update_key_tile() -> void:
	on_key_tile = false
	for pad in get_tree().get_nodes_in_group("pads"):
		if pad.block_color == block_color and global_position.distance_to(pad.global_position)<2 and is_settled():
			on_key_tile = true
			break
	queue_redraw()
func is_settled() -> bool:
	var body: CharacterBody2D = leader if is_instance_valid(leader) else self
	return not body.rotating and not body.sliding and Engine.get_physics_frames()-body.carried_frame>1
func try_push(direction: float, delta: float, contact: Node2D = null) -> void:
	if leader != self:
		leader.try_push(direction,delta,self if contact==null else contact)
		return
	if rotating or sliding or not (grounded or supported_by_player): return
	if contact==null: contact = self
	if direction != pushing_direction or push_contact!=contact: charge = 0
	push_contact = contact
	pushing_direction = direction
	last_push_frame = Engine.get_physics_frames()
	charge = minf(charge+delta,push_delay)
	if charge < push_delay-0.000001: return
	var motion := Vector2(direction*16,0)
	push_riders = SupportCarry.push_convoy(self,motion)
	if SupportCarry.safe_fraction(push_riders,motion)<0.999: return
	# A blocked frame must not consume the attempt. Keep the charge ready
	# until movement can actually start or the player stops pushing.
	charge = 0
	slide_from = global_position
	slide_to = global_position+motion
	slide_time = 0
	sliding = true
	has_moved = true
	velocity = Vector2.ZERO
	flash = 0.4
func is_at_home() -> bool:
	if leader!=self: return leader.is_at_home()
	for member in members:
		if member.global_position.distance_to(member.home)>0.1 or absf(member.rotation)>0.001: return false
	return true
func has_rotated_pose() -> bool:
	if absf(rotation)>0.001: return true
	for member in members:
		if member.weld_offset.distance_to(member.home-home)>0.01: return true
	return false
func reset_home(automatic := false) -> bool:
	if leader != self:
		return leader.reset_home(automatic)
	if not automatic and is_at_home(): return false
	# Capture the rider before restoring the collision shapes. Otherwise a
	# player standing on a rotated arm can disappear from the support test.
	var rider_state := -1
	var destination_pivot := Vector2.INF
	if has_rotated_pose():
		var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
		rider_state=1 if player and SupportCarry.supports(self,player) else 0
		destination_pivot=rotation_pivot_member().home
	if is_instance_valid(rotation_controller): rotation_controller.cancel()
	var previous := global_position
	var old_offsets: Array[Vector2]=[]
	for member in members:
		old_offsets.append(member.weld_offset)
		member.weld_offset=member.home-home
	rebuild_weld_shapes()
	if not PuzzlePhysics.teleport(self,home,body_rids(),rider_state,destination_pivot):
		for i in members.size(): members[i].weld_offset=old_offsets[i]
		rebuild_weld_shapes()
		if not automatic:
			for member in members:
				if is_instance_valid(member.home_marker): member.home_marker.flash_failure()
			Juice.sound("reject")
		return false
	if not automatic: Juice.burst(previous,PuzzlePalette.color_for(block_color),16)
	velocity = Vector2.ZERO
	sliding = false
	charge = 0
	flash = 0 if automatic else 1
	resting_x = home.x
	portal_locked = true
	has_moved = false
	supported_by_player = false
	grounded=false
	supporting_member = null
	push_contact = null
	automatic_recall_wait = 0
	sync_members()
	if not automatic:
		Juice.burst(home,PuzzlePalette.color_for(block_color),20)
		Juice.sound("reset")
		Juice.impact(1,home)
		Juice.block_pushed.emit()
	return true
func check_portals() -> void:
	if not has_moved or not is_settled(): return
	var on_portal := false
	for portal in get_tree().get_nodes_in_group("symbol_portals"):
		for member in members:
			if member.global_position.distance_to(portal.global_position) < 2:
				on_portal = true
				if not sliding and not portal_locked: portal.transport(self,member)
	if not on_portal: portal_locked = false
