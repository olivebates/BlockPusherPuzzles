extends Node2D
const TOP := 48
const BOTTOM := 88
var draft_path := "user://level_editor_draft.cpe"
var initial_level_code := ""
var fit_grid_to_view := true
var background_color := HuePalette.DEFAULT_BACKGROUND
var data := {"v":1,"grid":[40,20,16],"color":"", "tiles":[],"objects":[]}
var selected_kind := 0
var selected_hue := 0
var playing := false
var board: Board
var width_input: SpinBox
var height_input: SpinBox
var color_button: Button
var play_button: Button
var import_button: Button
var export_button: Button
var ui: Control
var palette: HBoxContainer
var palette_buttons: Array[Button]=[]
var popup: Control
var play_view: SubViewportContainer
var play_viewport: SubViewport
var world: Node2D
var updating := false
var painting := false
var erase := false
var last_cell := Vector2i(-1,-1)
var history: Array[Dictionary]=[]
var stroke_saved := false
var play_frames := 0
var objective: Label
var publish_hint: Label
var publisher: LevelPublisher
var publisher_settings_path := "user://level_publishing.cfg"
var verified_level_code := ""
var test_level_code := ""
var publishing_test := false
var upload_name: LineEdit
var upload_author: LineEdit
var upload_description: LineEdit
var cloud_level_id := ""
var cloud_revision := 0
var upload_error: Label
var upload_button: Button
var upload_back: Button
var upload_request_id := ""
var upload_payload := ""
var cooldown_label: Label
var cooldown_timer: Timer

