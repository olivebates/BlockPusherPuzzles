extends CharacterBody2D
@export var character_name := StoryLines.PLAYER
const IDLE_SPRITE = preload("res://assets/playerSprite.png")
const RISING_SPRITE = preload("res://assets/playerSpriteJumpUp.png")
const FALLING_SPRITE = preload("res://assets/playerSpriteJumpDown.png")
@export var speed := 100.0
@export var acceleration := 850.0
@export var ground_friction := 1100.0
@export var gravity := 650.0
@export var jump_height := 40.0
var coyote := 0.0
var buffered := 0.0
var spawn_point: Vector2
var facing := 1.0
var recall_freeze_frames := 0
var show_recall_prompt := false
var recall_prompt_color := Color.WHITE
var noclip := false
var solid_layer := 2
var solid_mask := 5
var rotation_locks := {}
var safety: PlayerSafety
@onready var visual: Sprite2D = $Visual
func _ready() -> void:
	add_to_group("player")
	z_index=3
	spawn_point = global_position
	safety=PlayerSafety.new(self)
	# Recalled bodies must never inject teleport velocity into their rider.
	platform_floor_layers = 0
	platform_wall_layers = 0
	platform_on_leave = CharacterBody2D.PLATFORM_ON_LEAVE_DO_NOTHING
func _physics_process(delta: float) -> void:
	safety.lightning_grace=maxf(0,safety.lightning_grace-delta)
	if Dialogue.active:
		buffered=0
		return
	if not rotation_locks.is_empty():
		velocity=Vector2.ZERO
		buffered=0
		coyote=0
		return
	var flying := not OS.has_feature("web") and Input.is_physical_key_pressed(KEY_SHIFT)
	if flying != noclip:
		if flying:
			solid_layer = collision_layer
			solid_mask = collision_mask
		noclip = flying
		collision_layer = 0 if noclip else solid_layer
		collision_mask = 0 if noclip else solid_mask
		velocity = Vector2.ZERO
		buffered = 0
		coyote = 0
	if noclip:
		var direction := Vector2(float(noclip_key(KEY_D,KEY_RIGHT))-float(noclip_key(KEY_A,KEY_LEFT)),float(noclip_key(KEY_S,KEY_DOWN))-float(noclip_key(KEY_W,KEY_UP)))
		velocity = direction.normalized()*speed*3
		global_position += velocity*delta
		if direction.x != 0:
			facing = signf(direction.x)
			visual.flip_h = direction.x<0
		show_recall_prompt = false
		for actor in get_tree().get_nodes_in_group("blocks")+get_tree().get_nodes_in_group("spheres"):
			actor.recall_available = false
			actor.queue_redraw()
		visual.scale = Vector2.ONE
		visual.rotation = 0
		update_sprite()
		queue_redraw()
		return
	if recall_freeze_frames>0:
		recall_freeze_frames -= 1
		velocity = Vector2.ZERO
		return
	if safety.recover_embedded(): return
	var was_grounded := is_on_floor()
	var previous_fall := velocity.y
	coyote = 0.10 if was_grounded else maxf(0.0,coyote-delta)
	buffered = 0.12 if Input.is_action_just_pressed("jump") else maxf(0.0,buffered-delta)
	var axis := Input.get_axis("left","right")
	if axis != 0:
		facing = axis
		visual.flip_h = axis<0
	velocity.x = move_toward(velocity.x,axis*speed,(acceleration if axis != 0 else ground_friction)*delta*(1.0 if was_grounded else 0.7))
	if not was_grounded: velocity.y = minf(velocity.y+gravity*delta,280.0)
	if buffered > 0 and coyote > 0:
		velocity.y = -sqrt(2.0*gravity*jump_height)+gravity*delta*0.5
		buffered = 0
		coyote = 0
		visual.scale = Vector2(0.8,1.18)
		Juice.sound("jump")
		Juice.burst(global_position+Vector2(0,6),Color("b4e6ed"),5)
	if was_grounded and velocity.y>=0 and axis!=0: step_over_seam(velocity.x*delta)
	move_and_slide()
	update_sprite()
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var actor := collision.get_collider()
		if actor is Node and actor.is_in_group("blocks") and absf(collision.get_normal().x)>0.9:
			# Keep the player's side outside the shared tile edge. Physics contact
			# tolerance must not leave them tucked beneath an adjacent ceiling tile.
			for player_shape in PuzzlePhysics.colliders(self):
				var player_rect := SupportCarry.bounds(player_shape)
				for block_shape in PuzzlePhysics.colliders(actor):
					var block_rect := SupportCarry.bounds(block_shape)
					if player_rect.end.y<=block_rect.position.y or player_rect.position.y>=block_rect.end.y: continue
					var safe_x: float
					if collision.get_normal().x<0:
						safe_x=block_rect.position.x-safe_margin-0.02-(player_rect.end.x-global_position.x)
					else:
						safe_x=block_rect.end.x+safe_margin+0.02+(global_position.x-player_rect.position.x)
					if absf(safe_x-global_position.x)<0.5: global_position.x=safe_x
		if actor is Node and actor.is_in_group("spheres"): actor.touch(-collision.get_normal())
	if is_on_floor() and not was_grounded and previous_fall > 40:
		visual.scale = Vector2(1.28,0.72)
		Juice.sound("land")
		Juice.burst(global_position+Vector2(0,6),Color("c3edf1"),7)
		Juice.impact(minf(previous_fall/160.0,1.4),global_position)
	visual.scale = visual.scale.lerp(Vector2.ONE,1-exp(-16*delta))
	visual.rotation = lerpf(visual.rotation,axis*0.045,1-exp(-12*delta))
	visual.material.set_shader_parameter("energy",minf(absf(velocity.y)/210.0,1.0))
	var block := touching_block(axis)
	# A real side contact permits pushing even if this same welded body is
	# underfoot. Nearby wall/floor contacts alone must never trigger a push.
	if block != null and was_grounded and is_on_floor() and axis != 0 and has_push_contact(block,axis) and absf(block.global_position.y-global_position.y) < 14 and absf(block.global_position.x-global_position.x) > 10 and signf(block.global_position.x-global_position.x) == axis:
		block.try_push(axis,delta,block)
	safety.record_ground()
	update_recall_target()
	var scene := get_tree().current_scene
	if scene and global_position.y > scene.get_meta("fall_limit",480): respawn()
