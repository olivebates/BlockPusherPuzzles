extends CanvasLayer
const TEMP_PATH := "user://level_editor_session.tmp.cps"
const WARNING := "Warning!\n\nIt's recommended you play through the game\nfirst to avoid spoilers."
var suspended_game: Node2D
var overlay: Control
var warned := false
var progress_was_enabled := true
var switching := false
var draft_path := "user://level_editor_draft.cpe"

func _ready() -> void:
	layer=1200
	process_mode=Node.PROCESS_MODE_ALWAYS
	var config := ConfigFile.new()
	config.load("user://level_editor.cfg")
	warned=config.get_value("editor","spoiler_warning_accepted",false)==true

func current_color() -> Color:
	var game := get_tree().current_scene
	return game.hue_palette.map_color(game.background_color) if game and "hue_palette" in game else HuePalette.DEFAULT_BACKGROUND

func open_menu() -> void:
	if switching or is_instance_valid(overlay) or is_instance_valid(suspended_game) or get_tree().paused or Progress.restoring: return
	get_tree().paused=true
	if warned: show_menu()
	else:
		overlay=LevelEditorUI.modal(self,current_color(),WARNING,{"Back":close_menu,"Continue":accept_warning})
		overlay.cancel_action=close_menu

func clear_overlay() -> void:
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
	overlay=null

func close_menu() -> void:
	clear_overlay()
	get_tree().paused=false

func accept_warning() -> void:
	warned=true
	var config := ConfigFile.new()
	config.set_value("editor","spoiler_warning_accepted",true)
	config.save("user://level_editor.cfg")
	if OS.has_feature("web"): JavaScriptBridge.force_fs_sync()
	show_menu()

func show_menu() -> void:
	clear_overlay()
	overlay=LevelEditorUI.modal(self,current_color(),"",{"Make Levels":enter_editor})
	overlay.cancel_action=close_menu

func enter_editor() -> void:
	if switching: return
	var state := Progress.snapshot()
	if state.is_empty() or not Progress.write_file(TEMP_PATH,state):
		clear_overlay()
		overlay=LevelEditorUI.modal(self,current_color(),"Couldn't save the game. Please try again.",{"Back":close_menu})
		return
	switching=true
	call_deferred("switch_to_editor")

func switch_to_editor() -> void:
	var color := current_color()
	clear_overlay()
	progress_was_enabled=Progress.enabled
	Progress.enabled=false
	suspended_game=get_tree().current_scene
	# Keep the exact running scene, including in-flight physics, off the tree.
	if RenderingServer.frame_pre_draw.is_connected(suspended_game.sync_hue_mask):
		RenderingServer.frame_pre_draw.disconnect(suspended_game.sync_hue_mask)
	get_tree().root.remove_child(suspended_game)
	get_tree().current_scene=null
	get_viewport().canvas_transform=Transform2D.IDENTITY
	var editor := preload("res://scenes/level_editor.tscn").instantiate()
	editor.background_color=color
	editor.draft_path=draft_path
	get_tree().root.add_child(editor)
	get_tree().current_scene=editor
	get_tree().paused=false
	switching=false

func exit_editor() -> void:
	if switching or not is_instance_valid(suspended_game): return
	if not get_tree().current_scene.save_draft():
		get_tree().current_scene.show_message("Couldn't save your level. Please try Exit again.")
		return
	var state := Progress.read_file(TEMP_PATH)
	if state.is_empty():
		get_tree().current_scene.show_message("Couldn't read the temporary save. Your game is still suspended.")
		return
	switching=true
	call_deferred("restore_game",state)

func restore_game(state: Dictionary) -> void:
	var editor := get_tree().current_scene
	get_tree().paused=true
	get_tree().root.remove_child(editor)
	get_tree().root.add_child(suspended_game)
	get_tree().current_scene=suspended_game
	if not RenderingServer.frame_pre_draw.is_connected(suspended_game.sync_hue_mask):
		RenderingServer.frame_pre_draw.connect(suspended_game.sync_hue_mask)
	Progress.level=suspended_game
	var restored := Progress.apply_state(state)
	if not restored:
		RenderingServer.frame_pre_draw.disconnect(suspended_game.sync_hue_mask)
		get_tree().root.remove_child(suspended_game)
		get_tree().root.add_child(editor)
		get_tree().current_scene=editor
		get_viewport().canvas_transform=Transform2D.IDENTITY
		editor.show_message("Couldn't restore the temporary save. Please try Exit again.")
		switching=false
		return
	suspended_game.apply_theme()
	Progress.enabled=progress_was_enabled
	suspended_game=null
	editor.queue_free()
	DirAccess.remove_absolute(TEMP_PATH)
	if OS.has_feature("web"): JavaScriptBridge.force_fs_sync()
	get_tree().paused=false
	switching=false

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(suspended_game):
		get_tree().current_scene.save_draft()
		# Closing the app in the editor still preserves the suspended main game.
		var state := Progress.read_file(TEMP_PATH)
		if not state.is_empty(): Progress.write_file(Progress.save_root+"/current.cps",state,true)

func _exit_tree() -> void:
	if is_instance_valid(suspended_game) and not suspended_game.is_inside_tree(): suspended_game.free()
