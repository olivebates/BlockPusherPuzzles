@tool
extends Node2D
@export var dialogue_id := ""
@export_multiline var text := "Whoa, this one looks tough!"
func _ready() -> void:
	if not Engine.is_editor_hint(): add_to_group("dialogue_triggers")
func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	if Progress.restoring: return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and not player.noclip and player.global_position.distance_to(global_position)<=64:
		var key := dialogue_id if not dialogue_id.is_empty() else "trigger:"+Progress.object_key(self)
		Dialogue.request_once(key,[[StoryLines.PLAYER,text]])
func _draw() -> void:
	if Engine.is_editor_hint():
		draw_circle(Vector2.ZERO,5,Color("b1cfed"))
		draw_string(ThemeDB.fallback_font,Vector2(-2,4),"!",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("202830"))
