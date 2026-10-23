class_name SupportCarry
extends RefCounted
## Treat a support and its recursively supported boxes as a collision-checked convoy.
static func bounds(collider: CollisionShape2D) -> Rect2:
	return collider.global_transform*collider.shape.get_rect()
static func supports(base: CharacterBody2D, rider: CharacterBody2D) -> bool:
	for lower in PuzzlePhysics.colliders(base):
		var base_rect := bounds(lower)
		for upper in PuzzlePhysics.colliders(rider):
			var rider_rect := bounds(upper)
			if rider_rect.end.x<=base_rect.position.x+0.1 or rider_rect.position.x>=base_rect.end.x-0.1: continue
			var surface_y := base_rect.position.y
			if lower.shape is CircleShape2D:
				var radius: float = lower.shape.radius
				var dx := clampf(lower.global_position.x,rider_rect.position.x,rider_rect.end.x)-lower.global_position.x
				if absf(dx)>=radius: continue
				surface_y = lower.global_position.y-sqrt(radius*radius-dx*dx)
			if absf(rider_rect.end.y-surface_y)<=0.7 and rider_rect.get_center().y<base_rect.get_center().y: return true
	return false
static func convoy(base: CharacterBody2D) -> Array[CharacterBody2D]:
	var result: Array[CharacterBody2D] = [base]
	var candidates: Array[CharacterBody2D] = []
	for block in base.get_tree().get_nodes_in_group("blocks"):
		if block.leader==block: candidates.append(block)
	for sphere in base.get_tree().get_nodes_in_group("spheres"): candidates.append(sphere)
	var index := 0
	while index<result.size():
		for candidate in candidates:
			if not result.has(candidate) and supports(result[index],candidate): result.append(candidate)
		index += 1
	return result
static func push_convoy(base: CharacterBody2D, motion: Vector2) -> Array[CharacterBody2D]:
	var required: Array[CharacterBody2D] = [base]
	var index := 0
	while index<required.size():
		for candidate in base.get_tree().get_nodes_in_group("blocks"):
			if candidate.leader!=candidate or required.has(candidate): continue
			if side_contact(required[index],candidate,motion.x): required.append(candidate)
		index += 1
	var bodies: Array[CharacterBody2D] = []
	for body in required:
		for rider in convoy(body):
			if not bodies.has(rider): bodies.append(rider)
	# Test the entire tile before starting the animation, so obstructed riders
	# stay in their original column rather than moving partway off the grid.
	var changed := true
	while changed:
		changed = false
		for body in bodies.duplicate():
			if required.has(body): continue
			var single: Array[CharacterBody2D] = [body]
			var supported := false
			for support in bodies:
				if support != body and supports(support,body): supported = true
			if not supported or safe_fraction(single,motion,bodies)<0.999:
				bodies.erase(body)
				changed = true
	return bodies
static func side_contact(base: CharacterBody2D, other: CharacterBody2D, direction: float) -> bool:
	for lower in PuzzlePhysics.colliders(base):
		var a := bounds(lower)
		for upper in PuzzlePhysics.colliders(other):
			var b := bounds(upper)
			if minf(a.end.y,b.end.y)-maxf(a.position.y,b.position.y)<=0.2: continue
			var gap := b.position.x-a.end.x if direction>0 else a.position.x-b.end.x
			if gap>=-0.1 and gap<=0.4: return true
	return false
static func safe_fraction(bodies: Array[CharacterBody2D], motion: Vector2, ignored: Array[CharacterBody2D] = []) -> float:
	for body in bodies:
		if body.is_in_group("blocks") and body.rotating: return 0.0
	if motion.length_squared()<0.0000001: return 1.0
	# Body motion tests preserve Godot's one-way-platform rules. Temporarily
	# ignore convoy members, then restore exactly the exceptions we added.
	var exceptions: Array = []
	if ignored.is_empty(): ignored = bodies
	for body in bodies:
		for other in ignored:
			if body!=other and not body.get_collision_exceptions().has(other):
				body.add_collision_exception_with(other)
				exceptions.append([body,other])
	var fraction := 1.0
	for body in bodies:
		if body.is_in_group("blocks") or body.is_in_group("elevators"):
			fraction=minf(fraction,BlockFall.axis_distance(body,motion,ignored)/motion.length())
			continue
		var collision := KinematicCollision2D.new()
		if body.test_move(body.global_transform,motion,collision,0.0):
			fraction = minf(fraction,clampf(collision.get_travel().dot(motion)/motion.length_squared(),0,1))
	for pair in exceptions: pair[0].remove_collision_exception_with(pair[1])
	return fraction
static func can_move(base: CharacterBody2D, motion: Vector2) -> bool:
	return safe_fraction(convoy(base),motion)>=0.999
static func move(base: CharacterBody2D, motion: Vector2, bodies: Array[CharacterBody2D] = []) -> bool:
	if bodies.is_empty(): bodies = convoy(base)
	var fraction := safe_fraction(bodies,motion)
	var travel := motion*fraction
	for body in bodies:
		body.global_position += travel
		body.force_update_transform()
		if body!=base:
			if body.is_in_group("player"):
				body.velocity.y=0
				continue
			body.carried_frame = Engine.get_physics_frames()
			body.velocity = Vector2.ZERO
			if body.is_in_group("blocks"):
				body.resting_x = body.global_position.x
				if body.sliding:
					body.slide_from += travel
					body.slide_to += travel
				body.has_moved = true
		if body.is_in_group("blocks"): body.sync_members()
	return fraction<0.999
