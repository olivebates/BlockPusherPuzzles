extends Node2D
## Always processes while gameplay is paused. Authored data never comes from a test run.
var active := false
var building := false
var data: Dictionary = {}
var selected := 0
var selected_color := 0
var selected_symbol := 0
var lightning_direction := 0
var link_id := "A"
var trigger_hex := ""
var trigger_color := Color("89b9d1")
var trigger_background := Color(0.6,0.6,0.6,1)
var trigger_tiles := Color(0.2,0.2,0.2,1)
var required := 1
var editor_camera: Camera2D
var ui: CanvasLayer
var top: PanelContainer
var bottom: PanelContainer
var state_label: Label
var message: Label
var mode_button: Button
var file_dialog: FileDialog
var dimensions: Array[SpinBox] = []
var palette_buttons: Array[Button] = []
var textures: Array[Texture2D] = []
var last_cell := Vector2i(-999999,-999999)
var chord_latched := false
var chord_keys := {}
@onready var level: Node2D = get_parent()
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 30
	for icon in LevelData.ICONS: textures.append(load("res://assets/editor/"+icon+".svg"))
	editor_camera = Camera2D.new()
	editor_camera.enabled = false
	add_child(editor_camera)
	make_ui()
func label(text: String, parent: Node) -> Label:
	var node := Label.new()
	node.text = text
	parent.add_child(node)
	return node
