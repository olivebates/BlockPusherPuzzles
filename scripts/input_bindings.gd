extends Node
signal changed
const DEFAULTS = {"left":[KEY_A,KEY_LEFT],"right":[KEY_D,KEY_RIGHT],"jump":[KEY_SPACE,KEY_W,KEY_UP],"down":[KEY_S,KEY_DOWN],"reset_block":[KEY_R],"recall_player":[KEY_Q],"gentle":[KEY_M],"interact":[KEY_E],"map":[KEY_TAB]}
const NAMES = {"left":"Move left","right":"Move right","jump":"Jump","down":"Look down","reset_block":"Recall object","recall_player":"Recall platform","gentle":"Gentle effects","interact":"Talk","map":"Map"}
const PATH = "user://keybinds.cfg"
func _ready() -> void: load_bindings()
func key_event(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event
func load_bindings() -> void:
	var config := ConfigFile.new()
	config.load(PATH)
	for action in DEFAULTS:
		if not InputMap.has_action(action): InputMap.add_action(action)
		var events: Array[InputEvent] = []
		var stored: Variant = config.get_value("bindings",action,false)
		if stored is Array:
			for token in stored.slice(0,3):
				if not token is Array or token.size()!=2: continue
				if token[0]=="key" and token[1] is int and token[1]>0: events.append(key_event(token[1]))
				elif token[0]=="mouse" and token[1] is int and token[1]>0:
					var event := InputEventMouseButton.new()
					event.button_index = token[1]
					events.append(event)
		else:
			for code in DEFAULTS[action]: events.append(key_event(code))
		install(action,events)
	changed.emit()
func install(action: String, events: Array[InputEvent]) -> void:
	InputMap.action_erase_events(action)
	for event in events.slice(0,3):
		if not InputMap.action_has_event(action,event): InputMap.action_add_event(action,event)
func set_slot(action: String, slot: int, event: InputEvent) -> void:
	if not DEFAULTS.has(action) or slot<0 or slot>2: return
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	if slot<events.size(): events.remove_at(slot)
	if event!=null:
		if event is InputEventKey:
			event = key_event(event.physical_keycode if event.physical_keycode else event.keycode)
		elif event is InputEventMouseButton:
			var mouse := InputEventMouseButton.new()
			mouse.button_index = event.button_index
			event = mouse
		else: return
		events.insert(mini(slot,events.size()),event)
	install(action,events)
	save_bindings()
	changed.emit()
func save_bindings() -> void:
	var config := ConfigFile.new()
	for action in DEFAULTS:
		var tokens: Array = []
		for event in InputMap.action_get_events(action):
			if event is InputEventKey: tokens.append(["key",int(event.physical_keycode if event.physical_keycode else event.keycode)])
			elif event is InputEventMouseButton: tokens.append(["mouse",int(event.button_index)])
		config.set_value("bindings",action,tokens)
	config.save(PATH)
	if OS.has_feature("web"): JavaScriptBridge.force_fs_sync()
func reset_defaults() -> void:
	for action in DEFAULTS:
		var events: Array[InputEvent] = []
		for code in DEFAULTS[action]: events.append(key_event(code))
		install(action,events)
	save_bindings()
	changed.emit()
func event_label(event: InputEvent) -> String:
	if event is InputEventKey: return OS.get_keycode_string(event.physical_keycode if event.physical_keycode else event.keycode)
	if event is InputEventMouseButton: return "Mouse %d" % event.button_index
	return "â€”"
func prompt(action: String) -> String:
	var events := InputMap.action_get_events(action)
	return event_label(events[0]) if not events.is_empty() else "â€”"


