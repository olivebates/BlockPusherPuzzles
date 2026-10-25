extends Node2D
@export var open_as_editor := false
var elapsed := 0.0
var background_color := HuePalette.DEFAULT_BACKGROUND
var tile_color := HuePalette.DEFAULT_TILES
var theme_tween: Tween
var hue_shift := 0.0
var hue_cycling := false
var hue_cycle_tween: Tween
var hue_material: ShaderMaterial
var hue_palette := preload("res://scripts/hue_palette.gd").new()
var hue_exempt_view: SubViewport
var initial_level: Dictionary = {}
var initial_background := HuePalette.DEFAULT_BACKGROUND
var initial_tiles := HuePalette.DEFAULT_TILES
var reset_keys := {}
var reset_latched := false
func _ready() -> void:
	get_viewport().size_changed.connect(queue_redraw)
	var main_scene := str(ProjectSettings.get_setting("application/run/main_scene"))
	# Godot can store the main scene as a UID rather than a resource path.
	# Compare resolved paths so exported/editor launches both enable autosaving.
	if main_scene.begins_with("uid://"):
		var uid := ResourceUID.text_to_id(main_scene)
		if ResourceUID.has_id(uid): main_scene=ResourceUID.get_id_path(uid)
	if scene_file_path==main_scene and not open_as_editor: Progress.call_deferred("bind_level",self)
	initial_background = background_color
	initial_tiles = tile_color
	call_deferred("remember_level")
	setup_inputs()
	for walls in find_children("*","TileMapLayer",true,false):
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
	# Composite after every world/UI canvas, including paused dialogue. Explicitly
	# copy the screen again so this includes the earlier world post-processing.
	var hue_layer := CanvasLayer.new()
	hue_layer.name = "HueShift"
	hue_layer.layer = 1000
	add_child(hue_layer)
	var screen_copy := BackBufferCopy.new()
	screen_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	hue_layer.add_child(screen_copy)
	var hue_rect := ColorRect.new()
	hue_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hue_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hue_material = ShaderMaterial.new()
	hue_material.shader = preload("res://shaders/hue_shift.gdshader")
	hue_material.set_shader_parameter("hue_palette",hue_palette.texture)
	hue_exempt_view=SubViewport.new()
	hue_exempt_view.name="HueExemptMask"
	hue_exempt_view.transparent_bg=true
	hue_exempt_view.disable_3d=true
	hue_exempt_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(hue_exempt_view)
	var mask_draw := Node2D.new()
	mask_draw.set_script(preload("res://scripts/hue_exempt_mask.gd"))
	hue_exempt_view.add_child(mask_draw)
	hue_material.set_shader_parameter("exempt_texture",hue_exempt_view.get_texture())
	RenderingServer.frame_pre_draw.connect(sync_hue_mask)
	hue_rect.material = hue_material
	hue_layer.add_child(hue_rect)
	var hud := CanvasLayer.new()
	hud.name = "GameHUD"
	hud.layer = 10
	add_child(hud)
	var support := CanvasLayer.new()
	support.name="SupportLinks"
	support.set_script(preload("res://scripts/support_links.gd"))
	add_child(support)
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
	if OS.has_feature("web"): return
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
	hue_shift = 0.0
	stop_hue_cycle()
	hue_palette.reset(0.0)
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
	sync_hue_mask()
	RenderingServer.set_default_clear_color(background_color)
	for walls in find_children("*","TileMapLayer",true,false):
		if walls.material is ShaderMaterial: walls.material.set_shader_parameter("tile_color",tile_color)
	for body in get_tree().get_nodes_in_group("one_way_blocks"):
		body.tile_color = tile_color
		body.queue_redraw()
func sync_hue_mask() -> void:
	if hue_exempt_view:
		# ViewportTexture reports a stretched size again under canvas_items.
		# Match the actual framebuffer and its transform so the mask rasterizes
		# on the same pixels as the player, including at fractional window scales.
		var stretch := get_viewport().get_stretch_transform()
		hue_exempt_view.size=Vector2i((stretch*get_viewport_rect()).size.round())
		hue_exempt_view.canvas_item_default_texture_filter=get_viewport().canvas_item_default_texture_filter
		hue_exempt_view.get_child(0).transform=stretch
	if not hue_material: return
	var rects: Array[Vector4]=[]
	var dialogue := get_node_or_null("/root/Dialogue")
	if dialogue and dialogue.active and dialogue.panel: append_ui_rect(rects,dialogue.panel.get_global_rect())
	var map := get_node_or_null("TeleportMap")
	if map and map.active and map.panel: append_ui_rect(rects,map.panel.get_global_rect())
	var settings := get_node_or_null("AudioSettings")
	if settings:
		if settings.menu and settings.menu.visible: append_ui_rect(rects,Rect2(settings.menu.position,settings.menu.size))
		var gear := settings.get_node_or_null("AudioSettingsButton") as Control
		if gear: append_ui_rect(rects,gear.get_global_rect())
	hue_material.set_shader_parameter("ui_rect_count",rects.size())
	while rects.size()<4: rects.append(Vector4.ZERO)
	hue_material.set_shader_parameter("ui_rects",rects)
func append_ui_rect(rects: Array[Vector4], rect: Rect2) -> void:
	var size := get_viewport_rect().size
	rects.append(Vector4(rect.position.x/size.x,rect.position.y/size.y,rect.end.x/size.x,rect.end.y/size.y))
func stop_hue_cycle() -> void:
	hue_cycling=false
	if hue_cycle_tween and hue_cycle_tween.is_valid(): hue_cycle_tween.kill()
func start_hue_cycle() -> void:
	stop_hue_cycle()
	hue_cycling=true
	var origin := hue_shift
	hue_cycle_tween=create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_loops()
	hue_cycle_tween.tween_method(func(phase: float):
		hue_shift=wrapf(origin+phase,-0.5,0.5)
		hue_palette.reset(hue_shift)
		apply_theme(),0.0,1.0,12.0)
func change_theme(color: Color, cycle_hue := false) -> void:
	if theme_tween and theme_tween.is_valid(): theme_tween.kill()
	stop_hue_cycle()
	hue_cycling=cycle_hue
	# Absolute hue, never cumulative: revisiting a changer keeps the same palette.
	var target_hue := HuePalette.hue_offset(color)
	hue_shift=target_hue
	hue_palette.begin(target_hue)
	theme_tween = create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	# Blend RGB endpoints directly; no detour around intermediate wheel hues.
	theme_tween.tween_method(hue_palette.blend,0.0,1.0,0.35)
	theme_tween.tween_method(func(_value: float): apply_theme(),0.0,1.0,0.35)
	if cycle_hue: theme_tween.chain().tween_callback(start_hue_cycle)
func _draw() -> void:
	for i in 35:
		var p := Vector2(fmod(i*97.0+elapsed*1.5,960),100+fmod(i*43.0,190))
		draw_circle(p,0.5,Color(0.4,0.7,0.8,0.13))
