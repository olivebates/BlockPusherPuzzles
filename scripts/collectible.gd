@tool
extends Node2D
@export var persistent_id := ""
var collected := false
var clock := 0.0
func _ready() -> void:
	if not Engine.is_editor_hint(): add_to_group("collectibles")
func set_collected(value: bool) -> void:
	collected=value
	visible=not collected
func collect() -> bool:
	if collected: return false
	set_collected(true)
	var nearest: Node2D
	var distance := INF
	for indicator in get_tree().get_nodes_in_group("collectible_indicators"):
		if indicator.lit: continue
		var next: float=global_position.distance_squared_to(indicator.global_position)
		if next<distance:
			distance=next
			nearest=indicator
	if nearest: nearest.lit=true
	Juice.sound("collect")
	Juice.burst(global_position,Color("ffe38b"),9)
	return true
func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if Progress.restoring: return
	clock+=delta
	queue_redraw()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and not collected and not player.noclip and player.global_position.distance_to(global_position)<13: collect()
func _draw() -> void:
	var bob := Vector2(0,sin(clock*3)*1.5)
	draw_circle(bob,4.5,Color("ffe38b"))
