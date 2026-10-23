extends CanvasLayer
var active := false
var lines: Array=[]
var line_index := 0
var dialogue_id := ""
var pending: Array=[]
var old_pause := false
var panel: PanelContainer
var speaker: Label
var words: RichTextLabel
var portrait: TextureRect
var advance: Label
var pointer: Control
var chatter: AudioStreamPlayer
var chatter_streams := {}
var chatter_index := 0
var full_text := ""
var revealed := 0
var reveal_wait := 0.0
var letters_since_chirp := 0
var opening := 0.0
const LETTER_INTERVAL := 1.0/35.0
const OPEN_DURATION := 0.15
class SpeakerPointer extends Control:
	var dialogue: CanvasLayer
	func _draw() -> void: dialogue.draw_pointer(self)
func _ready() -> void:
	layer=100
	process_mode=Node.PROCESS_MODE_ALWAYS
	var shield := ColorRect.new()
	shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shield.color=Color(0,0,0,0.12)
	add_child(shield)
	pointer=SpeakerPointer.new()
	pointer.dialogue=self
	pointer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(pointer)
	panel=PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left=28
	panel.offset_right=-28
	panel.offset_top=-170
	panel.offset_bottom=-24
	add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color=Color("20282e")
	style.border_color=Color("c5aa69")
	style.set_border_width_all(1)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel",style)
	var layout := VBoxContainer.new()
	panel.add_child(layout)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",18)
	layout.add_child(row)
	portrait=TextureRect.new()
	portrait.texture=load("res://assets/playerSprite.png")
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size=Vector2(70,80)
	row.add_child(portrait)
	var column := VBoxContainer.new()
	column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(column)
	speaker=Label.new()
	speaker.add_theme_color_override("font_color",Color("ffd76f"))
	column.add_child(speaker)
	words=RichTextLabel.new()
	words.bbcode_enabled=true
	words.fit_content=true
	words.scroll_active=false
	words.custom_minimum_size.y=52
	words.mouse_filter=Control.MOUSE_FILTER_IGNORE
	words.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	words.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	words.add_theme_font_size_override("normal_font_size",20)
	column.add_child(words)
	advance=Label.new()
	advance.text="Space to continue"
	advance.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	advance.add_theme_font_size_override("font_size",14)
	layout.add_child(advance)
	chatter=AudioStreamPlayer.new()
	chatter.bus="SFX"
	chatter.volume_db=-12
	add_child(chatter)
	for character in ["pip","sunny"]:
		chatter_streams[character]=[]
		for variant in 3:
			chatter_streams[character].append(load("res://assets/audio/fox_%s_%d.wav" % [character,variant+1]))
	hide()
func request_once(id: String, content: Array) -> bool:
	if Progress.dialogues.has(id): return false
	for item in pending:
		if item[0]==id: return false
	if active: pending.append([id,content.duplicate(true)])
	else: begin(id,content)
	return true
func begin(id: String, content: Array, index := 0) -> void:
	if content.is_empty(): return
	if not active: old_pause=get_tree().paused
	active=true
	dialogue_id=id
	lines=content.duplicate(true)
	line_index=clampi(index,0,lines.size()-1)
	if not id.is_empty(): Progress.dialogues[id]=true
	get_tree().paused=true
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		for trigger in get_tree().get_nodes_in_group("color_triggers"):
			if trigger.contains_player(player): trigger.touched(player)
	show()
	opening=0
	display_line()
	_process(0)
func display_line() -> void:
	speaker.text=lines[line_index][0]
	full_text=lines[line_index][1]
	words.text=emphasize(full_text)
	revealed=0
	reveal_wait=LETTER_INTERVAL
	letters_since_chirp=0
	words.visible_characters=0
	advance.modulate.a=0
	chatter.stop()
	portrait.material=null
	if speaker.text==StoryLines.NPC:
		var mat := ShaderMaterial.new()
		mat.shader=load("res://shaders/npc_fox.gdshader")
		portrait.material=mat
