extends SceneTree
var failures := 0

class FakeCloud extends LevelPublisher:
	var code := ""
	var replay := ""
	var calls: Array[Dictionary]=[]
	func api(path: String, method := HTTPClient.METHOD_GET, payload: Dictionary = {}) -> Dictionary:
		calls.append({"path":path,"method":method,"payload":payload.duplicate(true)})
		await get_tree().process_frame
		if path.begins_with("/levels?"):
			var entries := []
			var second := path.contains("cursor=next")
			for i in range(50 if not second else 1): entries.append({"id":"level%d"%i,"name":"Puzzle %d"%i,"author":"Fox","description":"Push the matching block onto the key.","likes":i,"plays":i+10,"revision":1})
			return {"levels":entries,"cursor":"next" if not second else ""}
		if path.begins_with("/level?"): return {"id":"level0","levelString":code,"revision":1,"likes":1}
		if path.begins_with("/replays?"): return {"replays":[{"id":"replay0","name":"Puzzle 0","author":"Anonymous","comment":"W".repeat(40),"time":1.25}],"cursor":""}
		if path.begins_with("/replay?"): return {"replayString":replay}
		if path=="/complete": return {"ok":true,"likes":2}
		return {"ok":true}

func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	print(("PASS: " if condition else "FAIL: ")+message)
	if not condition: failures+=1