func noclip_key(first: Key, second: Key) -> bool:
	return Input.is_physical_key_pressed(first) or Input.is_physical_key_pressed(second)
func has_push_contact(block: Node2D, direction: float) -> bool:
	var supported := false
	for collider in PuzzlePhysics.colliders(self):
		var rect := SupportCarry.bounds(collider)
		for x in [rect.position.x+0.2,rect.get_center().x,rect.end.x-0.2]:
			var hit := safety.floor_hit(Vector2(x,global_position.y))
			if not hit.is_empty() and hit.normal.y< -0.7: supported=true
	if not supported: return false
	for i in get_slide_collision_count():
		var contact := get_slide_collision(i)
		var actor := contact.get_collider()
		if actor is Node and actor.is_in_group("blocks") and actor.leader==block.leader and contact.get_normal().x*direction< -0.9: return true
	return false
func update_sprite() -> void:
	visual.texture = RISING_SPRITE if velocity.y < -0.1 else FALLING_SPRITE if velocity.y > 0.1 and (noclip or not is_on_floor()) else IDLE_SPRITE
func step_over_seam(distance: float) -> void:
	var collision := KinematicCollision2D.new()
	if not test_move(global_transform,Vector2(distance,0),collision): return
	var wall := absf(collision.get_normal().x)>0.9
	if not wall or test_move(global_transform,Vector2(0,-1)): return
	var raised := global_transform
	raised.origin.y -= 1
	if not test_move(raised,Vector2(distance,0)): global_position.y -= 1