func button(text: String, parent: Node, callback: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.focus_mode = Control.FOCUS_NONE
	node.pressed.connect(callback)
	parent.add_child(node)
	return node
func make_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 50
	add_child(ui)
	top = PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 82
	ui.add_child(top)
	var top_rows := VBoxContainer.new()
	top.add_child(top_rows)
	var actions := HBoxContainer.new()
	top_rows.add_child(actions)
	button("Save",actions,func(): open_file(true))
	button("Load",actions,func(): open_file(false))
	mode_button = button("Play [Space]",actions,toggle_mode)
	button("Close [Shift+Z+P]",actions,toggle_editor)
	state_label = label("BUILD",actions)
	var settings := HBoxContainer.new()
	top_rows.add_child(settings)
	for i in 3:
		label([" Columns "," Rows "," Snap px "][i],settings)
		var spinner := SpinBox.new()
		spinner.min_value = 1
		spinner.max_value = 64 if i==2 else 512
		spinner.value = [60,34,16][i]
		spinner.custom_minimum_size.x = 78
		spinner.value_changed.connect(func(value: float):
			if not data.is_empty(): data.grid[i] = int(value)
			queue_redraw())
		settings.add_child(spinner)
		dimensions.append(spinner)
	message = label("LMB place | RMB erase | Middle drag pan | Wheel zoom",top_rows)
	message.add_theme_font_size_override("font_size",12)
	bottom = PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -164
	ui.add_child(bottom)
	var rows := VBoxContainer.new()
	bottom.add_child(rows)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 66
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows.add_child(scroll)
	var palette := HBoxContainer.new()
	scroll.add_child(palette)
	var names := ["Wall","Player","Block","Key tile","Door","Portal","Sphere","Platform","One-way","Theme","Rotate CW","Rotate CCW","Large door","Pickup","Indicator","Sunny","Dialogue","Map hint","Lightning","Elevator","Phase wall","Erase"]
	for i in names.size():
		var item := button(names[i],palette,func(): select_item(i))
		item.toggle_mode = true
		item.custom_minimum_size = Vector2(96,58)
		if i<textures.size():
			item.icon = textures[i]
			item.expand_icon = true
			item.add_theme_constant_override("icon_max_width",24)
		palette_buttons.append(item)
	select_item(0)
	var props := HBoxContainer.new()
	rows.add_child(props)
	label(" Color ",props)
	var colors := OptionButton.new()
	for name in PuzzlePalette.NAMES: colors.add_item(name)
	colors.item_selected.connect(func(index: int): selected_color = index)
	props.add_child(colors)
	label(" Symbol ",props)
	var symbols := OptionButton.new()
	for name in ["Square","Circle","Triangle","Star"]: symbols.add_item(name)
	symbols.item_selected.connect(func(index: int): selected_symbol = index)
	props.add_child(symbols)
	var beam_direction := OptionButton.new()
	beam_direction.add_item("Lightning right")
	beam_direction.add_item("Lightning left")
	beam_direction.item_selected.connect(func(index: int): lightning_direction=index)
	props.add_child(beam_direction)
	label(" ID ",props)
	var id_edit := LineEdit.new()
	id_edit.text = "A"
	id_edit.max_length = 32
	id_edit.custom_minimum_size.x = 58
	id_edit.text_changed.connect(func(value: String): link_id = value)
	props.add_child(id_edit)
	label(" Door needs ",props)
	for i in 4:
		var check := CheckBox.new()
		check.text = PuzzlePalette.NAMES[i].capitalize()
		check.modulate = PuzzlePalette.COLORS[i]
		check.button_pressed = i==0
		check.focus_mode = Control.FOCUS_NONE
		check.toggled.connect(func(on: bool):
			if on: required |= 1<<i
			else: required &= ~(1<<i))
		props.add_child(check)
	var theme_props := HBoxContainer.new()
	rows.add_child(theme_props)
	label(" Theme hex ",theme_props)
	var hex_edit := LineEdit.new()
	hex_edit.placeholder_text = "#RRGGBB (optional)"
	hex_edit.max_length = 32
	hex_edit.custom_minimum_size.x = 210
	hex_edit.text_changed.connect(func(value: String): trigger_hex = value)
	theme_props.add_child(hex_edit)
	label(" or color ",theme_props)
	var picker := ColorPickerButton.new()
	picker.color = trigger_color
	picker.custom_minimum_size = Vector2(60,26)
	picker.color_changed.connect(func(value: Color): trigger_color = value)
	theme_props.add_child(picker)
	for target in 2:
		label(" Background " if target==0 else " Tiles ",theme_props)
		var base_picker := ColorPickerButton.new()
		base_picker.color = trigger_background if target==0 else trigger_tiles
		base_picker.edit_alpha = false
		base_picker.custom_minimum_size = Vector2(48,26)
		base_picker.color_changed.connect(func(value: Color):
			if target==0: trigger_background = value
			else: trigger_tiles = value)
		theme_props.add_child(base_picker)
	label("Space switches build / play; testing preserves your layout",rows).add_theme_font_size_override("font_size",12)
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.cpplevel ; Chromatic Push level"])
	file_dialog.file_selected.connect(file_selected)
	ui.add_child(file_dialog)
	ui.hide()
func open_blank() -> void:
	await get_tree().process_frame
	var area := board_area()
	data = {"v":1,"grid":[maxi(1,int(area.size.x/16)),maxi(1,int(area.size.y/16)),16],"tiles":[],"objects":[]}
	active = true
	enter_build()
	ui.show()
	level.get_node("GameHUD").hide()
	fit_board()
func board_area() -> Rect2:
	return Rect2(0,top.get_rect().end.y,get_viewport_rect().size.x,maxf(16,bottom.get_rect().position.y-top.get_rect().end.y))
func fit_board() -> void:
	var area := board_area()
	var size := Vector2(data.grid[0]*16,data.grid[1]*16)
	var amount := minf(area.size.x/size.x,area.size.y/size.y)
	editor_camera.zoom = Vector2.ONE*amount
	editor_camera.position = size/2+(get_viewport_rect().size/2-area.get_center())/amount
func select_item(index: int) -> void:
	selected = index
	for i in palette_buttons.size(): palette_buttons[i].button_pressed = i==index
func toggle_editor() -> void:
	if active:
		get_tree().paused = false
		get_tree().call_deferred("change_scene_to_file","res://scenes/main.tscn")
	else:
		open_blank()
func enter_build() -> void:
	building = true
	get_tree().paused = true
	level.get_node("Objects").hide()
	level.get_node("Walls").hide()
	editor_camera.enabled = true
	editor_camera.make_current()
	for i in 3: dimensions[i].set_value_no_signal(data.grid[i])
	bottom.show()
	state_label.text = "BUILD"
	mode_button.text = "Play [Space]"
	queue_redraw()
func start_play() -> bool:
	if not LevelData.valid(data):
		message.text = "Place exactly one player before playtesting."
		return false
	if not LevelData.apply(level,data): return false
	level.remember_level(data)
	building = false
	get_tree().paused = false
	level.get_node("Objects").show()
	level.get_node("Walls").show()
	editor_camera.enabled = false
	var camera := level.get_node("Camera") as Camera2D
	camera.make_current()
	camera.global_position = camera.player.global_position
	camera.reset_smoothing()
	bottom.hide()
	state_label.text = "PLAYTEST"
	mode_button.text = "Build [Space]"
	queue_redraw()
	return true
func toggle_mode() -> void:
	get_viewport().gui_release_focus()
	Input.action_release("jump")
	if building: start_play()
	else: enter_build()
func _input(event: InputEvent) -> void:
	if Dialogue.active or level.get_node("TeleportMap").active: return
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode!=0 else event.keycode
		chord_keys[code] = event.pressed
		var chord: bool = (event.shift_pressed or chord_keys.get(KEY_SHIFT,false)) and chord_keys.get(KEY_Z,false) and chord_keys.get(KEY_P,false)
		if chord and not chord_latched:
			chord_latched = true
			toggle_editor()
			get_viewport().set_input_as_handled()
			return
		if not chord: chord_latched = false
		if active and event.pressed and not event.echo and event.physical_keycode==KEY_SPACE and not modal_open():
			var focus := get_viewport().gui_get_focus_owner()
			if focus is LineEdit: return
			toggle_mode()
			get_viewport().set_input_as_handled()
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		chord_keys.clear()
		chord_latched = false
func _unhandled_input(event: InputEvent) -> void:
	if not active or not building or modal_open(): return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			editor_camera.zoom *= 1.12 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1/1.12
			editor_camera.zoom = editor_camera.zoom.clamp(Vector2(0.25,0.25),Vector2(5,5))
		if event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
			last_cell = Vector2i(-999999,-999999)
			if event.pressed: paint(get_global_mouse_position(),event.button_index==MOUSE_BUTTON_RIGHT)
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE): editor_camera.position -= event.relative/editor_camera.zoom
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			paint(get_global_mouse_position(),Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))
func _process(delta: float) -> void:
	if active and building and not modal_open():
		if not get_viewport().gui_get_focus_owner() is LineEdit:
			var axis := Input.get_vector("left","right","jump","down")
			# Space is reserved for switching; pan vertically with arrow/W/S keys.
			axis.y = float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
			editor_camera.position += axis*240*delta/editor_camera.zoom.x
		queue_redraw()
