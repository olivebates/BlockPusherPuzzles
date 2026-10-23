extends Node2D
var player: CharacterBody2D
var nearest: Node2D
var key_canvas: Node2D
class KeyCanvas extends Node2D:
	var guide: Node2D
	func _draw() -> void:
		for link in guide.key_links(): DottedLinks.draw(self,to_local(link[0]),to_local(link[1]))
func _ready() -> void:
	z_index = -10
	key_canvas = KeyCanvas.new()
	key_canvas.guide = self
	key_canvas.z_index = 11
	add_child(key_canvas)
func platform_visible(platform: Node2D) -> bool:
	return get_viewport_rect().intersects(platform.get_global_transform_with_canvas()*Rect2(-8,-2,16,4))
func _process(_delta: float) -> void:
	player = get_tree().get_first_node_in_group("player")
	nearest = null
	if player:
		var distance := INF
		for platform in get_tree().get_nodes_in_group("recall_platforms"):
			platform.nearest = false
			if not platform.activated or not platform_visible(platform): continue
			var next_distance: float = player.global_position.distance_squared_to(platform.global_position)
			if next_distance < distance:
				distance = next_distance
				nearest = platform
		if nearest: nearest.nearest = true
		if Input.is_action_just_pressed("recall_player"): recall()
	queue_redraw()
	key_canvas.queue_redraw()
func recall() -> bool:
	return teleport_to(nearest)
func teleport_to(target: Node2D, require_visible := true) -> bool:
	player=get_tree().get_first_node_in_group("player") as CharacterBody2D
	if is_instance_valid(player) and not player.rotation_locks.is_empty(): return false
	if not is_instance_valid(player) or not is_instance_valid(target) or not target.activated: return false
	if require_visible and not platform_visible(target): return false
	var point: Vector2 = target.arrival_position()
	if not PuzzlePhysics.clear_at(player,point,[player.get_rid()]):
		Juice.sound("close")
		return false
	Juice.burst(player.global_position,Color("c1deef"),8)
	player.global_position = point
	player.velocity = Vector2.ZERO
	player.buffered=0
	player.coyote=0
	player.recall_freeze_frames=2
	player.force_update_transform()
	player.reset_physics_interpolation()
	Juice.burst(point,Color("c1deef"),8)
	Juice.sound("reset",0.9)
	return true
func key_links() -> Array:
	var links: Array = []
	if not is_instance_valid(player): return links
	for door in get_tree().get_nodes_in_group("doors"):
		var connected: Array[Node2D] = []
		var nearby: bool = player.global_position.distance_to(door.global_position)<=16
		for key in get_tree().get_nodes_in_group("pads"):
			if key.id==door.id and door.required_colors & (1<<key.block_color):
				connected.append(key)
				if player.global_position.distance_to(key.global_position)<=16: nearby = true
		if nearby:
			for key in connected: links.append([key.global_position,door.global_position])
	return links