class Board extends Control:
	var editor: Node2D
	var content: Node2D
	var ghost: Node2D
	func _ready() -> void:
		content=Node2D.new()
		add_child(content)
	func rebuild_visuals() -> void:
		for child in content.get_children():
			content.remove_child(child)
			child.queue_free()
		for tile in editor.data.tiles:
			var visual := LevelEditorIcons.create(0,0,editor.background_color)
			visual.position=Vector2(tile[0],tile[1])*16+Vector2(8,8)
			content.add_child(visual)
		var keys := {}
		for item in editor.data.objects:
			if item[0]==2: continue
			var hue: int=int(item[3]) if item[0]==3 else 0
			var visual := LevelEditorIcons.create(item[0],hue,editor.background_color)
			visual.position=Vector2(item[1],item[2])
			visual.z_index=4 if item[0] in [10,11] else 3 if item[0]==1 else 0
			content.add_child(visual)
			if item[0]==3: keys[visual.position]=hue
		for component in LevelEditorIcons.block_components(editor.data.objects):
			var group := LevelEditorIcons.block_group(component.points,component.hue,keys)
			group.z_index=1
			content.add_child(group)
	func refresh_ghost() -> void:
		if is_instance_valid(ghost):
			remove_child(ghost)
			ghost.queue_free()
		ghost=LevelEditorIcons.create(editor.selected_kind,editor.selected_hue,editor.background_color)
		ghost.modulate.a=0.45
		ghost.z_index=10
		add_child(ghost)
	func _process(_delta: float) -> void:
		if not is_instance_valid(ghost): return
		var mouse := get_local_mouse_position()
		ghost.visible=is_visible_in_tree() and Rect2(Vector2.ZERO,size).has_point(mouse) and not is_instance_valid(editor.popup)
		ghost.position=(mouse/16).floor()*16+Vector2(8,8)
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),editor.background_color)
		for x in range(0,int(size.x)+1,16): draw_line(Vector2(x,0),Vector2(x,size.y),Color(1,1,1,0.09))
		for y in range(0,int(size.y)+1,16): draw_line(Vector2(0,y),Vector2(size.x,y),Color(1,1,1,0.09))
		var mouse := get_local_mouse_position()
		if Rect2(Vector2.ZERO,size).has_point(mouse) and not is_instance_valid(editor.popup):
			var rect := Rect2((mouse/16).floor()*16,Vector2(16,16))
			draw_rect(rect.grow(-0.5),Color.WHITE,false,1)
	func _gui_input(event: InputEvent) -> void:
		if editor.playing or is_instance_valid(editor.popup): return
		if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
			accept_event()
			editor.painting=event.pressed
			editor.erase=event.button_index==MOUSE_BUTTON_RIGHT or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
			editor.last_cell=Vector2i(-1,-1)
			editor.stroke_saved=false
			if event.pressed: editor.paint_at(Vector2i((get_local_mouse_position()/16).floor()))
		elif event is InputEventMouseMotion:
			queue_redraw()
			if editor.painting:
				editor.erase=Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
				editor.paint_at(Vector2i((get_local_mouse_position()/16).floor()))

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	ui=Control.new()
	ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	var top := PanelContainer.new()
	top.name="Toolbar"
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom=TOP
	ui.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation",8)
	top.add_child(bar)
	width_input=add_dimension(bar,"Width")
	height_input=add_dimension(bar,"Height")
	color_button=LevelEditorUI.button("Color",show_color_picker)
	bar.add_child(color_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	import_button=LevelEditorUI.button("Import",show_import)
	bar.add_child(import_button)
	export_button=LevelEditorUI.button("Export",show_export)
	bar.add_child(export_button)
	play_button=LevelEditorUI.button("Play",toggle_play)
	bar.add_child(play_button)
	bar.add_child(LevelEditorUI.button("Publish",request_publish))
	bar.add_child(LevelEditorUI.button("Exit",func(): LevelEditorSession.exit_editor()))
	var bottom := PanelContainer.new()
	bottom.name="PalettePanel"
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top=-BOTTOM
	ui.add_child(bottom)
	var bottom_rows := VBoxContainer.new()
	bottom.add_child(bottom_rows)
	palette=HBoxContainer.new()
	palette.alignment=BoxContainer.ALIGNMENT_CENTER
	palette.add_theme_constant_override("separation",6)
	bottom_rows.add_child(palette)
	add_tool(1,0,"Player")
	add_tool(0,0,"Wall")
	for hue in 4: add_tool(2,hue,PuzzlePalette.NAMES[hue].capitalize()+" block")
	for hue in 4: add_tool(3,hue,PuzzlePalette.NAMES[hue].capitalize()+" key")
	add_tool(10,0,"Clockwise rotator")
	add_tool(11,0,"Counterclockwise rotator")
	var hint := Label.new()
	hint.text="Left click: place    Right click: erase    Space: play / edit    Ctrl+Z: undo"
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size",11)
	bottom_rows.add_child(hint)
	board=Board.new()
	board.editor=self
	board.clip_contents=true
	ui.add_child(board)
	play_view=SubViewportContainer.new()
	play_view.mouse_filter=Control.MOUSE_FILTER_IGNORE
	play_view.hide()
	ui.add_child(play_view)
	play_viewport=SubViewport.new()
	play_viewport.world_2d=World2D.new()
	play_viewport.disable_3d=true
	play_viewport.handle_input_locally=false
	play_view.add_child(play_viewport)
	objective=Label.new()
	objective.text="Complete the puzzle by filling all the squares."
	objective.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	objective.add_theme_font_size_override("font_size",12)
	objective.mouse_filter=Control.MOUSE_FILTER_IGNORE
	objective.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	objective.offset_left=8
	objective.offset_right=-8
	objective.offset_top=-BOTTOM-24
	objective.offset_bottom=-BOTTOM-4
	objective.hide()
	ui.add_child(objective)
	publish_hint=Label.new()
	publish_hint.text="You must complete the puzzle before publishing."
	publish_hint.add_theme_font_size_override("font_size",12)
	publish_hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	publish_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	publish_hint.offset_left=8
	publish_hint.offset_top=-BOTTOM-24
	publish_hint.offset_bottom=-BOTTOM-4
	publish_hint.hide()
	ui.add_child(publish_hint)
	if not is_instance_valid(publisher):
		publisher=LevelPublisher.new()
		publisher.config_path=publisher_settings_path
		add_child(publisher)
	get_viewport().size_changed.connect(layout)
	layout()
	data.grid=[mini(40,int(width_input.max_value)),mini(20,int(height_input.max_value)),16]
	load_draft()
	update_theme()
	sync_controls()
	select_tool(1,0)
	layout()

func add_dimension(bar: HBoxContainer, caption: String) -> SpinBox:
	var label := Label.new()
	label.text=caption
	bar.add_child(label)
	var input := SpinBox.new()
	input.min_value=1
	input.max_value=512
	input.step=1
	input.custom_minimum_size.x=68
	input.get_line_edit().add_theme_font_size_override("font_size",12)
	input.value_changed.connect(resize_grid)
	bar.add_child(input)
	return input

func load_draft() -> void:
	if not initial_level_code.is_empty():
		var initial := LevelEditorCodec.decode(initial_level_code)
		if not initial.is_empty():
			data=initial
			background_color=Color.html(data.color)
		return
	if not FileAccess.file_exists(draft_path): return
	var file := FileAccess.open(draft_path,FileAccess.READ)
	if not file or file.get_length()>LevelEditorCodec.MAX_CELLS*2: return
	var saved := LevelEditorCodec.decode(file.get_as_text())
	if saved.is_empty(): return
	data=saved
	background_color=Color.html(data.color)

func save_draft() -> bool:
	var encoded := LevelEditorCodec.encode(data)
	if encoded.is_empty(): return false
	var file := FileAccess.open(draft_path+".tmp",FileAccess.WRITE)
	if not file: return false
	file.store_string(encoded)
	file.flush()
	var error := file.get_error()
	file.close()
	if error!=OK or DirAccess.rename_absolute(draft_path+".tmp",draft_path)!=OK: return false
	if OS.has_feature("web"): JavaScriptBridge.force_fs_sync()
	return true

func add_tool(kind: int, hue: int, caption: String) -> void:
	var button := LevelEditorUI.button("",func(): select_tool(kind,hue))
	button.custom_minimum_size=Vector2(40,36)
	button.tooltip_text=caption
	button.set_meta("kind",kind)
	button.set_meta("hue",hue)
	palette.add_child(button)
	var preview := LevelEditorIcons.create(kind,hue,background_color)
	preview.name="Preview"
	preview.position=button.custom_minimum_size/2
	preview.scale=Vector2.ONE*1.5
	button.add_child(preview)
	button.resized.connect(func(): preview.position=button.size/2)
	palette_buttons.append(button)

func select_tool(kind: int, hue: int) -> void:
	selected_kind=kind
	selected_hue=hue
	for button in palette_buttons:
		var selected: bool=button.get_meta("kind")==kind and button.get_meta("hue")==hue
		var style: StyleBoxFlat=ui.theme.get_stylebox("normal","Button").duplicate()
		style.border_color=Color.WHITE if selected else background_color.lightened(0.35)
		button.add_theme_stylebox_override("normal",style)
	board.refresh_ghost()
	board.queue_redraw()

func layout() -> void:
	if not board: return
	var size := get_viewport_rect().size
	ui.size=size
	updating=true
	width_input.max_value=clampi(floori((size.x-16)/16),1,512) if fit_grid_to_view else 512
	height_input.max_value=clampi(floori((size.y-TOP-BOTTOM-16)/16),1,512) if fit_grid_to_view else 512
	updating=false
	if data.grid[0]>width_input.max_value or data.grid[1]>height_input.max_value:
		if playing: stop_play()
		remember_edit()
		crop_grid(mini(data.grid[0],int(width_input.max_value)),mini(data.grid[1],int(height_input.max_value)))
	board.size=Vector2(data.grid[0]*16,data.grid[1]*16)
	var fit := minf(1.0,minf((size.x-16)/board.size.x,(size.y-TOP-BOTTOM-16)/board.size.y))
	board.scale=Vector2.ONE*fit
	board.position=Vector2(floorf((size.x-board.size.x*fit)/2),TOP+floorf((size.y-TOP-BOTTOM-board.size.y*fit)/2))
	play_view.position=board.position
	play_view.scale=board.scale
	play_view.size=board.size
	play_viewport.size=Vector2i(board.size)
	sync_controls()

func sync_controls() -> void:
	updating=true
	width_input.value=data.grid[0]
	height_input.value=data.grid[1]
	updating=false
	board.rebuild_visuals()
	board.queue_redraw()

func resize_grid(_value: float) -> void:
	if updating or playing: return
	remember_edit()
	crop_grid(int(width_input.value),int(height_input.value))
	layout()

func crop_grid(width: int, height: int) -> void:
	var before := data.duplicate(true)
	data.grid=[width,height,16]
	data.tiles=data.tiles.filter(func(tile: Array): return tile[0]<width and tile[1]<height)
	data.objects=data.objects.filter(func(item: Array): return item[1]<width*16 and item[2]<height*16)
	if before!=data: invalidate_completion()

func invalidate_completion() -> void:
	verified_level_code=""
	publishing_test=false
	if publish_hint: publish_hint.hide()

func remember_edit() -> void:
	history.append(data.duplicate(true))
	if history.size()>100: history.pop_front()

func undo() -> void:
	if playing or history.is_empty(): return
	var before := data.duplicate(true)
	data=history.pop_back()
	if before!=data: invalidate_completion()
	background_color=Color.html(data.color)
	crop_grid(mini(data.grid[0],int(width_input.max_value)),mini(data.grid[1],int(height_input.max_value)))
	update_theme()
	layout()

func paint_at(cell: Vector2i) -> void:
	if playing or is_instance_valid(popup) or cell==last_cell or cell.x<0 or cell.y<0 or cell.x>=data.grid[0] or cell.y>=data.grid[1]: return
	# Interpolate fast drags so no tiles are skipped between mouse events.
	if last_cell.x>=0:
		var start := last_cell
		var steps := maxi(absi(cell.x-start.x),absi(cell.y-start.y))
		for i in range(1,steps): paint_cell(Vector2i(Vector2(start).lerp(Vector2(cell),float(i)/steps).round()))
	paint_cell(cell)
	last_cell=cell
	board.rebuild_visuals()
	board.queue_redraw()

func paint_cell(cell: Vector2i) -> void:
	var before := data.duplicate(true)
	if not stroke_saved:
		remember_edit()
		stroke_saved=true
	var tile := [cell.x,cell.y]
	var point := Vector2(cell)*16+Vector2(8,8)
	if erase:
		data.tiles.erase(tile)
		data.objects=data.objects.filter(func(item: Array): return Vector2(item[1],item[2])!=point)
	elif selected_kind==0:
		if not data.tiles.has(tile): data.tiles.append(tile)
		data.objects=data.objects.filter(func(item: Array): return Vector2(item[1],item[2])!=point)
	else:
		data.tiles.erase(tile)
		var marker := selected_kind in [3,10,11]
		data.objects=data.objects.filter(func(item: Array):
			if selected_kind==1 and item[0]==1: return false
			return Vector2(item[1],item[2])!=point or (item[0] in [3,10,11])!=marker)
		var item := [selected_kind,point.x,point.y]
		if selected_kind==2: item.append_array([selected_hue,0.2,0.15])
		elif selected_kind==3: item.append_array([selected_hue,"E%d_%d"%[cell.x,cell.y]])
		data.objects.append(item)
	if before!=data: invalidate_completion()

func update_theme() -> void:
	data.color=background_color.to_html(false)
	ui.theme=LevelEditorUI.theme_for(background_color)
	var toolbar_style: StyleBoxFlat=ui.theme.get_stylebox("panel","PanelContainer").duplicate()
	toolbar_style.content_margin_top=6
	toolbar_style.content_margin_bottom=6
	toolbar_style.content_margin_left=8
	toolbar_style.content_margin_right=8
	ui.get_node("Toolbar").add_theme_stylebox_override("panel",toolbar_style)
	RenderingServer.set_default_clear_color(background_color.darkened(0.4))
	if play_viewport: play_viewport.transparent_bg=false
	for button in palette_buttons:
		if button.get_meta("kind")==0: button.get_node("Preview").material.set_shader_parameter("tile_color",background_color.darkened(0.72))
	select_tool(selected_kind,selected_hue)
	board.rebuild_visuals()
	board.queue_redraw()

func close_popup() -> void:
	cooldown_label=null
	if is_instance_valid(cooldown_timer): cooldown_timer.queue_free()
	cooldown_timer=null
	if is_instance_valid(popup):
		ui.remove_child(popup)
		popup.queue_free()
	popup=null
	get_tree().paused=false

func show_message(message: String) -> void:
	close_popup()
	get_tree().paused=true
	popup=LevelEditorUI.modal(ui,background_color,message,{"Back":close_popup})
	popup.cancel_action=close_popup

func show_color_picker() -> void:
	if playing: return
	close_popup()
	popup=LevelEditorUI.modal(ui,background_color,"Level color",{"Back":close_popup})
	popup.cancel_action=close_popup
	var picker := ColorPicker.new()
	picker.edit_alpha=false
	picker.color_modes_visible=false
	picker.sliders_visible=false
	picker.presets_visible=false
	picker.sampler_visible=false
	picker.add_theme_constant_override("sv_width",220)
	picker.add_theme_constant_override("sv_height",220)
	picker.color=background_color
	picker.custom_minimum_size=Vector2(280,260)
	popup.rows.add_child(picker)
	popup.rows.move_child(picker,1)
	remember_edit()
	picker.color_changed.connect(func(color: Color):
		if data.color!=color.to_html(false): invalidate_completion()
		background_color=color
		update_theme()
		popup.theme=LevelEditorUI.theme_for(color))

func show_import() -> void:
	if playing: return
	close_popup()
	popup=LevelEditorUI.modal(ui,background_color,"Paste a level code",{"Back":close_popup})
	popup.cancel_action=close_popup
	var input := TextEdit.new()
	input.custom_minimum_size=Vector2(540,140)
	input.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
	popup.rows.add_child(input)
	popup.rows.move_child(input,1)
	var error := Label.new()
	error.add_theme_font_size_override("font_size",12)
	popup.rows.add_child(error)
	popup.rows.move_child(error,2)
	popup.actions.add_child(LevelEditorUI.button("Import",func():
		var imported := LevelEditorCodec.decode(input.text)
		if imported.is_empty():
			error.text="Invalid or damaged level string."
			return
		if imported.grid[0]>width_input.max_value or imported.grid[1]>height_input.max_value:
			error.text="Level is too large for this view (maximum %d × %d)."%[width_input.max_value,height_input.max_value]
			return
		remember_edit()
		if LevelEditorCodec.encode(data)!=LevelEditorCodec.encode(imported): invalidate_completion()
		data=imported
		background_color=Color.html(data.color)
		close_popup()
		update_theme()
		layout()))
	input.grab_focus()

func show_export() -> void:
	if playing: return
	close_popup()
	var encoded := LevelEditorCodec.encode(data)
	popup=LevelEditorUI.modal(ui,background_color,"Copy this code somewhere safe",{"Back":close_popup})
	popup.cancel_action=close_popup
	var output := TextEdit.new()
	output.text=encoded
	output.editable=false
	output.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
	output.custom_minimum_size=Vector2(540,140)
	popup.rows.add_child(output)
	popup.rows.move_child(output,1)
	popup.actions.add_child(LevelEditorUI.button("Copy",func(): DisplayServer.clipboard_set(encoded)))
	output.grab_focus()
	output.select_all()

func toggle_play() -> void:
	if is_instance_valid(popup): return
	if playing: stop_play()
	elif not LevelData.valid(data): show_message("Place one player before playing your level.")
	else: start_play()

func start_play() -> void:
	painting=false
	test_level_code=LevelEditorCodec.encode(data)
	playing=true
	play_frames=0
	world=Node2D.new()
	world.process_mode=Node.PROCESS_MODE_PAUSABLE
	var walls := TileMapLayer.new()
	walls.name="Walls"
	walls.tile_set=preload("res://assets/walls.tres")
	var material := ShaderMaterial.new()
	material.shader=preload("res://shaders/walls.gdshader")
	material.set_shader_parameter("tile_color",background_color.darkened(0.72))
	walls.material=material
	world.add_child(walls)
	var objects := Node2D.new()
	objects.name="Objects"
	world.add_child(objects)
	play_viewport.add_child(world)
	set_meta("effects_root",world)
	set_meta("fall_limit",data.grid[1]*16+32)
	LevelData.apply(world,data)
	play_view.show()
	board.hide()
	set_edit_enabled(false)
	play_button.text="Edit"
	objective.visible=not publishing_test
	publish_hint.visible=publishing_test

func stop_play() -> void:
	if not playing: return
	playing=false
	publishing_test=false
	if is_instance_valid(world):
		play_viewport.remove_child(world)
		world.queue_free()
	world=null
	remove_meta("effects_root")
	play_view.hide()
	board.show()
	set_edit_enabled(true)
	play_button.text="Play"
	objective.hide()
	publish_hint.hide()
	board.queue_redraw()

func set_edit_enabled(enabled: bool) -> void:
	width_input.editable=enabled
	height_input.editable=enabled
	width_input.get_line_edit().release_focus()
	height_input.get_line_edit().release_focus()
	for button in [color_button,import_button,export_button]+palette_buttons: button.disabled=not enabled

func _process(_delta: float) -> void:
	if painting and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): painting=false
	if not playing or get_tree().paused: return
	play_frames+=1
	if play_frames<3: return
	var pads := get_tree().get_nodes_in_group("pads")
	var has_pad := false
	for pad in pads:
		if not world.is_ancestor_of(pad): continue
		has_pad=true
		if not pad.filled: return
	if not has_pad: return
	var open_upload := publishing_test
	verified_level_code=test_level_code if LevelEditorCodec.encode(data)==test_level_code else ""
	stop_play()
	if open_upload: show_upload_prompt()
	else: show_message("Good job!\n\n You beat the level!")

