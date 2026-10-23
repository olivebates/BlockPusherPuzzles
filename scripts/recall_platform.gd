@tool
extends StaticBody2D
var nearest := false
var glow := 0.0
var activated := false
var placed_position := Vector2.ZERO
var snap_attempts := 3
func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("recall_platforms")
		placed_position = position
		call_deferred("snap_to_floor")
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	if snap_attempts>0:
		snap_attempts -= 1
		snap_to_floor()
func snap_to_floor() -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position+Vector2(0,-2),global_position+Vector2(0,32768),1)
	var excluded: Array[RID] = []
	for platform in get_tree().get_nodes_in_group("recall_platforms"): excluded.append(platform.get_rid())
	query.exclude = excluded
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.y>-0.5: return false
	var target_y: float = hit.position.y-2
	if target_y<global_position.y-0.1: return false
	global_position.y = target_y
	force_update_transform()
	return true
func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		if activation_rect().intersects(Rect2(player.global_position-Vector2(5,7),Vector2(10,14))) and not player.noclip: activated = true
	glow = move_toward(glow,1.0 if nearest else 0.0,delta*5)
	queue_redraw()
func activation_rect() -> Rect2:
	var top := global_position.y-32768
	# Check the whole column, so even a partial ceiling stops the activation area.
	for column in [-7.9,0,7.9]:
		var query := PhysicsRayQueryParameters2D.create(global_position+Vector2(column,-2.1),global_position+Vector2(column,-32768),1)
		query.exclude = [get_rid()]
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): top = maxf(top,hit.position.y)
	return Rect2(Vector2(global_position.x-8,top),Vector2(16,maxf(0,global_position.y-2-top)))
func arrival_position() -> Vector2:
	return global_position+Vector2(0,-9.2)
func _draw() -> void:
	draw_rect(Rect2(-8,-2,16,4),Color("7d8da4"))
	draw_line(Vector2(-7,-2),Vector2(7,-2),Color("e4f4ff"),1)
	if glow > 0:
		for row in 28:
			var strength := (1-float(row)/28)*glow
			draw_line(Vector2(-7-row*0.12,-3-row),Vector2(7+row*0.12,-3-row),Color(0.65,0.87,1,strength*0.22),1)
	if nearest and not Engine.is_editor_hint():
		var text := InputBindings.prompt("recall_player")
		var font := ThemeDB.fallback_font
		var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x
		draw_string(font,Vector2(-width/2,-12),text,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.WHITE)
