extends Node2D
@export var open_as_editor := false
var elapsed := 0.0
var background_color := Color(0.6,0.6,0.6,1)
var tile_color := Color(0.2,0.2,0.2,1)
var theme_tween: Tween
var initial_level: Dictionary = {}
var initial_background := Color(0.6,0.6,0.6,1)
var initial_tiles := Color(0.2,0.2,0.2,1)
var reset_keys := {}
var reset_latched := false
func _ready() -> void:
	if scene_file_path==ProjectSettings.get_setting("application/run/main_scene") and not open_as_editor: Progress.call_deferred("bind_level",self)
	initial_background = background_color
	initial_tiles = tile_color
	call_deferred("remember_level")
	setup_inputs()
	var walls := get_node("Walls") as TileMapLayer
	if walls.material: walls.material = walls.material.duplicate()
	apply_theme()
	var guide := Node2D.new()
	guide.name = "PlatformGuide"
	guide.set_script(load("res://scripts/platform_guide.gd"))
	add_child(guide)
	var fx_layer := CanvasLayer.new()
	fx_layer.layer = 5
	add_child(fx_layer)
	var fx := ColorRect.new()
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.material = ShaderMaterial.new()
	fx.material.shader = load("res://shaders/world.gdshader")
	fx.set_script(load("res://scripts/post_fx.gd"))
	fx_layer.add_child(fx)
	var hud := CanvasLayer.new()
	hud.name = "GameHUD"
	hud.layer = 10
	add_child(hud)
	var audio := CanvasLayer.new()
	audio.name = "AudioSettings"
	audio.set_script(load("res://scripts/audio_settings.gd"))
	add_child(audio)
	var map := CanvasLayer.new()
	map.name="TeleportMap"
	map.set_script(load("res://scripts/teleport_map.gd"))
	add_child(map)
	if open_as_editor:
		var editor := Node2D.new()
		editor.name = "LevelEditor"
		editor.set_script(load("res://scripts/level_editor.gd"))
		add_child(editor)
		editor.call_deferred("open_blank")
	else:
		var shortcut := Node.new()
		shortcut.name = "EditorShortcut"
		shortcut.set_script(load("res://scripts/editor_shortcut.gd"))
		add_child(shortcut)
func setup_inputs() -> void:
	# The autoload installs saved bindings once, before any scene starts.
	pass
func remember_level(data: Dictionary = {}) -> void:
	initial_level = LevelData.capture(self) if data.is_empty() else data.duplicate(true)
	set_meta("fall_limit",initial_level.grid[1]*16+64)
func _input(event: InputEvent) -> void:
	if not event is InputEventKey: return
	var code: int = event.physical_keycode if event.physical_keycode else event.keycode
	reset_keys[code] = event.pressed
	var chord: bool = (event.shift_pressed or reset_keys.get(KEY_SHIFT,false)) and reset_keys.get(KEY_Z,false) and reset_keys.get(KEY_O,false)
	if chord and not reset_latched:
		reset_latched = true
		get_viewport().set_input_as_handled()
		call_deferred("reset_level")
	elif not chord: reset_latched = false
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		reset_keys.clear()
		reset_latched = false
func reset_level() -> bool:
	var editor := get_node_or_null("LevelEditor")
	if editor and editor.building: return false
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if not player or not LevelData.valid(initial_level): return false
	var point := player.global_position
	if not LevelData.apply(self,initial_level,true): return false
	if theme_tween and theme_tween.is_valid(): theme_tween.kill()
	background_color = initial_background
	tile_color = initial_tiles
	elapsed = 0
	player.global_position = point
	player.velocity = Vector2.ZERO
	player.coyote = 0
	player.buffered = 0
	player.show_recall_prompt = false
	player.recall_freeze_frames = 2
	player.force_update_transform()
	player.reset_physics_interpolation()
	player.queue_redraw()
	Juice.sound("reset")
	apply_theme()
	return true
func _process(delta: float) -> void:
	elapsed += delta
	apply_theme()
	if Input.is_action_just_pressed("gentle") and not Input.is_physical_key_pressed(KEY_SHIFT): Juice.reduced_motion = not Juice.reduced_motion
	queue_redraw()
func apply_theme() -> void:
	RenderingServer.set_default_clear_color(background_color)
	var walls := get_node_or_null("Walls") as TileMapLayer
	if walls and walls.material: walls.material.set_shader_parameter("tile_color",tile_color)
	for body in get_tree().get_nodes_in_group("one_way_blocks"):
		body.tile_color = tile_color
		body.queue_redraw()
func change_theme(color: Color, background_base := Color(0.6,0.6,0.6,1), tile_base := Color(0.2,0.2,0.2,1)) -> void:
	if theme_tween and theme_tween.is_valid(): theme_tween.kill()
	theme_tween = create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	theme_tween.tween_property(self,"background_color",background_base*Color.from_hsv(color.h,color.s*0.22,1),0.35)
	theme_tween.tween_property(self,"tile_color",tile_base*Color.from_hsv(color.h,color.s*0.55,1),0.35)
	theme_tween.tween_method(func(_value: float): apply_theme(),0.0,1.0,0.35)
func _draw() -> void:
	for x in range(0,961,16): draw_line(Vector2(x,64),Vector2(x,400),Color(0.25,0.45,0.6,0.035),0.5)
	for y in range(64,401,16): draw_line(Vector2(0,y),Vector2(960,y),Color(0.25,0.45,0.6,0.035),0.5)
	for i in 35:
		var p := Vector2(fmod(i*97.0+elapsed*1.5,960),100+fmod(i*43.0,190))
		draw_circle(p,0.5,Color(0.4,0.7,0.8,0.13))
