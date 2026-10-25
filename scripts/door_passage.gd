extends RefCounted
var entry_side := 0
var entered := false
func update(door: StaticBody2D) -> bool:
	var player := door.get_tree().get_first_node_in_group("player") as CharacterBody2D
	if not door.opened or not player or player.noclip or player.recall_freeze_frames>0:
		entry_side=0
		entered=false
		return false
	var shape: CollisionShape2D=door.get_node("CollisionShape2D")
	var rect := shape.global_transform*shape.shape.get_rect()
	var point := player.global_position
	if rect.has_point(point):
		entered=entry_side!=0
		return false
	var side := -1 if point.x<rect.position.x else 1 if point.x>=rect.end.x else 0
	var passed := entered and side!=0 and side!=entry_side and point.y>=rect.position.y and point.y<rect.end.y
	entry_side=side
	entered=false
	return passed
