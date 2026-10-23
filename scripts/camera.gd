extends Camera2D
var trauma := 0.0
var look := Vector2.ZERO
var player: Node2D
var level_bounds := Vector2(960,544)
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	add_to_group("game_camera")
	player = get_tree().get_first_node_in_group("player")
	if player: global_position = player.global_position
func _process(delta: float) -> void:
	if get_tree().paused:
		trauma=0
		offset=Vector2.ZERO
		zoom=Vector2(2,2)
		get_tree().call_group("post_fx","set_impact",0.0)
		return
	if not is_instance_valid(player): return
	var target_look := Vector2(player.facing*28,clampf(player.velocity.y*0.13,-12,25))
	if Input.is_action_pressed("down"): target_look.y += 35
	look = look.lerp(target_look,1-exp(-3*delta))
	var target: Vector2 = player.global_position+look
	if absf(target.y-global_position.y) < 18: target.y = global_position.y
	global_position = global_position.lerp(target,1-exp(-6*delta))
	trauma = move_toward(trauma,0,delta*5)
	offset = Vector2(randf_range(-1,1),randf_range(-1,1))*trauma*0.5 if trauma>0 else Vector2.ZERO
	zoom = Vector2(2,2)
	get_tree().call_group("post_fx","set_impact",trauma)
func bump(strength: float) -> void:
	trauma = maxf(trauma,clampf(strength,0,0.75))
