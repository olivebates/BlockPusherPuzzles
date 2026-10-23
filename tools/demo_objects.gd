extends RefCounted
func add_instance(root: Node, scene: String, name: String, point: Vector2) -> Node:
	var parent := root.get_node("Objects")
	if parent.has_node(name): return parent.get_node(name)
	var object: Node2D = load(scene).instantiate()
	object.name = name
	object.position = point
	parent.add_child(object)
	object.owner = root
	return object
func add_examples(root: Node) -> void:
	for i in 2:
		var block := add_instance(root,"res://scenes/push_block.tscn","WeldedLilac%d" % i,Vector2(184+i*16,312))
		block.block_color = 3
	add_instance(root,"res://scenes/sliding_sphere.tscn","WhiteSphere",Vector2(216,280))
	add_instance(root,"res://scenes/symbol_portal.tscn","SquarePortalA",Vector2(344,312))
	add_instance(root,"res://scenes/symbol_portal.tscn","SquarePortalB",Vector2(456,312))
	add_instance(root,"res://scenes/recall_platform.tscn","RecallPlatformA",Vector2(40,318))
	add_instance(root,"res://scenes/recall_platform.tscn","RecallPlatformB",Vector2(568,318))