func request_publish() -> void:
	if is_instance_valid(popup): return
	if publisher.cooldown_remaining()>0:
		show_message(publisher.cooldown_message())
		cooldown_label=popup.rows.get_child(0)
		start_cooldown_timer()
		return
	if not verified_level_code.is_empty() and verified_level_code==LevelEditorCodec.encode(data):
		stop_play()
		show_upload_prompt()
		return
	get_tree().paused=true
	popup=LevelEditorUI.modal(ui,background_color,"You must complete the puzzle before publishing",{"Okay":begin_publish_test})
	popup.cancel_action=close_popup

func begin_publish_test() -> void:
	close_popup()
	var has_key := false
	for item in data.objects:
		if item[0]==3: has_key=true
	if not LevelData.valid(data) or not has_key:
		show_message("Place one player and at least one key before publishing your level.")
		return
	publishing_test=true
	if not playing: start_play()
	objective.hide()
	publish_hint.show()

func show_upload_prompt() -> void:
	if verified_level_code.is_empty() or verified_level_code!=LevelEditorCodec.encode(data):
		request_publish()
		return
	close_popup()
	get_tree().paused=true
	upload_request_id=""
	upload_payload=""
	popup=LevelEditorUI.modal(ui,background_color,"Publish puzzle",{})
	popup.cancel_action=func():
		if not publisher.uploading: close_popup()
	for caption in ["Puzzle Name","Author","Description (100 characters)"]:
		var row := VBoxContainer.new()
		var label := Label.new()
		label.text=caption
		row.add_child(label)
		var input := LineEdit.new()
		input.custom_minimum_size.x=320
		input.max_length=80 if caption=="Puzzle Name" else 40 if caption=="Author" else 100
		row.add_child(input)
		popup.rows.add_child(row)
		popup.rows.move_child(row,popup.rows.get_child_count()-2)
		if caption=="Puzzle Name": upload_name=input
		elif caption=="Author": upload_author=input
		else: upload_description=input
	var meta: Dictionary=data.get("metadata",{})
	upload_name.text=str(meta.get("n",""))
	upload_author.text=str(meta.get("a",publisher.last_author))
	upload_description.text=str(meta.get("d",""))
	upload_error=Label.new()
	upload_error.custom_minimum_size.x=320
	upload_error.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	popup.rows.add_child(upload_error)
	popup.rows.move_child(upload_error,popup.rows.get_child_count()-2)
	upload_back=LevelEditorUI.button("Back",close_popup)
	popup.actions.add_child(upload_back)
	upload_button=LevelEditorUI.button("Publish",upload_level)
	popup.actions.add_child(upload_button)
	upload_name.grab_focus()
	start_cooldown_timer()

