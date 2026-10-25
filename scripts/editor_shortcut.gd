extends Node
var held := {}
var latched := false
func _input(event: InputEvent) -> void:
	if OS.has_feature("web"): return
	if not event is InputEventKey: return
	var code: int = event.physical_keycode if event.physical_keycode else event.keycode
	held[code] = event.pressed
	var chord: bool = (event.shift_pressed or held.get(KEY_SHIFT,false)) and held.get(KEY_Z,false) and held.get(KEY_P,false)
	if chord and not latched:
		latched = true
		get_viewport().set_input_as_handled()
		call_deferred("open_editor")
	elif not chord: latched = false
func open_editor() -> void:
	if OS.has_feature("web"): return
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/level_editor.tscn")
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		held.clear()
		latched = false
