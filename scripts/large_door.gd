@tool
extends StaticBody2D
@export_range(1,100) var indicator_radius_tiles := 20
var opened := false
var openness := 0.0
func _ready() -> void:
	if not Engine.is_editor_hint(): add_to_group("large_doors")
func nearby_indicators() -> Array[Node2D]:
	var result: Array[Node2D]=[]
	for indicator in get_tree().get_nodes_in_group("collectible_indicators"):
		if global_position.distance_to(indicator.global_position)<=indicator_radius_tiles*16: result.append(indicator)
	return result
func restore_state() -> void:
	var indicators := nearby_indicators()
	opened=not indicators.is_empty()
	for indicator in indicators:
		if not indicator.lit: opened=false
	openness=1.0 if opened else 0.0
	$CollisionShape2D.set_deferred("disabled",opened)
	queue_redraw()
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	var indicators := nearby_indicators()
	var satisfied := not indicators.is_empty()
	for indicator in indicators:
		if not indicator.lit: satisfied=false
	if not satisfied and opened:
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape=$CollisionShape2D.shape
		query.transform=$CollisionShape2D.global_transform
		query.collision_mask=6
		if not get_world_2d().direct_space_state.intersect_shape(query).is_empty(): satisfied=true
	if satisfied!=opened:
		opened=satisfied
		$CollisionShape2D.set_deferred("disabled",opened)
		Juice.sound("open" if opened else "close",0.7)
		Juice.impact(0.7,global_position)
	openness=move_toward(openness,1.0 if opened else 0.0,delta/0.45)
	queue_redraw()
func _draw() -> void:
	var gold := Color("c6a765")
	draw_rect(Rect2(-16,-56,32,64),Color(gold,0.08))
	draw_rect(Rect2(-15.5,-55.5,31,63),gold.darkened(0.35),false,1)
	var width := 14.0*(1-openness)
	if width>0:
		for side in 2:
			var rect := Rect2(-14 if side==0 else 14-width,-54,width,60)
			draw_rect(rect,Color("33302a"))
			draw_rect(rect,gold,false,1)
			if width>4: draw_line(rect.position+Vector2(width/2,8),rect.position+Vector2(width/2,52),gold.darkened(0.4),1)