func start_cooldown_timer() -> void:
	if is_instance_valid(cooldown_timer): cooldown_timer.queue_free()
	cooldown_timer=Timer.new()
	cooldown_timer.process_mode=Node.PROCESS_MODE_ALWAYS
	cooldown_timer.wait_time=0.2
	popup.add_child(cooldown_timer)
	cooldown_timer.timeout.connect(update_cooldown)
	cooldown_timer.start()
	update_cooldown()

func update_cooldown() -> void:
	var remaining := publisher.cooldown_remaining()
	if is_instance_valid(cooldown_label):
		cooldown_label.text=publisher.cooldown_message() if remaining>0 else "You can publish now."
		return
	if not is_instance_valid(upload_button) or publisher.uploading: return
	upload_button.disabled=remaining>0
	upload_button.text="Publish (%d:%02d)"%[remaining/60,remaining%60] if remaining>0 else "Publish"
	if remaining>0: upload_error.text=publisher.cooldown_message()
	elif upload_error.text.begins_with("Please wait "): upload_error.text=""

func upload_level() -> void:
	if publisher.uploading: return
	var puzzle_name := upload_name.text.strip_edges()
	var author := upload_author.text.strip_edges()
	if puzzle_name.is_empty() or author.is_empty():
		upload_error.text="Enter a Puzzle Name and Author."
		return
	var encoded := LevelEditorCodec.encode(data)
	if verified_level_code.is_empty() or verified_level_code!=encoded:
		close_popup()
		request_publish()
		return
	# Keep the same request ID on retries after an uncertain network response.
	var payload := JSON.stringify([puzzle_name,author,upload_description.text,encoded])
	if payload!=upload_payload:
		upload_payload=payload
		upload_request_id=Crypto.new().generate_random_bytes(16).hex_encode()
	upload_button.disabled=true
	upload_back.disabled=true
	upload_name.editable=false
	upload_author.editable=false
	upload_description.editable=false
	upload_button.text="Publishing..."
	upload_error.text=""
	var result: Dictionary=await publisher.publish(puzzle_name,author,encoded,upload_request_id,upload_description.text,cloud_level_id,cloud_revision)
	if result.get("ok",false):
		data.metadata={"n":puzzle_name,"a":author,"d":upload_description.text}
		verified_level_code=LevelEditorCodec.encode(data)
		if not cloud_level_id.is_empty(): cloud_revision=int(result.get("revision",cloud_revision))
		show_message("Puzzle published!")
		return
	upload_button.disabled=false
	upload_back.disabled=false
	upload_name.editable=true
	upload_author.editable=true
	upload_description.editable=true
	upload_button.text="Publish"
	upload_error.text=result.get("error","Couldn't publish the puzzle. Please try again.")

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if is_instance_valid(popup): return
	var code: int=event.physical_keycode if event.physical_keycode else event.keycode
	if code==KEY_SPACE:
		get_viewport().set_input_as_handled()
		Input.action_release("jump")
		toggle_play()
	elif code==KEY_Z and (event.ctrl_pressed or event.meta_pressed):
		var focus := get_viewport().gui_get_focus_owner()
		if focus is LineEdit or focus is TextEdit: return
		get_viewport().set_input_as_handled()
		undo()

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		painting=false
		last_cell=Vector2i(-1,-1)
