extends CanvasLayer
const TEMP_PATH := "user://level_editor_session.tmp.cps"
const WARNING := "Warning!\n\nIt's recommended you play through the game\nfirst to avoid spoilers."
var suspended_game: Node2D
var overlay: Control
var warned := false
var progress_was_enabled := true
var switching := false
var draft_path := "user://level_editor_draft.cpe"
var service: LevelPublisher
var browser_state := {"sort":"hot","search":""}
var pending_level: Dictionary={}
var pending_replay := ""
var pending_edit := false
var return_browser := false
var return_replays: Dictionary={}
var menu_destination := "browser"
var suspended_from_menu := false

func _ready() -> void:
	layer=1200
	process_mode=Node.PROCESS_MODE_ALWAYS
	var config := ConfigFile.new()
	config.load("user://level_editor.cfg")
	warned=config.get_value("editor","spoiler_warning_accepted",false)==true
	service=LevelPublisher.new()
	add_child(service)

func current_color() -> Color:
	var game := get_tree().current_scene
	return game.hue_palette.map_color(game.background_color) if game and "hue_palette" in game else HuePalette.DEFAULT_BACKGROUND

func open_menu(destination := "browser", force_warning := false) -> void:
	if switching or is_instance_valid(overlay) or is_instance_valid(suspended_game) or get_tree().paused or Progress.restoring: return
	get_tree().paused=true
	menu_destination=destination
	if warned and not force_warning: open_destination()
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
	open_destination()

func open_destination() -> void:
	if menu_destination=="editor": enter_editor()
	else: show_menu()

func show_menu(replay_level: Dictionary = {}) -> void:
	clear_overlay()
	get_tree().paused=true
	service.load_state()
	overlay=LevelEditorUI.modal(self,current_color(),"",{"Make Levels":enter_editor})
	LevelEditorUI.compact_buttons(overlay)
	overlay.rows.add_theme_constant_override("separation",0)
	overlay.actions.add_theme_constant_override("separation",0)
	for button in overlay.actions.get_children(): button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	LevelEditorUI.tint_button(overlay.actions.get_child(0),Color("8564ad"))
	overlay.cancel_action=close_menu
	overlay.set_meta("selection_menu",true)
	var browser := CommunityBrowser.new()
	browser.session=self
	browser.service=service
	browser.sort_order=str(browser_state.sort)
	browser.search_text=str(browser_state.search)
	browser.replay_level=replay_level
	overlay.rows.add_child(browser)
	overlay.rows.move_child(browser,0)

func enter_editor() -> void:
	pending_level={}
	pending_replay=""
	pending_edit=false
	return_browser=is_instance_valid(overlay) and overlay.get_meta("selection_menu",false)
	return_replays=overlay.rows.get_child(0).replay_level.duplicate(true) if return_browser else {}
	begin_session()

func enter_community(entry: Dictionary, replay_code := "", editing := false) -> void:
	if switching: return
	pending_level=entry
	pending_replay=replay_code
	pending_edit=editing
	return_browser=true
	return_replays=entry if not replay_code.is_empty() else {}
	begin_session()

func begin_session() -> void:
	if switching: return
	suspended_from_menu=get_tree().current_scene.is_in_group("main_menu")
	var state := {} if suspended_from_menu else Progress.snapshot()
	if not suspended_from_menu and (state.is_empty() or not Progress.write_file(TEMP_PATH,state)):
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
	if suspended_game.has_method("sync_hue_mask") and RenderingServer.frame_pre_draw.is_connected(suspended_game.sync_hue_mask):
		RenderingServer.frame_pre_draw.disconnect(suspended_game.sync_hue_mask)
	get_tree().root.remove_child(suspended_game)
	get_tree().current_scene=null
	get_viewport().canvas_transform=Transform2D.IDENTITY
	var editor: Node2D
	if not pending_level.is_empty() and not pending_edit:
		editor=load("res://scripts/community_play.gd").new()
		editor.entry=pending_level
		editor.replay_code=pending_replay
	else:
		editor=preload("res://scenes/level_editor.tscn").instantiate()
	editor.background_color=color
	editor.draft_path=draft_path
	editor.publisher=service
	if not pending_level.is_empty():
		editor.initial_level_code=str(pending_level.levelString)
		editor.fit_grid_to_view=false
		if pending_edit:
			editor.cloud_level_id=str(pending_level.id)
			editor.cloud_revision=int(pending_level.revision)
			editor.draft_path="user://cloud_editor_"+str(pending_level.id)+".cpe"
	get_tree().root.add_child(editor)
	get_tree().current_scene=editor
	get_tree().paused=is_instance_valid(editor.popup)
	switching=false

func exit_editor() -> void:
	if switching or not is_instance_valid(suspended_game): return
	if not get_tree().current_scene.save_draft():
		get_tree().current_scene.show_message("Couldn't save your level. Please try Exit again.")
		return
	if suspended_from_menu:
		switching=true
		call_deferred("restore_menu")
		return
	var state := Progress.read_file(TEMP_PATH)
	if state.is_empty():
		get_tree().current_scene.show_message("Couldn't read the temporary save. Your game is still suspended.")
		return
	switching=true
	call_deferred("restore_game",state)

func restore_menu() -> void:
	var editor := get_tree().current_scene
	get_tree().root.remove_child(editor)
	get_tree().root.add_child(suspended_game)
	get_tree().current_scene=suspended_game
	get_viewport().canvas_transform=Transform2D.IDENTITY
	Progress.enabled=progress_was_enabled
	Progress.level=null
	suspended_game=null
	editor.queue_free()
	get_tree().paused=false
	switching=false
	if return_browser: show_menu(return_replays)

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
	if return_browser: show_menu(return_replays)

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(suspended_game) and not suspended_from_menu:
		get_tree().current_scene.save_draft()
		# Closing the app in the editor still preserves the suspended main game.
		var state := Progress.read_file(TEMP_PATH)
		if not state.is_empty(): Progress.write_file(Progress.save_root+"/current.cps",state,true)

func _exit_tree() -> void:
	if is_instance_valid(suspended_game) and not suspended_game.is_inside_tree(): suspended_game.free()
