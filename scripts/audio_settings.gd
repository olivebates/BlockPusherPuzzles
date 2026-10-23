extends CanvasLayer
var menu: AcceptDialog
var was_paused := false
var menu_open := false
var binding_buttons := {}
var capture_action := ""
var capture_slot := -1
var capture_hint: Label
var backup_picker: OptionButton
var delete_button: Button
var delete_confirmation: ConfirmationDialog
var delete_stage := 0
var restore_confirmation: ConfirmationDialog
var backup_path := ""
func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	var gear := Button.new()
	gear.name = "AudioSettingsButton"
	gear.icon = load("res://assets/gear.svg")
	gear.tooltip_text = ""
	gear.focus_mode = Control.FOCUS_NONE
	gear.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	gear.offset_left = -44
	gear.offset_right = -8
	gear.offset_top = 8
	gear.offset_bottom = 44
	add_child(gear)
	menu = AcceptDialog.new()
	menu.title = ""
	menu.min_size = Vector2i(600,400)
	menu.borderless = true
	menu.get_ok_button().hide()
	add_child(menu)
	menu.about_to_popup.connect(func():
		was_paused = get_tree().paused
		menu_open = true
		get_tree().paused = true)
	menu.visibility_changed.connect(func():
		if not menu.visible and menu_open:
			capture_action = ""
			refresh_bindings()
			menu_open = false
			get_tree().paused = was_paused)
	var rows := VBoxContainer.new()
	menu.add_child(rows)
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_END
	rows.add_child(header)
	var close := Button.new()
	close.icon = load("res://assets/settings_close.svg")
	close.pressed.connect(menu.hide)
	header.add_child(close)
	for bus_name in ["Music","SFX"]:
		var title := Label.new()
		title.text = "Music" if bus_name=="Music" else "Sound Effects"
		rows.add_child(title)
		var line := HBoxContainer.new()
		rows.add_child(line)
		var slider := HSlider.new()
		slider.name = bus_name+"Volume"
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.custom_minimum_size.x = 260
		slider.value = Juice.volumes[bus_name]*100
		line.add_child(slider)
		slider.value_changed.connect(func(amount: float): Juice.set_volume(bus_name,amount/100))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560,210)
	rows.add_child(scroll)
	var bindings := VBoxContainer.new()
	bindings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(bindings)
	for action in InputBindings.DEFAULTS:
		var row := HBoxContainer.new()
		bindings.add_child(row)
		var name_label := Label.new()
		name_label.text = InputBindings.NAMES[action]
		name_label.custom_minimum_size.x = 155
		row.add_child(name_label)
		binding_buttons[action] = []
		for slot in 3:
			var button := Button.new()
			button.custom_minimum_size.x = 110
			button.focus_mode = Control.FOCUS_NONE
			button.pressed.connect(func():
				capture_action = action
				capture_slot = slot
				capture_hint.text = ""
				refresh_bindings())
			row.add_child(button)
			binding_buttons[action].append(button)
	capture_hint = Label.new()
	capture_hint.text = ""
	rows.add_child(capture_hint)
	var reset := Button.new()
	reset.icon = load("res://assets/settings_reset.svg")
	reset.pressed.connect(InputBindings.reset_defaults)
	rows.add_child(reset)
	var footer := HBoxContainer.new()
	rows.add_child(footer)
	delete_button=Button.new()
	delete_button.text="Delete Progresse"
	delete_button.add_theme_font_size_override("font_size",12)
	var delete_style := StyleBoxFlat.new()
	delete_style.bg_color=Color("852b34")
	delete_style.border_color=Color("4c1820")
	delete_style.set_border_width_all(1)
	delete_style.set_content_margin_all(5)
	delete_button.add_theme_stylebox_override("normal",delete_style)
	delete_button.pressed.connect(func():
		delete_stage=1
		show_delete_confirmation())
	footer.add_child(delete_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	backup_picker=OptionButton.new()
	backup_picker.custom_minimum_size.x=260
	backup_picker.item_selected.connect(select_backup)
	footer.add_child(backup_picker)
	delete_confirmation=ConfirmationDialog.new()
	delete_confirmation.title="Delete progress"
	delete_confirmation.confirmed.connect(confirm_delete)
	delete_confirmation.canceled.connect(func(): delete_stage=0)
	menu.add_child(delete_confirmation)
	restore_confirmation=ConfirmationDialog.new()
	restore_confirmation.dialog_text="Restore this backup? This replaces the current progress."
	restore_confirmation.confirmed.connect(func():
		menu.hide()
		Progress.restore_backup(backup_path))
	menu.add_child(restore_confirmation)
	Progress.backups_changed.connect(refresh_backups)
	refresh_backups()
	InputBindings.changed.connect(refresh_bindings)
	menu.window_input.connect(capture_binding)
	refresh_bindings()
	gear.pressed.connect(func(): menu.popup_centered())
func refresh_backups() -> void:
	backup_picker.clear()
	backup_picker.add_item("Backups")
	for backup in Progress.list_backups():
		var stamp := Time.get_datetime_string_from_unix_time(int(backup.time)).replace("T"," ")
		backup_picker.add_item(("10 min · " if backup.kind=="timed" else "Launch · ")+stamp+" UTC")
		backup_picker.set_item_metadata(backup_picker.item_count-1,backup.path)
	backup_picker.select(0)
func select_backup(index: int) -> void:
	if index==0: return
	backup_path=backup_picker.get_item_metadata(index)
	restore_confirmation.popup_centered()
	backup_picker.select(0)
func show_delete_confirmation() -> void:
	delete_confirmation.dialog_text=["Delete your saved progress? (1/3)","This also deletes all progress backups. Continue? (2/3)","Permanently delete progress and start over? (3/3)"][delete_stage-1]
	delete_confirmation.popup_centered()
func confirm_delete() -> void:
	if delete_stage<1: return
	if delete_stage<3:
		delete_stage+=1
		call_deferred("show_delete_confirmation")
	else:
		delete_stage=0
		menu.hide()
		Progress.call_deferred("delete_progress")
func refresh_bindings() -> void:
	for action in binding_buttons:
		var events := InputMap.action_get_events(action)
		for slot in 3:
			binding_buttons[action][slot].text = InputBindings.event_label(events[slot]) if slot<events.size() else ""
			binding_buttons[action][slot].modulate = Color(1.4,1.4,1.4) if capture_action==action and capture_slot==slot else Color.WHITE
func _process(_delta: float) -> void:
	if not menu.visible: return
	var level := get_tree().current_scene
	if not level: return
	var panel := StyleBoxFlat.new()
	panel.bg_color = level.background_color
	panel.border_color = level.tile_color.darkened(0.35)
	panel.set_border_width_all(1)
	panel.set_content_margin_all(12)
	menu.add_theme_stylebox_override("panel",panel)
func _input(event: InputEvent) -> void: capture_binding(event)
func capture_binding(event: InputEvent) -> void:
	if capture_action.is_empty() or not event.is_pressed() or event.is_echo(): return
	if not event is InputEventKey and not event is InputEventMouseButton: return
	var action := capture_action
	var slot := capture_slot
	capture_action = ""
	if event is InputEventKey and event.keycode==KEY_ESCAPE:
		refresh_bindings()
	elif event is InputEventKey and event.keycode in [KEY_DELETE,KEY_BACKSPACE]: InputBindings.set_slot(action,slot,null)
	else: InputBindings.set_slot(action,slot,event)
	capture_hint.text = ""
	menu.set_input_as_handled()
	get_viewport().set_input_as_handled()

