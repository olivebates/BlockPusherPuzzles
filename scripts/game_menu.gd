extends CanvasLayer

var overlay: Control
var was_paused := false
var settings_owner: Node

func _ready() -> void:
	layer=1300
	process_mode=Node.PROCESS_MODE_ALWAYS

func open_menu() -> void:
	if is_instance_valid(overlay) or is_instance_valid(settings_owner) or LevelEditorSession.switching: return
	if is_instance_valid(LevelEditorSession.overlay): return
	was_paused=get_tree().paused
	show_menu()

func show_menu() -> void:
	clear_overlay()
	get_tree().paused=true
	overlay=LevelEditorUI.modal(self,LevelEditorSession.current_color(),"Paused",{})
	overlay.cancel_action=continue_game
	var buttons := VBoxContainer.new()
	buttons.custom_minimum_size.x=300
	buttons.add_theme_constant_override("separation",6)
	overlay.rows.add_child(buttons)
	overlay.rows.move_child(buttons,1)
	var choices := {"Continue":continue_game,"Settings":open_settings,"Custom Levels":func(): open_destination("browser"),"Level Editor":func(): open_destination("editor"),"Discord":func(): OS.shell_open(preload("res://scripts/ending_message.gd").DISCORD_URL),"Donate":func(): OS.shell_open("https://ko-fi.com/snugglefox"),"Back to Main Menu":return_to_main}
	for caption in choices:
		var button := LevelEditorUI.button(caption,choices[caption])
		button.custom_minimum_size.y=32
		buttons.add_child(button)

func clear_overlay() -> void:
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
	overlay=null

func continue_game() -> void:
	clear_overlay()
	get_tree().paused=was_paused

func open_settings() -> void:
	var scene := get_tree().current_scene
	var settings := scene.get_node_or_null("AudioSettings")
	if not settings: return
	clear_overlay()
	settings_owner=settings
	settings.open_settings()

func back_from_settings(owner: Node) -> void:
	settings_owner=owner
	owner.menu.hide()

func settings_closed(owner: Node) -> void:
	if settings_owner!=owner: return
	settings_owner=null
	call_deferred("show_menu")

func open_destination(destination: String) -> void:
	clear_overlay()
	get_tree().paused=false
	LevelEditorSession.open_menu(destination)

func return_to_main() -> void:
	clear_overlay()
	get_tree().paused=false
	if get_tree().current_scene.is_in_group("main_menu"): return
	if not SaveSlots.return_to_menu(): show_menu()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or event.keycode!=KEY_ESCAPE: return
	if is_instance_valid(settings_owner) or is_instance_valid(LevelEditorSession.overlay): return
	var scene := get_tree().current_scene
	if not scene or scene.is_in_group("main_menu") or scene.has_method("request_publish"): return
	get_viewport().set_input_as_handled()
	if is_instance_valid(overlay): continue_game()
	else: open_menu()
