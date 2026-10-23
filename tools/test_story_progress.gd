extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ")+message)
	if not value: failures+=1
func frames(count: int) -> void:
	for i in count: await physics_frame
func finish_dialogue() -> void:
	while root.get_node("Dialogue").active: root.get_node("Dialogue").next_line()
func instance(kind: int, parent: Node, position: Vector2) -> Node2D:
	var node: Node2D=load(LevelData.SCENES[kind]).instantiate()
	node.position=position
	parent.add_child(node)
	return node
func run() -> void:
	create_timer(45,true).timeout.connect(func(): quit(99))
	var progress := root.get_node("Progress")
	var dialogue := root.get_node("Dialogue")
	progress.save_root="user://tests/story_progress"
	progress.delete_progress(false)
	var game: Node2D=load("res://tools/test_world.gd").new().level()
	root.add_child(game)
	current_scene=game
	await frames(8)
	var objects := game.get_node("Objects")
	var player: CharacterBody2D=get_first_node_in_group("player")
	player.set_physics_process(false)
	var door := instance(12,objects,Vector2(800,312))
	var indicators: Array[Node2D]=[]
	for i in 3: indicators.append(instance(14,objects,Vector2(768+i*16,300)))
	var outside := instance(14,objects,Vector2(1136,300))
	var pickups: Array[Node2D]=[]
	for i in 3: pickups.append(instance(13,objects,Vector2(680+i*24,264)))
	var npc := instance(15,objects,Vector2(744,313))
	await progress.bind_level(game)
	check(dialogue.active and dialogue.lines==StoryLines.OPENING and dialogue.speaker.text=="Pip","First launch shows Pip's exact four-line opening")
	check(paused and progress.dialogues.has("opening"),"Dialogue freezes play and records that the opening has triggered")
	dialogue._process(0)
	var dialogue_style: StyleBoxFlat=dialogue.panel.get_theme_stylebox("panel")
	check(dialogue_style.bg_color==game.background_color and dialogue_style.border_color==game.tile_color,"Dialogue uses the current game background and tile colors")
	var continue_prompt := false
	for label in dialogue.panel.find_children("*","Label",true,false):
		if label.text=="Space to continue" and label.horizontal_alignment==HORIZONTAL_ALIGNMENT_CENTER: continue_prompt=true
	check(continue_prompt and dialogue.panel.find_children("*","Button",true,false).is_empty(),"Dialogue has a centered Space to continue label instead of an arrow button")
	var enter := InputEventKey.new()
	enter.keycode=KEY_ENTER
	enter.physical_keycode=KEY_ENTER
	enter.pressed=true
	Input.parse_input_event(enter)
	Input.flush_buffered_events()
	check(dialogue.line_index==0,"Enter does not advance dialogue")
	enter.pressed=false
	Input.parse_input_event(enter)
	var before_velocity := player.velocity
	player.buffered=0.12
	player._physics_process(1.0/60)
	check(player.velocity==before_velocity and player.buffered==0,"Jump buffering and movement are disabled during dialogue")
	var space := InputEventKey.new()
	space.keycode=KEY_SPACE
	space.physical_keycode=KEY_SPACE
	space.pressed=true
	Input.parse_input_event(space)
	Input.flush_buffered_events()
	check(dialogue.line_index==0 and not dialogue.revealing(),"First Space finishes the text reveal without skipping the line")
	space.pressed=false
	Input.parse_input_event(space)
	space.pressed=true
	Input.parse_input_event(space)
	Input.flush_buffered_events()
	check(dialogue.line_index==1,"Second Space advances the dialogue by one line")
	space.pressed=false
	Input.parse_input_event(space)
	progress.save_now()
	var mid: Dictionary=progress.read_file(progress.save_root+"/current.cps")
	check(mid.dialogue.index==1 and mid.dialogue.lines[1][1]=="Now how do I take this thing off?","Autosaves retain the current dialogue line")
	finish_dialogue()
	check(not paused,"Finishing a conversation restores gameplay")
	check(door.get_node("CollisionShape2D").shape.size==Vector2(32,64),"Large door occupies exactly two by four tiles")
	check(door.nearby_indicators().size()==3 and not door.opened,"Door requires every indicator within twenty tiles")
	for i in 3:
		pickups[i].collect()
		await frames(3)
		var lit := 0
		for indicator in indicators:
			if indicator.lit: lit+=1
		check(lit==i+1 and door.opened==(i==2),"Pickup %d lights exactly one indicator and opens only the complete door" % (i+1))
	check(not outside.lit and door.get_node("CollisionShape2D").disabled,"An unlit indicator outside the radius does not block the open door")
	check(not pickups[0].collect(),"Collected pickups cannot light a second indicator")
	var block: CharacterBody2D=objects.get_node("Block_0")
	var sphere: CharacterBody2D=objects.get_node("WhiteSphere")
	var weld: CharacterBody2D=objects.get_node("WeldedLilac0")
	block.position=Vector2(152,312)
	block.resting_x=152
	sphere.position=Vector2(432,240)
	weld.members[1].weld_offset=Vector2(0,-16)
	weld.rebuild_weld_shapes()
	weld.sync_members()
	player.position=Vector2(680,280)
	check(progress.save_now(),"Progress is written atomically to the user data filesystem")
	var saved: Dictionary=progress.read_file(progress.save_root+"/current.cps")
	var encoded: PackedByteArray=ProgressCodec.encode(saved)
	check(encoded.size()<JSON.stringify(saved).to_utf8_buffer().size(),"Progress uses the smallest supported lossless compressed representation")
	var corrupt := encoded.duplicate()
	corrupt[-1]^=1
	check(ProgressCodec.decode(corrupt).is_empty(),"A checksum rejects corrupted compressed progress")
	block.position=Vector2(120,312)
	sphere.position=Vector2(216,280)
	player.position=Vector2(56,313)
	weld.members[1].weld_offset=Vector2(16,0)
	for indicator in indicators: indicator.lit=false
	for pickup in pickups: pickup.set_collected(false)
	check(progress.apply_state(saved),"A saved snapshot can be restored")
	check(block.position==Vector2(152,312) and sphere.position==Vector2(432,240) and player.position==Vector2(680,280),"Restore recovers player, box, and circle coordinates")
	check(weld.members[1].weld_offset==Vector2(0,-16),"Restore recovers rotated welded geometry")
	check(indicators.all(func(p): return p.lit) and pickups.all(func(p): return p.collected),"Restore recovers indicators and collected pickups")
	player.position=Vector2(690,313)
	for i in 3: await process_frame
	check(dialogue.active and dialogue.lines==StoryLines.ENCOUNTER and dialogue.lines.size()==14,"Approaching Sunny within four tiles starts the exact fourteen-line encounter")
	check(npc.get_node("Visual").texture.resource_path=="res://assets/playerSprite.png" and npc.get_node("Visual").material.shader.resource_path.ends_with("npc_fox.gdshader"),"Sunny uses the player sprite with a brighter yellow hue shader")
	finish_dialogue()
	player.position=Vector2(734,313)
	for i in 3: await process_frame
	check(npc.nearby and not dialogue.active,"A nearby introduced NPC shows its interaction prompt without repeating the introduction")
	Input.action_press("interact")
	for i in 2: await process_frame
	Input.action_release("interact")
	check(dialogue.active and dialogue.lines==StoryLines.REMINDER,"E starts Sunny's reminder dialogue")
	finish_dialogue()
	var trigger := instance(16,objects,Vector2(1000,200))
	player.position=Vector2(936,200)
	for i in 3: await process_frame
	check(dialogue.active and dialogue.words.get_parsed_text()=="Whoa, this one looks tough!","Challenge triggers start the requested line within four tiles")
	finish_dialogue()
	for i in 3: await process_frame
	check(not dialogue.active,"The challenge dialogue only triggers once")
	player.position=Vector2(900,200)
	progress._process(5.1)
	check(progress.read_file(progress.save_root+"/current.cps").player==[900.0,200.0],"The five-second autosave stores the latest player position")
	for i in 24: progress.write_backup("timed",progress.snapshot())
	for i in 7: progress.write_backup("launch",progress.snapshot())
	var backups: Array=progress.list_backups()
	check(backups.filter(func(b): return b.kind=="timed").size()==20 and backups.filter(func(b): return b.kind=="launch").size()==5,"Backup retention keeps twenty timed saves and five launch saves")
	var sequence: int=progress.sequence
	progress._process(600)
	check(progress.sequence==sequence+1,"Ten minutes creates a new periodic backup")
	var settings := game.get_node("AudioSettings")
	settings.refresh_backups()
	check(settings.backup_picker.item_count==26,"Settings list all twenty-five latest backups")
	player.position=Vector2(56,313)
	check(progress.restore_backup(progress.list_backups()[0].path) and player.position==Vector2(900,200),"Selecting a valid backup restores its progress")
	var level_copy := LevelData.decode(LevelData.encode(LevelData.capture(game)))
	var kinds: Array=[]
	for item in level_copy.objects: kinds.append(int(item[0]))
	check([12,13,14,15,16].all(func(kind): return kinds.has(kind)),"All five new object types survive compressed level save/load")
	settings.menu.popup_centered()
	settings.delete_button.pressed.emit()
	settings.delete_confirmation.confirmed.emit()
	for i in 2: await process_frame
	check(settings.delete_stage==2 and FileAccess.file_exists(progress.save_root+"/current.cps"),"The first deletion confirmation does not delete progress")
	settings.delete_confirmation.confirmed.emit()
	for i in 2: await process_frame
	check(settings.delete_stage==3 and FileAccess.file_exists(progress.save_root+"/current.cps"),"The second deletion confirmation still preserves progress")
	progress.enabled=false
	settings.delete_confirmation.confirmed.emit()
	for i in 6: await process_frame
	check(not FileAccess.file_exists(progress.save_root+"/current.cps") and progress.list_backups().is_empty(),"Only the third confirmation deletes progress and every backup")
	check(current_scene.scene_file_path=="res://scenes/main.tscn","Deleting progress restarts the game")
	var remaining := current_scene
	current_scene=null
	remaining.queue_free()
	await process_frame
	print("STORY AND PROGRESS: ","PASS" if failures==0 else "FAIL")
	quit(failures)
