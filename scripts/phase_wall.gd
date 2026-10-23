@tool
extends StaticBody2D
## Solid for puzzle pieces (layer 8); transparent to the player's layer mask.
func _ready() -> void: add_to_group("phase_walls")
func wall_map() -> TileMapLayer:
	var node := get_parent()
	while node:
		var walls := node.get_node_or_null("Walls") as TileMapLayer
		if walls: return walls
		node=node.get_parent()
	return null
func edge_exposed(direction: Vector2) -> bool:
	for other in get_tree().get_nodes_in_group("phase_walls"):
		if other!=self and other.global_position.distance_to(global_position+direction*16)<0.2: return false
	var walls := wall_map()
	if walls:
		var cell := walls.local_to_map(walls.to_local(global_position+direction*16))
		if walls.get_cell_source_id(cell)>=0: return false
	return true
func _process(_delta: float) -> void: queue_redraw()
func _draw() -> void:
	if not is_inside_tree(): return
	for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
		if not edge_exposed(direction): continue
		for dash in range(0,16,4):
			var point := Vector2(-8+dash,-8 if direction.y<0 else 7) if direction.y!=0 else Vector2(-8 if direction.x<0 else 7,-8+dash)
			draw_rect(Rect2(point,Vector2(2,1) if direction.y!=0 else Vector2(1,2)),Color.WHITE)
