extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ")+message)
	if not value: failures+=1
func frames(count: int) -> void:
	for i in count: await physics_frame
func space() -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode=KEY_SPACE
		event.physical_keycode=KEY_SPACE
		event.pressed=pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
func run() -> void:
	create_timer(20,true).timeout.connect(func(): quit(99))
	var game: Node2D=load("res://tools/test_world.gd").new().level()
	root.add_child(game)
	current_scene=game
	await frames(5)
	var dialogue := root.get_node("Dialogue")
	var juice := root.get_node("Juice")
	var player: CharacterBody2D=get_first_node_in_group("player")
	var chatter: Array[String]=[]
	juice.sound_played.connect(func(kind: String):
		if kind.begins_with("fox_chatter"): chatter.append(kind))
	dialogue.begin("",[[StoryLines.PLAYER,"Hey, wait!"],[StoryLines.NPC,"Seriously?"]])
	check(paused and dialogue.revealed==0 and dialogue.advance.modulate.a==0,"Dialogue pauses play, starts hidden text, and hides its continue prompt")
	dialogue._process(0.12)
	check(dialogue.revealed==4 and dialogue.reveal_wait>0.1,"Text reveals at 35 characters per second and pauses at a comma")
	var before: int=dialogue.revealed
	dialogue._process(0.08)
	check(dialogue.revealed==before,"Punctuation creates a readable pause")
	check(chatter==["fox_chatter_pip"] and dialogue.chatter.bus=="SFX","Soft Pip chatter sounds every few letters through the saved SFX volume bus")
	check(dialogue.panel.modulate.a>0.99 and absf(dialogue.panel.offset_bottom+24)<0.01,"Bubble fade and upward slide settle after 0.15 seconds")
	check(dialogue.current_speaker()==player,"The speech marker follows the speaking player")
	space()
	check(dialogue.line_index==0 and not dialogue.revealing() and dialogue.advance.modulate.a==1,"Space finishes the current line before showing Space to continue")
	check(chatter.size()==1,"Skipping the reveal does not burst chatter sounds")
	space()
	check(dialogue.line_index==1 and dialogue.revealed==0,"A second Space moves to the next line")
	dialogue._process(0.1)
	check(chatter.back()=="fox_chatter_sunny" and dialogue.portrait.material!=null,"Sunny uses a distinct voice and retains the existing yellow portrait")
	check(dialogue.words.get_parsed_text()=="Seriously?" and dialogue.words.text.contains("[color=#ffd433]"),"Selected words are highlighted without changing dialogue text")
	var snapshot: Dictionary=dialogue.snapshot()
	dialogue.stop()
	dialogue.restore(snapshot)
	check(dialogue.revealed==int(snapshot.revealed) and dialogue.words.visible_characters==int(snapshot.revealed),"Saving and restoring a conversation preserves partial text reveal")
	dialogue.begin("",[[StoryLines.PLAYER,"...   "]])
	var sounds_before := chatter.size()
	dialogue._process(1.5)
	check(chatter.size()==sounds_before,"Spaces and punctuation remain silent")
	dialogue.stop()
	check(not paused and player.buffered==0 and player.recall_freeze_frames>=2,"Closing dialogue restores play without triggering a jump")
	for character in ["pip","sunny"]:
		var clips: Array=dialogue.chatter_streams[character]
		check(clips.size()==3 and clips[0].data!=clips[1].data,"Generated %s chatter has three distinct audio variations" % character)
		for clip in clips:
			check(clip.loop_mode==AudioStreamWAV.LOOP_DISABLED and clip.get_length()>0.05 and clip.get_length()<0.12,"Chatter is a short non-looping clip")
	current_scene=null
	game.queue_free()
	await process_frame
	quit(failures)
