class_name LevelEditorUI
extends RefCounted

static func theme_for(color: Color) -> Theme:
	var theme := Theme.new()
	theme.default_font_size=13
	var panel := StyleBoxFlat.new()
	panel.bg_color=color
	panel.border_color=color.lightened(0.55)
	panel.set_border_width_all(1)
	panel.set_content_margin_all(12)
	theme.set_stylebox("panel","PanelContainer",panel)
	for state in ["normal","hover","pressed","disabled","focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color=color.lightened(0.16 if state in ["hover","pressed"] else 0.04)
		box.border_color=color.lightened(0.65 if state=="focus" else 0.35)
		box.set_border_width_all(1)
		box.set_content_margin_all(6)
		theme.set_stylebox(state,"Button",box)
	for type in ["Label","Button","LineEdit","TextEdit","SpinBox"]:
		theme.set_color("font_color",type,color.lightened(0.9))
	return theme

static func button(text: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text=text
	result.focus_mode=Control.FOCUS_NONE
	result.pressed.connect(callback)
	return result

# Canvas controls keep every popup inside the game viewport, including on web.
class Modal extends Control:
	var panel: PanelContainer
	var rows: VBoxContainer
	var actions: HBoxContainer
	var cancel_action: Callable
	func _init(color: Color, message: String, choices: Dictionary) -> void:
		process_mode=Node.PROCESS_MODE_ALWAYS
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		theme=LevelEditorUI.theme_for(color)
		var shade := ColorRect.new()
		shade.color=Color(0,0,0,0.65)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(shade)
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter=Control.MOUSE_FILTER_IGNORE
		add_child(center)
		panel=PanelContainer.new()
		center.add_child(panel)
		rows=VBoxContainer.new()
		rows.add_theme_constant_override("separation",14)
		panel.add_child(rows)
		if not message.is_empty():
			var label := Label.new()
			label.text=message
			label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			rows.add_child(label)
		actions=HBoxContainer.new()
		actions.alignment=BoxContainer.ALIGNMENT_CENTER
		actions.add_theme_constant_override("separation",12)
		rows.add_child(actions)
		for caption in choices:
			actions.add_child(LevelEditorUI.button(caption,choices[caption]))
	func _input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if cancel_action.is_valid(): cancel_action.call()

static func modal(parent: Node, color: Color, message: String, choices: Dictionary) -> Modal:
	var result := Modal.new(color,message,choices)
	parent.add_child(result)
	return result