func touching_block(direction := 0.0) -> Node2D:
	for block in get_tree().get_nodes_in_group("blocks"):
		var gap: Vector2 = (block.global_position-global_position).abs()
		if direction!=0 and (gap.y>=14 or gap.x<=10 or signf(block.global_position.x-global_position.x)!=direction): continue
		if direction!=0:
			# A floor contact must never become a side push through rounding
			# at the shared tile edge, even when another box is beside us.
			var overlap := false
			for collider in PuzzlePhysics.colliders(self):
				var rect := SupportCarry.bounds(collider)
				if minf(rect.end.y,block.global_position.y+8)-maxf(rect.position.y,block.global_position.y-8)>0.5: overlap=true
			if not overlap: continue
		if (gap.x <= 14 and gap.y < 14) or (gap.x < 12 and gap.y <= 16): return block
	return null
func respawn() -> void:
	global_position = spawn_point
	velocity = Vector2.ZERO
	Juice.sound("reset")
	Juice.burst(global_position,Color.WHITE)
func recall_distance(point: Vector2) -> float:
	# Minkowski rectangle: normal side/top contact plus five extra pixels.
	var gap := (point-global_position).abs()
	return Vector2(maxf(gap.x-13,0),maxf(gap.y-15,0)).length()
func update_recall_target() -> Node2D:
	var closest: Node2D
	var distance := INF
	show_recall_prompt = false
	var actors := get_tree().get_nodes_in_group("blocks")+get_tree().get_nodes_in_group("spheres")
	for actor in actors:
		actor.recall_available = false
		var at_home: bool = actor.global_position.distance_to(actor.home)<0.2
		if actor.is_in_group("blocks"):
			at_home = actor.leader.is_at_home()
			if at_home: continue
		var next_distance := minf(recall_distance(actor.global_position),recall_distance(actor.home))
		var priority := next_distance+(1000.0 if at_home else 0.0)
		if next_distance <= 5.0 and priority < distance:
			distance = priority
			closest = actor
	if closest:
		var home_gap: Vector2 = (closest.home-global_position).abs()
		show_recall_prompt = home_gap.x<13 and home_gap.y<15
		if closest.is_in_group("blocks"):
			for member in closest.leader.members: member.recall_available = true
			recall_prompt_color = Color.WHITE
			var gap: Vector2 = (closest.global_position-global_position).abs()
			show_recall_prompt = closest.leader.side_blocked() and ((gap.x<=14 and gap.y<=16) or show_recall_prompt)
		else:
			closest.recall_available = true
			recall_prompt_color = Color.WHITE
		var at_home: bool = closest.global_position.distance_to(closest.home)<0.2
		if closest.is_in_group("blocks"): at_home = closest.leader.is_at_home()
		if at_home:
			show_recall_prompt = false
			if closest.is_in_group("blocks"):
				for member in closest.leader.members: member.recall_available = false
			else: closest.recall_available = false
		if Input.is_action_just_pressed("reset_block"): closest.reset_home()
	for actor in actors: actor.queue_redraw()
	queue_redraw()
	return closest
func _draw() -> void:
	var font := ThemeDB.fallback_font
	if show_recall_prompt:
		var text := InputBindings.prompt("reset_block")
		var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x
		draw_string(font,Vector2(-width/2,-14),text,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.WHITE)
	var hint := map_hint()
	if not hint.is_empty():
		var width := font.get_string_size(hint,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x
		draw_string(font,Vector2(-width/2,-26 if show_recall_prompt else -14),hint,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("ffd433"))
func map_hint() -> String:
	if Progress.map_hint_stage not in [1,2]: return ""
	return InputBindings.prompt("map").to_upper()+(" - Teleport" if Progress.map_hint_stage==2 else "")

