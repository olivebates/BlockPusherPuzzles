extends Node2D

var background_color := HuePalette.DEFAULT_BACKGROUND
var tile_color := HuePalette.DEFAULT_TILES
var hue_palette := HuePalette.new()
var ui: Control
var content: VBoxContainer
var popup: Control
var page := "home"
var slot_name: LineEdit
var slot_error: Label
var pending_slot := -1
var background: ColorRect
var launching := false

func _ready() -> void:
	add_to_group("main_menu")
	Progress.enabled=false
	Progress.level=null
	Dialogue.stop()
	get_viewport().canvas_transform=Transform2D.IDENTITY
	SaveSlots.initialize()
	var layer := CanvasLayer.new()
	add_child(layer)
	ui=Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.theme=LevelEditorUI.theme_for(background_color)
	layer.add_child(ui)
	background=ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader=preload("res://shaders/menu_background.gdshader")
	background.material=material
	ui.add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(center)
	content=VBoxContainer.new()
	content.custom_minimum_size.x=400
	content.add_theme_constant_override("separation",12)
	center.add_child(content)
	var settings := CanvasLayer.new()
	settings.name="AudioSettings"
	settings.set_script(preload("res://scripts/audio_settings.gd"))
	add_child(settings)
	show_home()

func _process(_delta: float) -> void:
	background.material.set_shader_parameter("reduced_motion",Juice.reduced_motion)

func clear_content() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

func heading(text: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text=text
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	content.add_child(label)

func show_home() -> void:
	page="home"
	clear_content()
	heading("PRISMBOUND",56,Color("d7edff"))
	heading("Every colour has a place.",16,Color("bda8d9"))
	var spacer := Control.new()
	spacer.custom_minimum_size.y=12
	content.add_child(spacer)
	var play := LevelEditorUI.button("Play Game",show_slots)
	play.custom_minimum_size.y=64
	play.add_theme_font_size_override("font_size",24)
	content.add_child(play)
	var extras := HBoxContainer.new()
	extras.add_theme_constant_override("separation",8)
	content.add_child(extras)
	for caption in ["Level Editor","Custom Levels"]:
		var destination := "editor" if caption=="Level Editor" else "browser"
		var button := LevelEditorUI.button(caption,func(): LevelEditorSession.open_menu(destination,true))
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y=38
		extras.add_child(button)
		if destination=="editor": LevelEditorUI.tint_button(button,Color("8564ad"))

func show_slots() -> void:
	page="slots"
	clear_content()
	heading("Choose your save",28,Color("d7edff"))
	for i in 3:
		var info := SaveSlots.slot_info(i)
		var caption := "%d  ·  %s\n%d orbs collected"%[i+1,info.name,info.orbs] if info.occupied else "%d  ·  Empty slot"%(i+1)
		var button := LevelEditorUI.button(caption,func(): choose_slot(i))
		button.custom_minimum_size.y=64
		content.add_child(button)
	content.add_child(LevelEditorUI.button("Back",show_home))

func choose_slot(index: int) -> void:
	if SaveSlots.slot_info(index).occupied:
		load_slot(index)
		return
	pending_slot=index
	popup=LevelEditorUI.modal(ui,background_color,"Name your save",{"Back":close_popup,"Play Game":create_save})
	popup.cancel_action=close_popup
	slot_name=LineEdit.new()
	slot_name.max_length=32
	slot_name.placeholder_text="Save name"
	slot_name.custom_minimum_size.x=320
	slot_name.text_submitted.connect(func(_text: String): create_save())
	popup.rows.add_child(slot_name)
	popup.rows.move_child(slot_name,1)
	slot_error=Label.new()
	popup.rows.add_child(slot_error)
	popup.rows.move_child(slot_error,2)
	slot_name.grab_focus()

func create_save() -> void:
	if launching: return
	if not SaveSlots.create_slot(pending_slot,slot_name.text):
		slot_error.text="Enter a name, or try again if saving failed."
		return
	var index := pending_slot
	close_popup()
	load_slot(index)

func load_slot(index: int) -> void:
	if launching: return
	if not SaveSlots.activate(index): return
	launching=true
	get_tree().change_scene_to_file(SaveSlots.GAME_SCENE)

func close_popup() -> void:
	if is_instance_valid(popup):
		ui.remove_child(popup)
		popup.queue_free()
	popup=null

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE and page=="slots" and not is_instance_valid(popup):
		show_home()
