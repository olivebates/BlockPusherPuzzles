class_name PuzzleOccupancy
extends RefCounted
## Share a small spatial index across key/block queries instead of scanning
## every object for every tile. Moving/adding/removing objects invalidates it.
static func invalidate(node: Node, group: String) -> void:
	var tree := node.get_tree()
	var key := "_puzzle_occupancy_"+group
	if tree and tree.has_meta(key): tree.remove_meta(key)

static func nearby(node: Node2D, group: String) -> Array[Node2D]:
	var tree := node.get_tree()
	var key := "_puzzle_occupancy_"+group
	var cache: Dictionary=tree.get_meta(key,{})
	var physics := Engine.get_physics_frames()
	var process := Engine.get_process_frames()
	if cache.get("physics",-1)!=physics or cache.get("process",-1)!=process:
		var grid := {}
		for item in tree.get_nodes_in_group(group):
			var cell := Vector2i((item.global_position/16).floor())
			if not grid.has(cell): grid[cell]=[]
			grid[cell].append(item)
		cache={"physics":physics,"process":process,"grid":grid}
		tree.set_meta(key,cache)
	var center := Vector2i((node.global_position/16).floor())
	var result: Array[Node2D]=[]
	for x in range(center.x-1,center.x+2):
		for y in range(center.y-1,center.y+2):
			for item in cache.grid.get(Vector2i(x,y),[]):
				if is_instance_valid(item) and item.is_inside_tree(): result.append(item)
	return result
