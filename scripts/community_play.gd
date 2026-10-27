extends "res://scripts/level_editor.gd"

var entry: Dictionary={}
var replay_code := ""
var track := ReplayTrack.new()
var ready_to_play := false
var completed := false
var input_mask := 0
var run_id := ""
var timeline: HSlider
var time_label: Label
var replay_frame := 0
var replay_paused := false
var timeline_updating := false
var dragging_timeline := false
var pause_button: Button
var feedback: Label
var replay_author: LineEdit
var replay_comment: LineEdit
var like_button: Button
var dislike_button: Button
var save_replay_button: Button
var feedback_back: Button
var selected_vote: Variant=null
var saving_feedback := false

class Recorder extends Node:
	var host: Node
	func _physics_process(delta: float) -> void: host.after_physics(delta)

func _ready() -> void:
	initial_level_code=str(entry.get("levelString",""))
	fit_grid_to_view=false
	super._ready()
	process_physics_priority=-1000
	ui.get_node("Toolbar").hide()
	ui.get_node("PalettePanel").hide()
	var title := Label.new()
	var meta: Dictionary=data.get("metadata",{})
	title.text=str(meta.get("n","Puzzle"))+" — "+str(meta.get("a",""))
	title.position=Vector2(12,8)
	title.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ui.add_child(title)
	var footer := HBoxContainer.new()
	ui.add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_left=12
	footer.offset_right=-12
	footer.offset_top=-44
	footer.offset_bottom=-8
	if not replay_code.is_empty():
		pause_button=LevelEditorUI.button("Pause",func():
			replay_paused=not replay_paused
			if not replay_paused and replay_frame>=track.frames.size()-1: seek_replay(0)
			pause_button.text="Play" if replay_paused else "Pause")
		footer.add_child(pause_button)
		timeline=HSlider.new()
		timeline.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		timeline.min_value=0
		timeline.step=1
		footer.add_child(timeline)
		timeline.value_changed.connect(func(value: float):
			if not timeline_updating and ready_to_play: seek_replay(int(value)))
		timeline.drag_started.connect(func(): dragging_timeline=true)
		timeline.drag_ended.connect(func(_changed: bool): dragging_timeline=false)
		time_label=Label.new()
		footer.add_child(time_label)
	else:
		var credit := Label.new()
		credit.name="WebsiteCredit"
		credit.text="snugglefox.net"
		credit.add_theme_font_size_override("font_size",10)
		credit.add_theme_color_override("font_color",Color.WHITE)
		credit.mouse_filter=Control.MOUSE_FILTER_IGNORE
		credit.size_flags_vertical=Control.SIZE_SHRINK_END
		footer.add_child(credit)
		var spacer := Control.new()
		spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		footer.add_child(spacer)
	footer.add_child(LevelEditorUI.button("Back",go_back))
	if not LevelData.valid(data):
		show_message("This puzzle is invalid.")
		return
	start_play()
	world.process_mode=Node.PROCESS_MODE_DISABLED
	run_id=Crypto.new().generate_random_bytes(16).hex_encode()
	var recorder := Recorder.new()
	recorder.host=self
	recorder.process_physics_priority=1000
	add_child(recorder)
	call_deferred("prepare_play")

func prepare_play() -> void:
	# Let deferred welds and home markers initialize before recording frame zero.
	await get_tree().process_frame
	if not is_inside_tree(): return
	track.bind(world)
	for actor in track.actors:
		if actor.is_in_group("player"):
			actor.allow_noclip=false
			actor.input_source=self
		if actor.is_in_group("pads"): actor.set_process(false)
	if replay_code.is_empty():
		track.capture(0)
		world.process_mode=Node.PROCESS_MODE_PAUSABLE
		publisher.start_attempt(str(entry.id),int(entry.revision),run_id)
	else:
		var recording := ReplayTrack.decode(replay_code)
		if recording.is_empty() or not track.load_recording(recording):
			show_message("This replay is invalid or uses an unsupported version.")
			return
		timeline.max_value=track.frames.size()-1
		objective.hide()
	ready_to_play=true
	if not replay_code.is_empty(): seek_replay(0)

func _process(_delta: float) -> void:
	pass

func _physics_process(_delta: float) -> void:
	if not ready_to_play or get_tree().paused: return
	if replay_code.is_empty():
		input_mask=ReplayTrack.inputs() if not completed else 0
	elif not replay_paused and not dragging_timeline:
		if replay_frame<track.frames.size()-1:
			seek_replay(track.next_frame(replay_frame))
			if replay_frame==track.frames.size()-1:
				replay_paused=true
				pause_button.text="Play"
				Juice.sound("victory")
		else:
			replay_paused=true
			pause_button.text="Play"

func after_physics(delta: float) -> void:
	if not ready_to_play or completed or get_tree().paused or not replay_code.is_empty(): return
	var all_filled := true
	var has_pad := false
	for actor in track.actors:
		if actor.is_in_group("pads"):
			actor._process(delta)
			has_pad=true
			if not actor.filled: all_filled=false
	track.capture(input_mask)
	if has_pad and all_filled and track.frames.size()>3:
		completed=true
		call_deferred("show_completion")