func run() -> void:
	create_timer(60,true).timeout.connect(func(): quit(99))
	var session := root.get_node("LevelEditorSession")
	var progress := root.get_node("Progress")
	progress.save_root="res://.godot/community-test-progress"
	var fake := FakeCloud.new()
	fake.config_path="res://.godot/community-test-publishing.cfg"
	root.add_child(fake)
	session.service.queue_free()
	session.service=fake
	fake.remember_owned("level0")
	var data := {"v":1,"grid":[12,9,16],"color":"005155","tiles":[],"objects":[[1,24,104],[2,56,104,0,0.2,0.15],[3,88,104,0,"A"],[10,152,104]]}
	for x in 12: data.tiles.append([x,7])
	var old_code := LevelEditorCodec.encode(data)
	fake.code=CommunityCodec.level(old_code,"Puzzle 0","Fox","A description with æ and 😀")
	var decoded := LevelEditorCodec.decode(fake.code)
	check(decoded.metadata.d=="A description with æ and 😀" and LevelEditorCodec.encode(decoded)==fake.code,"CPE2 preserves Unicode metadata and still imports/exports losslessly")
	check(LevelEditorCodec.decode(old_code).objects.size()==4,"Old CPE1 codes still load")
	check(CommunityCodec.level(old_code,"Name","Author","x".repeat(101)).is_empty(),"Descriptions over 100 characters are rejected")
	var game: Node2D=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	for i in 12: await process_frame
	root.get_node("Dialogue").stop()
	session.warned=true
	session.open_menu()
	for i in 3: await process_frame
	var browser: CommunityBrowser=session.overlay.rows.get_child(0)
	check(browser.sort_buttons.size()==6 and browser.search.placeholder_text.contains("author"),"Browser shows all six sorts and a name/author search")
	check(browser.sort_buttons[0].get_theme_stylebox("normal").content_margin_left==8 and browser.next_button.get_theme_stylebox("hover").content_margin_top==8 and session.overlay.actions.get_child(0).get_theme_stylebox("normal").content_margin_bottom==8,"Sort, paging and Make Levels buttons retain 8px text padding")
	check(browser.rows.get_child_count()==50 and not browser.next_button.disabled,"Browser displays 50 levels and enables the next page")
	check(session.overlay.panel.get_global_rect().position.y>=0 and session.overlay.panel.get_global_rect().end.y<=root.get_visible_rect().size.y,"Level list and its headings fit inside the viewport")
	var header: Button=browser.rows.get_child(0).get_child(0).get_child(0)
	var fields: HBoxContainer=header.get_child(0)
	check(fields.offset_left==8 and fields.offset_top==8 and browser.rows.get_theme_constant("separation")==0 and fields.get_child_count()==4,"Level rows keep 8px text padding and show four fields")
	check(browser.headings.get_child(0).text=="Name" and browser.headings.get_child(1).text=="Author" and browser.headings.get_child(2).text=="Plays" and browser.headings.get_child(3).text=="Likes","Level list labels all four columns")
	check(fields.get_child(1).text=="Fox" and fields.get_child(2).text=="10" and fields.get_child(3).text=="0","Rows omit by/likes suffixes and display the play counter")
	check(browser.get_node("ListPadding").get_theme_constant("margin_top")==8 and browser.get_node("ListPadding").get_theme_constant("margin_bottom")==8,"Lists have 8px padding above and below")
	check(browser.page_label.get_parent().get_index()==0 and browser.previous_button.get_index()==1 and browser.page_label.get_parent().get_theme_constant("margin_left")==8 and browser.page_label.get_parent().get_theme_constant("margin_right")==8,"Page label precedes Previous with 8px horizontal margins")
	check(is_equal_approx(browser.headings.get_child(2).global_position.x,fields.get_child(2).global_position.x),"Level column headings align with their values")
	check(fields.get_child(0).get_theme_color("font_color")!=fields.get_child(1).get_theme_color("font_color") and fields.get_child(1).get_theme_color("font_color")!=fields.get_child(2).get_theme_color("font_color"),"Name, author and likes use distinct text colors")
	check(session.overlay.rows.get_child(1)==session.overlay.actions,"Scrollable catalogue appears above Make Levels")
	browser.rows.get_child(0).get_child(0).get_child(0).pressed.emit()
	var details: Control=browser.rows.get_child(0).get_child(0).get_node("Details")
	var buttons: HBoxContainer=details.get_node("Box/Contents/Actions")
	check(buttons.get_child_count()==4 and buttons.get_child(2).text=="Edit" and buttons.get_child(3).text=="Delete","Owned entries expand with Play, Replays, Edit, and Delete")
	check(buttons.get_child(0).get_theme_stylebox("normal").content_margin_left==8 and buttons.get_theme_constant("separation")==0,"Row action buttons have 8px padding and no gaps")
	await create_timer(0.08,true).timeout
	check(details.height>0 and details.height<details.get_child(0).get_combined_minimum_size().y,"Level details animate open while the game is paused")
	await create_timer(0.3,true).timeout
	check(is_equal_approx(details.height,details.get_child(0).get_combined_minimum_size().y) and details.get_child(0).get_theme_stylebox("panel").border_width_left==1,"Expanded details finish at their full height inside a bordered box")
	var row_style: StyleBox=browser.rows.get_child(0).get_theme_stylebox("panel")
	check(is_equal_approx(row_style.content_margin_top,8) and is_equal_approx(row_style.content_margin_bottom,8),"Expanded levels have 8px outer margins above and below")
	check(is_equal_approx(buttons.get_child(0).size.x+buttons.get_child(1).size.x+buttons.get_child(2).size.x+buttons.get_child(3).size.x,buttons.size.x) and is_equal_approx(session.overlay.actions.get_child(0).size.x,session.overlay.actions.size.x),"Action buttons and Make Levels fill their entire rows")
	var sorts: Control=browser.sort_buttons[0].get_parent()
	check(is_equal_approx(browser.sort_buttons[-1].position.x+browser.sort_buttons[-1].size.x,sorts.size.x),"Sorting buttons expand across the full row")
	check(browser.get_theme_constant("separation")==0 and session.overlay.rows.get_theme_constant("separation")==0,"Menu sections have no external gaps")
	header.pressed.emit()
	await create_timer(0.3,true).timeout
	check(details.height==0 and not details.visible,"Clicking an expanded row animates it closed")
	check(is_zero_approx(row_style.content_margin_top) and is_zero_approx(row_style.content_margin_bottom),"Collapsing restores flush row spacing")
	var second_contents: Control=browser.rows.get_child(1).get_child(0)
	var second_details: Control=second_contents.get_node("Details")
	second_details.get_node("Box/Contents").get_child(0).get_child(0).text="W".repeat(100)
	second_contents.get_child(0).pressed.emit()
	await create_timer(0.35,true).timeout
	check(second_details.height>=second_details.get_child(0).get_combined_minimum_size().y and second_details.height>details.get_child(0).get_combined_minimum_size().y,"Expanded boxes grow to fit wrapped descriptions")
	header.pressed.emit()
	header.pressed.emit()
	header.pressed.emit()
	await create_timer(0.3,true).timeout
	check(details.visible and details.opened and not second_details.visible and is_equal_approx(details.height,details.get_child(0).get_combined_minimum_size().y),"Rapid clicks settle on the latest expanded row without clipping")
	if "--capture" in OS.get_cmdline_user_args():
		for i in 4: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/community-browser.png")
	browser.next_button.pressed.emit()
	for i in 3: await process_frame
	check(browser.page==1 and browser.rows.get_child_count()==1 and browser.next_button.disabled,"Paging loads the remaining levels")
	browser.sort_buttons[2].pressed.emit()
	for i in 3: await process_frame
	check(browser.page==0 and fake.calls.back().path.contains("sort=today"),"Changing sort resets pagination and requests the selected ranking")
	browser.search.text="Fox"
	browser.search.text_changed.emit("Fox")
	await create_timer(0.3,true).timeout
	check(fake.calls.back().path.contains("search=Fox"),"Typing in search refreshes the filtered list")
	var entry := {"id":"level0","name":"Puzzle 0","levelString":fake.code,"revision":1}
	session.enter_community(entry)
	for i in 6: await process_frame
	var play := current_scene
	check(play!=game and play.ready_to_play and not game.is_inside_tree() and not progress.enabled,"Playing a cloud level suspends main-game progress")
	check(not play.ui.get_node("Toolbar").visible and not play.ui.get_node("PalettePanel").visible,"Community play hides editing tools")
	check(fake.calls.filter(func(call: Dictionary): return call.path=="/attempt").size()==1 and fake.calls.back().payload.runId==play.run_id,"Starting a community puzzle records one play attempt with a stable run ID")
	Input.action_press("right")
	for i in 240:
		await physics_frame
		if play.completed: break
	Input.action_release("right")
	for i in 4: await process_frame
	check(play.completed and paused and play.popup.rows.get_child(0).text=="Save Replay?","A real playthrough reaches the Save Replay completion prompt")
	check(play.replay_comment.max_length==40 and play.replay_author.placeholder_text=="Anonymous","Replay prompt limits comments to 40 characters and offers an anonymous author")
	check(fake.calls.back().path=="/complete" and not fake.calls.back().payload.has("replayString"),"Completion is recorded even before saving a replay")
	play.like_button.pressed.emit()
	for i in 3: await process_frame
	check(fake.calls.back().payload.vote==1,"Like submits a vote for this completion")
	play.replay_comment.text="Nice!"
	var recording: ReplayTrack=play.track
	fake.replay=recording.encode(fake.code,"","Nice!")
	var replay_data := ReplayTrack.decode(fake.replay)
	check(not replay_data.is_empty() and replay_data.a=="Anonymous" and replay_data.c=="Nice!","Replay code bakes in the comment and Anonymous fallback")
	check(replay_data.frames.any(func(frame: Array): return int(frame[0])&2!=0),"Replay records actual right-movement input frames")
	check(recording.encode(fake.code,"","W".repeat(41)).is_empty() and not recording.encode(fake.code,"","W".repeat(40)).is_empty(),"Replay encoding enforces the 40-character comment boundary")
	var fixtures := FileAccess.open("res://.godot/community-fixtures.json",FileAccess.WRITE)
	fixtures.store_string(JSON.stringify({"level":fake.code,"replay":fake.replay}))
	fixtures.close()
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/community-completion.png")
	play.save_replay()
	for i in 8: await process_frame
	check(current_scene==game and is_instance_valid(session.overlay) and paused,"Saving returns safely to the replay list over the resumed main game")
	check(fake.calls.any(func(call: Dictionary): return call.payload.has("replayString")),"Saving uploads the compressed input recording")
	var replay_browser: CommunityBrowser=session.overlay.rows.get_child(0)
	check(not replay_browser.replay_level.is_empty() and replay_browser.records[0].author=="Anonymous","Replay list shows the saved author, comment, and completion time")
	check(session.overlay.panel.get_global_rect().position.y>=0 and session.overlay.panel.get_global_rect().end.y<=root.get_visible_rect().size.y,"Replay list and its headings fit inside the viewport")
	check(replay_browser.rows.get_child(0).get_child(0).get_child_count()==1 and replay_browser.rows.get_child(0).get_child(0).get_child(0).get_child(0).get_child_count()==3,"Replay author, comment and time share one compact line without the redundant name")
	var replay_fields: HBoxContainer=replay_browser.rows.get_child(0).get_child(0).get_child(0).get_child(0)
	var comment_field: Label=replay_fields.get_child(1)
	var comment_width: float=comment_field.get_theme_font("font").get_string_size(comment_field.text,HORIZONTAL_ALIGNMENT_LEFT,-1,comment_field.get_theme_font_size("font_size")).x
	check(replay_browser.headings.get_child(1).text=="Comment" and replay_browser.headings.get_child(2).text=="Time" and comment_width<=comment_field.size.x,"Replay headings are present and even 40 wide characters fit without truncation")
	check(is_equal_approx(replay_browser.headings.get_child(1).global_position.x,comment_field.global_position.x),"Replay column headings align with their values")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/community-replays-menu.png")
	session.enter_community(entry,fake.replay)
	for i in 6: await process_frame
	var watch := current_scene
	watch.replay_paused=true
	check(watch.ready_to_play and watch.timeline.max_value==recording.frames.size()-1,"Replay mode opens with a timeline covering the full recording")
	watch.seek_replay(0)
	var actor: Node2D=watch.track.actors[0]
	var start_position := actor.position
	watch.timeline.value=watch.track.frames.size()-1
	var end_position := actor.position
	check(end_position!=start_position,"Dragging the timeline forward restores the completed puzzle state")
	watch.timeline.value=0
	check(actor.position==start_position,"Dragging backwards restores the starting state")
	watch.seek_replay(watch.track.frames.size()/2)
	var middle_position := actor.position
	var recorded_mask: int=watch.input_mask
	Input.action_press("left")
	for i in 10: await physics_frame
	Input.action_release("left")
	check(actor.position==middle_position and watch.input_mask==recorded_mask,"Live keyboard movement cannot change replay playback")
	var idle_recording: Dictionary=replay_data.duplicate(true)
	var idle_frames: Array=[replay_data.frames[0].duplicate(true)]
	for i in 660: idle_frames.append([0,[]])
	idle_frames.append_array(replay_data.frames.slice(1))
	var first_input_frame := 0
	while int(idle_frames[first_input_frame][0])&ReplayTrack.INPUT_BITS==0: first_input_frame+=1
	var trailing_idle := idle_frames.size()
	for i in 360: idle_frames.append([0,[]])
	idle_recording.frames=idle_frames
	watch.track.load_recording(idle_recording)
	watch.timeline.max_value=idle_frames.size()-1
	check(watch.track.next_frame(299)==300 and watch.track.next_frame(300)==first_input_frame,"Playback retains five seconds of an idle interval then skips to the next recorded input")
	check(watch.track.next_frame(first_input_frame)==first_input_frame+1,"Held input continues playing at normal speed")
	check(watch.track.next_frame(trailing_idle+300)==idle_frames.size()-1,"Trailing idle time is capped at five seconds too")
	watch.replay_paused=false
	watch.seek_replay(300)
	watch._physics_process(1.0/60)
	check(watch.replay_frame==first_input_frame and watch.input_mask&2!=0,"Replay playback actually resumes movement after skipping excess idle time")
	watch.replay_paused=true
	watch.seek_replay(450)
	check(watch.replay_frame==450 and actor.position==start_position,"The original idle frames remain available when scrubbing the timeline")
	watch.track.load_recording(replay_data)
	watch.timeline.max_value=recording.frames.size()-1
	watch.seek_replay(watch.track.frames.size()/2)
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/community-replay.png")
	watch.go_back()
	for i in 8: await process_frame
	check(current_scene==game and not session.overlay.rows.get_child(0).replay_level.is_empty(),"Replay Back returns to the same level's replay list")
	session.show_menu()
	for i in 3: await process_frame
	browser=session.overlay.rows.get_child(0)
	browser.confirm_edit(entry)
	var warning: Control=session.get_child(session.get_child_count()-1)
	check(warning.rows.get_child(0).text=="Warning!\n\nEditing your level will reset likes and remove all replays." and warning.actions.get_child(0).text=="Back" and warning.actions.get_child(1).text=="Continue","Editing an owned puzzle requires the requested warning")
	warning.actions.get_child(0).pressed.emit()
	check(current_scene==game and is_instance_valid(session.overlay),"Backing out of the warning leaves the puzzle unopened")
	browser.confirm_edit(entry)
	warning=session.get_child(session.get_child_count()-1)
	warning.actions.get_child(1).pressed.emit()
	for i in 5: await process_frame
	check(current_scene.cloud_level_id=="level0" and current_scene.data.metadata.n=="Puzzle 0","Edit loads the owned cloud level and embedded metadata")
	session.exit_editor()
	for i in 6: await process_frame
	check(current_scene==game and paused and is_instance_valid(session.overlay) and session.overlay.rows.get_child(0).replay_level.is_empty(),"Editor Exit returns to the game with level selection open")
	check(fake.calls.filter(func(call: Dictionary): return call.path=="/attempt").size()==1,"Replay viewing and cloud editing do not count as play attempts")
	session.close_menu()
	progress.enabled=false
	current_scene=null
	game.queue_free()
	for voice in root.get_node("Juice").voices:
		voice.stop()
		voice.stream=null
	await create_timer(0.1,true).timeout
	quit(failures)
