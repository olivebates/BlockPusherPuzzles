@tool
extends Node2D
@export var character_name := StoryLines.NPC
@export var dialogue_id := ""
var nearby := false
func _ready() -> void:
	if not Engine.is_editor_hint(): add_to_group("story_npcs")
func story_key() -> String:
	return dialogue_id if not dialogue_id.is_empty() else "npc:"+Progress.object_key(self)
func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	if Progress.restoring: return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	nearby=false
	if player and not player.noclip:
		var distance := player.global_position.distance_to(global_position)
		if distance<=64: Dialogue.request_once(story_key(),StoryLines.ENCOUNTER)
		nearby=distance<=16 and not Dialogue.active
		if nearby and Input.is_action_just_pressed("interact"): Dialogue.begin("",StoryLines.REMINDER)
	queue_redraw()
func _draw() -> void:
	if not nearby or Engine.is_editor_hint(): return
	var text := InputBindings.prompt("interact")
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x
	draw_string(font,Vector2(-width/2,-14),text,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.WHITE)