func input_axis() -> float:
	return float((input_mask>>1)&1)-float(input_mask&1)

func action_just_pressed(action: String) -> bool:
	var index := ReplayTrack.ACTIONS.find(action)
	return index>=0 and (input_mask&(1<<(index+8)))!=0

func seek_replay(frame: int) -> void:
	replay_frame=clampi(frame,0,track.frames.size()-1)
	input_mask=track.seek(replay_frame)
	timeline_updating=true
	timeline.value=replay_frame
	timeline_updating=false
	time_label.text=CommunityBrowser.format_time(replay_frame/60.0)+" / "+CommunityBrowser.format_time((track.frames.size()-1)/60.0)

func show_completion() -> void:
	get_tree().paused=true
	popup=LevelEditorUI.modal(ui,background_color,"Rate",{})
	Juice.sound("victory")
	popup.cancel_action=go_back
	var votes := HBoxContainer.new()
	votes.alignment=BoxContainer.ALIGNMENT_CENTER
	like_button=LevelEditorUI.button("Like",func(): choose_vote(1))
	dislike_button=LevelEditorUI.button("Dislike",func(): choose_vote(-1))
	for button in [like_button,dislike_button]:
		button.toggle_mode=true
		votes.add_child(button)
	insert_prompt_row(votes)
	for caption in ["Say something nice","Author"]:
		var row := VBoxContainer.new()
		var label := Label.new()
		label.text="Say something nice (40 characters)" if caption=="Say something nice" else caption
		row.add_child(label)
		var input := LineEdit.new()
		input.max_length=ReplayTrack.MAX_COMMENT_LENGTH if caption=="Say something nice" else 40
		input.custom_minimum_size.x=340
		row.add_child(input)
		insert_prompt_row(row)
		if caption=="Author":
			replay_author=input
			input.placeholder_text="Anonymous"
		else: replay_comment=input
	feedback=Label.new()
	feedback.custom_minimum_size.x=340
	feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	insert_prompt_row(feedback)
	feedback_back=LevelEditorUI.button("Back",go_back)
	popup.actions.add_child(feedback_back)
	save_replay_button=LevelEditorUI.button("Save Replay",save_replay)
	popup.actions.add_child(save_replay_button)
	# Completion counts even when the player chooses not to save a replay.
	saving_feedback=true
	like_button.disabled=true
	dislike_button.disabled=true
	save_replay_button.disabled=true
	feedback_back.disabled=true
	feedback.text="Saving completion..."
	report_completion()

func insert_prompt_row(row: Control) -> void:
	popup.rows.add_child(row)
	popup.rows.move_child(row,popup.rows.get_child_count()-2)

func report_completion() -> void:
	var result := await publisher.complete(str(entry.id),int(entry.revision),run_id)
	if not is_inside_tree() or not is_instance_valid(feedback): return
	saving_feedback=false
	like_button.disabled=false
	dislike_button.disabled=false
	save_replay_button.disabled=false
	feedback_back.disabled=false
	feedback.text=str(result.get("error",""))

func choose_vote(value: int) -> void:
	if saving_feedback: return
	selected_vote=0 if selected_vote==value else value
	like_button.button_pressed=selected_vote==1
	dislike_button.button_pressed=selected_vote== -1
	saving_feedback=true
	like_button.disabled=true
	dislike_button.disabled=true
	save_replay_button.disabled=true
	feedback_back.disabled=true
	feedback.text="Saving vote..."
	var result := await publisher.complete(str(entry.id),int(entry.revision),run_id,selected_vote)
	if not is_inside_tree(): return
	saving_feedback=false
	like_button.disabled=false
	dislike_button.disabled=false
	save_replay_button.disabled=false
	feedback_back.disabled=false
	feedback.text=str(result.get("error",""))

func save_replay() -> void:
	if saving_feedback: return
	if track.full:
		feedback.text="This run is too long to save as a replay."
		return
	var code := track.encode(str(entry.levelString),replay_author.text,replay_comment.text)
	if code.is_empty():
		feedback.text="This replay is too large to upload."
		return
	saving_feedback=true
	save_replay_button.disabled=true
	feedback_back.disabled=true
	like_button.disabled=true
	dislike_button.disabled=true
	replay_author.editable=false
	replay_comment.editable=false
	feedback.text="Saving replay..."
	var result := await publisher.complete(str(entry.id),int(entry.revision),run_id,selected_vote,code)
	if not is_inside_tree(): return
	saving_feedback=false
	save_replay_button.disabled=false
	feedback_back.disabled=false
	like_button.disabled=false
	dislike_button.disabled=false
	replay_author.editable=true
	replay_comment.editable=true
	if result.has("error"):
		feedback.text=str(result.error)
		return
	LevelEditorSession.return_replays=entry
	go_back()

func go_back() -> void:
	if saving_feedback: return
	LevelEditorSession.exit_editor()

func save_draft() -> bool:
	return true

func _input(event: InputEvent) -> void:
	# Replay playback consumes only the recorded action mask. Live keys never
	# reach the editor's Space/undo shortcuts or any replay physics bodies.
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE and not is_instance_valid(popup):
		get_viewport().set_input_as_handled()
		go_back()