func emphasize(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("(?i)\\b(seriously|guys|wait|theory|giant door|no idea|tough|stuck)\\b")
	var result := ""
	var offset := 0
	for match_word in regex.search_all(text):
		result+=escape_markup(text.substr(offset,match_word.get_start()-offset))
		result+="[color=#ffd433]"+escape_markup(match_word.get_string())+"[/color]"
		offset=match_word.get_end()
	return result+escape_markup(text.substr(offset))
func escape_markup(text: String) -> String: return text.replace("[","[lb]")
func punctuation_pause(character: String) -> float:
	if character in [",",";",":"]: return 0.12
	if character in [".","!","?"]: return 0.22
	return 0.0
func revealing() -> bool: return revealed<full_text.length()
func finish_line() -> void:
	revealed=full_text.length()
	words.visible_characters=revealed
	reveal_wait=0
	advance.modulate.a=1
	chatter.stop()
func advance_line() -> void:
	if revealing(): finish_line()
	else: next_line()
func chirp() -> void:
	var character := "sunny" if speaker.text==StoryLines.NPC else "pip"
	chatter.stream=chatter_streams[character][chatter_index%3]
	chatter_index+=1
	chatter.pitch_scale=randf_range(0.96,1.04)
	chatter.play()
	Juice.sound_played.emit("fox_chatter_"+character)
func next_line() -> void:
	if not active: return
	line_index+=1
	if line_index<lines.size(): display_line()
	else:
		stop(false)
		if not pending.is_empty():
			var entry: Array=pending.pop_front()
			begin(entry[0],entry[1])
func stop(clear_queue := true) -> void:
	chatter.stop()
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player:
		player.buffered=0
		player.recall_freeze_frames=maxi(player.recall_freeze_frames,2)
	if active: get_tree().paused=old_pause
	active=false
	hide()
	if clear_queue: pending.clear()
func snapshot() -> Dictionary:
	return {"id":dialogue_id,"lines":lines,"index":line_index,"pending":pending,"revealed":revealed,"wait":reveal_wait} if active else {}
func restore(data: Dictionary) -> void:
	stop()
	if data.is_empty(): return
	pending=data.get("pending",[]).duplicate(true)
	begin(data.get("id",""),data.get("lines",[]),int(data.get("index",0)))
	if LevelData.number(data.get("revealed")):
		revealed=clampi(int(data.revealed),0,full_text.length())
		words.visible_characters=revealed
		if LevelData.number(data.get("wait")): reveal_wait=clampf(data.wait,0,1)
		advance.modulate.a=0 if revealing() else 1
func _input(event: InputEvent) -> void:
	if not active or not event.is_pressed() or event.is_echo(): return
	if event is InputEventKey and (event.physical_keycode if event.physical_keycode else event.keycode)==KEY_SPACE:
		advance_line()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and (event.physical_keycode if event.physical_keycode else event.keycode) in [KEY_ENTER,KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
func _process(delta: float) -> void:
	if not active: return
	opening=minf(opening+delta,OPEN_DURATION)
	var fraction := opening/OPEN_DURATION
	var smooth := 1-pow(1-fraction,3)
	var slide := 0.0 if Juice.reduced_motion else 8*(1-smooth)
	panel.offset_top=-170+slide
	panel.offset_bottom=-24+slide
	panel.modulate.a=smooth
	if revealing():
		reveal_wait-=delta
		var played := false
		while reveal_wait<=0 and revealing():
			var character := full_text[revealed]
			revealed+=1
			reveal_wait+=LETTER_INTERVAL+punctuation_pause(character)
			if character.to_lower()!=character.to_upper() or character.is_valid_int():
				letters_since_chirp+=1
				if letters_since_chirp>=3:
					letters_since_chirp=0
					if not played:
						chirp()
						played=true
		words.visible_characters=revealed
		if not revealing(): advance.modulate.a=1
	pointer.queue_redraw()
	var world := get_tree().current_scene
	if world and world.get("background_color") is Color:
		var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
		style.bg_color=world.background_color
		style.border_color=world.tile_color
func current_speaker() -> Node2D:
	if speaker.text==StoryLines.NPC:
		var closest: Node2D
		var player := get_tree().get_first_node_in_group("player") as Node2D
		for npc in get_tree().get_nodes_in_group("story_npcs"):
			if not closest or (player and npc.global_position.distance_squared_to(player.global_position)<closest.global_position.distance_squared_to(player.global_position)): closest=npc
		return closest
	return get_tree().get_first_node_in_group("player") as Node2D
func draw_pointer(canvas: Control) -> void:
	if not active or panel.modulate.a<=0: return
	var actor := current_speaker()
	if not actor: return
	var screen := actor.get_global_transform_with_canvas().origin
	if not get_viewport().get_visible_rect().has_point(screen): return
	var rect := panel.get_global_rect()
	var x := clampf(roundf(screen.x),rect.position.x+12,rect.end.x-12)
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	# A stepped tail points toward the speaker without covering the world.
	for row in 6:
		var width := 2+row*2
		var point := Vector2(x-width/2.0,rect.position.y-6+row)
		canvas.draw_rect(Rect2(point,Vector2(width,1)),Color(style.border_color,panel.modulate.a))
		if width>2: canvas.draw_rect(Rect2(point+Vector2.RIGHT,Vector2(width-2,1)),Color(style.bg_color,panel.modulate.a))
	var marker := (screen+Vector2(0,-26)).round()
	if rect.grow(8).has_point(marker): return
	var color := Color(1,0.83,0.2,panel.modulate.a)
	canvas.draw_rect(Rect2(marker+Vector2(-3,-2),Vector2(6,2)),color)
	canvas.draw_rect(Rect2(marker+Vector2(-2,0),Vector2(4,2)),color)
	canvas.draw_rect(Rect2(marker+Vector2(-1,2),Vector2(2,2)),color)