func modal_open() -> bool:
	return file_dialog.visible or level.get_node("AudioSettings").menu.visible
func paint(point: Vector2, erase := false) -> void:
	get_viewport().gui_release_focus()
	var snap := int(data.grid[2])
	var cell := Vector2i(floor(point.x/snap),floor(point.y/snap))
	if cell==last_cell: return
	last_cell = cell
	if point.x<0 or point.y<0 or point.x>=data.grid[0]*16 or point.y>=data.grid[1]*16: return
	var tile := Vector2i(floor(point.x/16),floor(point.y/16))
	if erase or selected==LevelData.SCENES.size():
		data.tiles.erase([tile.x,tile.y])
		for i in range(data.objects.size()-1,-1,-1):
			var entry: Array = data.objects[i]
			if Vector2(entry[1],entry[2]).distance_to(Vector2(cell*snap)+Vector2.ONE*snap/2.0)<snap*0.75: data.objects.remove_at(i)
	elif selected==0:
		if not data.tiles.has([tile.x,tile.y]): data.tiles.append([tile.x,tile.y])
	else:
		var position := Vector2(cell*snap)+Vector2.ONE*snap/2.0
		if selected==1: position.y += snap/2.0-7
		if selected==7:
			position.y += snap/2.0-2
			position = LevelData.platform_position(data,position)
		for i in range(data.objects.size()-1,-1,-1):
			var previous: Array = data.objects[i]
			if int(previous[0])==selected and (selected==1 or Vector2(previous[1],previous[2]).distance_to(position)<1): data.objects.remove_at(i)
		var entry := [selected,position.x,position.y]
		if selected==2: entry.append_array([selected_color,0.2,0.15])
		if selected==3: entry.append_array([selected_color,link_id])
		if selected==4: entry.append_array([required,link_id])
		if selected==5: entry.append(selected_symbol)
		if selected==6: entry.append_array([150.0,0.2])
		if selected==9: entry.append_array([trigger_hex,trigger_color.to_html(),trigger_background.to_html(),trigger_tiles.to_html()])
		if selected==12: entry.append(20)
		if selected==13: entry.append("")
		if selected==15: entry.append_array([StoryLines.NPC,""])
		if selected==16: entry.append_array(["","Whoa, this one looks tough!"])
		if selected==18: entry.append_array([lightning_direction,128,"8adfff",true])
		if selected==19: entry.append(48.0)
		data.objects.append(entry)
	queue_redraw()
func open_file(save: bool) -> void:
	if not building: enter_build()
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if save else FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.current_file = "level.cpplevel" if save else ""
	file_dialog.popup_centered_ratio(0.78)
func file_selected(path: String) -> void:
	if file_dialog.file_mode==FileDialog.FILE_MODE_SAVE_FILE: save_to(path)
	else: load_from(path)
func save_to(path: String) -> bool:
	if not LevelData.valid(data,false):
		message.text = "Save needs valid object settings and at most one player."
		return false
	var bytes := LevelData.encode(data)
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file==null:
		message.text = "Could not save: "+error_string(FileAccess.get_open_error())
		return false
	file.store_buffer(bytes)
	file.close()
	message.text = "Saved %s (%d bytes)" % [path.get_file(),bytes.size()]
	return true
func load_from(path: String) -> bool:
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>LevelData.MAX_BYTES:
		message.text = "Cannot open level, or file is too large."
		return false
	var loaded := LevelData.decode(file.get_buffer(file.get_length()))
	file.close()
	if loaded.is_empty():
		message.text = "Invalid or damaged level; your layout is unchanged."
		return false
	data = loaded
	if not building: enter_build()
	for i in 3: dimensions[i].set_value_no_signal(data.grid[i])
	message.text = "Loaded "+path.get_file()
	fit_board()
	queue_redraw()
	return true
func _draw() -> void:
	if not active or not building or data.is_empty(): return
	var size := Vector2(data.grid[0]*16,data.grid[1]*16)
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.6,0.6,0.6,0.98))
	var snap := int(data.grid[2])
	var view := get_viewport_rect().size/editor_camera.zoom
	var start := editor_camera.position-view/2
	var end := editor_camera.position+view/2
	for x in range(maxi(0,int(start.x/snap)),mini(int(size.x/snap)+1,int(end.x/snap)+2)):
		draw_line(Vector2(x*snap,maxf(0,start.y)),Vector2(x*snap,minf(size.y,end.y)),Color(0.25,0.45,0.6,0.23),0.5)
	for y in range(maxi(0,int(start.y/snap)),mini(int(size.y/snap)+1,int(end.y/snap)+2)):
		draw_line(Vector2(maxf(0,start.x),y*snap),Vector2(minf(size.x,end.x),y*snap),Color(0.25,0.45,0.6,0.23),0.5)
	for door in data.objects:
		if int(door[0])!=4: continue
		for key in data.objects:
			if int(key[0])==3 and key[4]==door[4] and int(door[3]) & (1<<int(key[3])):
				DottedLinks.draw(self,Vector2(key[1],key[2]),Vector2(door[1],door[2]))
	for tile in data.tiles: draw_texture_rect(textures[0],Rect2(tile[0]*16,tile[1]*16,16,16),false)
	for item in data.objects:
		var color := Color.WHITE
		if int(item[0]) in [2,3]: color = PuzzlePalette.COLORS[int(item[3])]
		var point := Vector2(item[1],item[2])
		var icon_size := 12.0 if int(item[0])==3 else 16.0
		draw_texture_rect(textures[int(item[0])],Rect2(point-Vector2.ONE*icon_size/2,Vector2.ONE*icon_size),false,color)
	draw_rect(Rect2(Vector2.ZERO,size),Color("8acde1"),false,1)
	var mouse := get_global_mouse_position()
	var cell := Vector2(floor(mouse.x/snap),floor(mouse.y/snap))*snap
	draw_rect(Rect2(cell,Vector2(snap,snap)),Color(0.7,0.9,1,0.6),false,0.7)


