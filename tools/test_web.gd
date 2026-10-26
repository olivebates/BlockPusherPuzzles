extends Node
## Autoload in a temporary export-test project. Never shipped in-game.
var checks := {}
var phase := "write"
var progress: Node
var slots: Node

var root: Window:
	get: return get_tree().root
var current_scene: Node:
	get: return get_tree().current_scene
	set(value): get_tree().current_scene=value
var paused: bool:
	get: return get_tree().paused

func _ready() -> void: call_deferred("run")
func get_first_node_in_group(group: String) -> Node: return get_tree().get_first_node_in_group(group)
func get_nodes_in_group(group: String) -> Array[Node]: return get_tree().get_nodes_in_group(group)
func _process(_delta: float) -> void:
	var player := get_first_node_in_group("player")
	if player: player.set_physics_process(false)
func verify(condition: bool, name: String) -> void:
	checks[name]=condition
	print(("WEB PASS: " if condition else "WEB FAIL: ")+name)
func settle(count := 16) -> void:
	for i in count: await get_tree().process_frame
func freeze_player() -> CharacterBody2D:
	root.get_node("Dialogue").stop()
	var player := get_first_node_in_group("player") as CharacterBody2D
	player.set_physics_process(false)
	return player
func report() -> void:
	var failures := 0
	for key in checks:
		if not checks[key]: failures+=1
	var result := {"phase":phase,"checks":checks,"failures":failures}
	JavaScriptBridge.eval("window.__webSmokeResult="+JSON.stringify(result),true)
	print("WEB RESULT: "+JSON.stringify(result))

func run() -> void:
	print("WEB SMOKE DRIVER STARTED")
	await settle(2)
	if is_instance_valid(current_scene):
		var previous := current_scene
		root.remove_child(previous)
		previous.queue_free()
		current_scene=null
	progress=root.get_node("Progress")
	slots=root.get_node("SaveSlots")
	slots.root_path="user://tests/prismbound_web_slots"
	slots.legacy_root="user://tests/no_legacy_save"
	phase="read" if str(JavaScriptBridge.get_interface("location").search).contains("read") else "write"
	var menu: Node2D=load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene=menu
	await settle(5)
	verify(OS.has_feature("web") and OS.is_userfs_persistent(),"HTML5 persistent filesystem initializes")
	verify(menu.content.get_child(0).text=="PRISMBOUND","Title screen renders in the web release")
	var service := LevelPublisher.new()
	service.config_path="user://tests/prismbound_web_publish.cfg"
	var origin: String=JavaScriptBridge.get_interface("location").origin
	service.endpoint=origin+"/mock/levels"
	root.add_child(service)
	if phase=="read":
		verify(slots.slot_info(0).name=="Browser Save" and slots.slot_info(0).orbs==2,"Save name and orb count survive browser reload")
		verify(slots.slot_info(1).name=="Second Browser Save" and slots.slot_info(1).orbs==0,"Second slot survives reload independently")
		verify(not slots.slot_info(2).occupied,"Confirmed slot deletion survives browser reload")
		verify(not DirAccess.get_files_at(slots.slot_root(2)+"/backups").is_empty(),"Freed-slot backups survive browser reload")
		verify(service.owned_ids.has("web-level") and str(JavaScriptBridge.eval("document.cookie",true)).contains("cp_level_web-level"),"Uploaded-level ownership cookie survives reload")
		verify(service.last_author=="Browser Author","Publishing identity and author survive reload")
		verify(is_equal_approx(Juice.volumes.SFX,0.37) and InputMap.action_get_events("jump")[-1].physical_keycode==KEY_J,"Audio volume and custom key bindings survive browser reload")
		menu.choose_slot(0)
		await settle()
		var player := freeze_player()
		verify(player.position==Vector2(-100,-130) and progress.snapshot().collected.size()==2,"Reloaded slot restores player position and collected orbs")
		slots.return_to_menu()
		await settle(5)
		current_scene.choose_slot(1)
		await settle()
		player=freeze_player()
		verify(player.position==Vector2(-200,-130) and progress.snapshot().collected.is_empty(),"Reloaded second slot restores its own progress")
		slots.return_to_menu()
		await settle(5)
		var session := root.get_node("LevelEditorSession")
		session.service.endpoint=service.endpoint
		current_scene.content.get_child(4).get_child(1).pressed.emit()
		await settle(3)
		verify(session.warned and session.overlay.rows.get_child(0) is CommunityBrowser,"Custom Levels skips the accepted spoiler warning after browser reload")
		session.close_menu()
		verify(slots.create_slot(2,"Reused Browser Save"),"A freed browser slot can be reused")
		current_scene.choose_slot(2)
		await settle()
		player=get_first_node_in_group("player")
		verify(root.get_node("Dialogue").active and player.position!=Vector2(-300,-130) and progress.snapshot().collected.is_empty(),"Reused browser slot starts fresh with old backups retained")
		root.get_node("Dialogue").stop()
		var retained: Array=progress.list_backups().filter(func(backup: Dictionary): return backup.kind=="timed")
		verify(not retained.is_empty() and progress.restore_backup(retained[0].path) and player.position==Vector2(-300,-130),"The old browser backup can still be restored manually")
		slots.return_to_menu()
		await settle(5)
		report()
		return
	verify(slots.create_slot(0,"Browser Save"),"Named save slot can be created on HTML5")
	menu.choose_slot(0)
	await settle()
	var dialogue := root.get_node("Dialogue")
	var links: Node=current_scene.get_node("SupportLinks")
	verify(dialogue.active and not links.bar.visible,"HTML5 hides the bottom buttons during the opening dialogue")
	while dialogue.active: dialogue.next_line()
	await get_tree().create_timer(0.55,true).timeout
	verify(links.bar.visible and is_equal_approx(links.bar.offset_top,-16),"HTML5 reveals the bottom buttons after the opening finishes")
	var player := freeze_player()
	player.position=Vector2(-100,-130)
	for pickup in get_nodes_in_group("collectibles").slice(0,2): pickup.set_collected(true)
	verify(progress.save_now(),"Browser writes a campaign save")
	var settings: Node=current_scene.get_node("AudioSettings")
	var game_menu := root.get_node("GameMenu")
	game_menu.open_menu()
	verify(paused and game_menu.overlay.rows.get_child(1).get_child_count()==7,"HTML5 opens the new game menu")
	game_menu.open_settings()
	await settle(3)
	verify(settings.menu.visible and settings.group_panels.size()==3,"Grouped settings open as an embedded web dialog")
	settings.main_menu_button.pressed.emit()
	await settle(3)
	verify(paused and is_instance_valid(game_menu.overlay) and settings.main_menu_button.text=="Back","HTML5 Settings Back returns to the game menu")
	game_menu.continue_game()
	Juice.set_volume("SFX",0.37)
	InputBindings.set_slot("jump",2,InputBindings.key_event(KEY_J))
	slots.return_to_menu()
	await settle(5)
	verify(slots.create_slot(1,"Second Browser Save"),"Second named slot can be created")
	current_scene.choose_slot(1)
	await settle()
	player=freeze_player()
	player.position=Vector2(-200,-130)
	verify(progress.save_now(),"Browser writes a second independent save")
	slots.return_to_menu()
	await settle(5)
	verify(slots.create_slot(2,"Temporary Browser Save"),"Third browser slot can be created for deletion")
	current_scene.choose_slot(2)
	await settle()
	player=freeze_player()
	player.position=Vector2(-300,-130)
	progress.save_now()
	progress.write_backup("timed",progress.snapshot())
	slots.return_to_menu()
	await settle(5)
	current_scene.show_slots()
	current_scene.confirm_delete_slot(2)
	current_scene.popup.actions.get_child(1).pressed.emit()
	verify(not slots.slot_info(2).occupied and not FileAccess.file_exists(slots.slot_root(2)+"/current.cps"),"HTML5 confirmed trash action deletes the selected save")
	verify(not DirAccess.get_files_at(slots.slot_root(2)+"/backups").is_empty(),"HTML5 trash action preserves the slot backups")
	var session := root.get_node("LevelEditorSession")
	session.service.endpoint=service.endpoint
	session.draft_path="user://tests/prismbound_web_draft.cpe"
	session.open_menu("editor",true)
	verify(paused and session.overlay.rows.get_child(0).text==session.WARNING,"Web editor entry shows the spoiler warning")
	session.accept_warning()
	await settle(8)
	verify(current_scene.scene_file_path=="res://scenes/level_editor.tscn" and not progress.enabled,"Web editor opens from the title screen without overwriting a slot")
	session.exit_editor()
	await settle(8)
	verify(current_scene.is_in_group("main_menu") and not is_instance_valid(session.overlay) and not paused,"Web editor Exit returns directly to its title-screen origin")
	session.close_menu()
	var board := {"v":1,"grid":[12,9,16],"color":"005155","tiles":[],"objects":[[1,24,104],[2,56,104,0,0.2,0.15],[3,88,104,0,"A"]]}
	for x in 12: board.tiles.append([x,7])
	var raw := LevelEditorCodec.encode(board)
	var uploaded := await service.publish("Web Puzzle","Browser Author",raw,"1".repeat(32),"Browser upload")
	verify(uploaded.get("ok",false),"HTML5 sends the compressed level upload")
	var downloaded := await service.get_level("web-level")
	var code: String=downloaded.get("levelString","")
	var decoded := LevelEditorCodec.decode(code)
	verify(not decoded.is_empty() and decoded.metadata.n=="Web Puzzle","HTML5 downloads and decodes the published level")
	var track := ReplayTrack.new()
	track.kinds=[1,2,3]
	track.frames=[[0,[[0,2400,10400,0,1,0,100,100,0,0,0,0],[1,5600,10400,0,0,0,0,0,0,0,0],[2,8800,10400,0,0,0]]],[2,[[0,2500,10400,0,1,0,100,100,0,0,0,0]]]]
	var replay := track.encode(code,"Web Replay Author","W".repeat(40))
	var saved := await service.complete("web-level",1,"2".repeat(32),1,replay)
	verify(saved.get("ok",false),"HTML5 uploads the compressed replay with a 40-character comment")
	var listing := await service.list_replays("web-level","")
	verify(listing.get("replays",[]).size()==1 and listing.replays[0].comment.length()==40,"HTML5 downloads replay metadata")
	var fetched := await service.get_replay("web-replay")
	verify(not ReplayTrack.decode(fetched.get("replayString","")).is_empty(),"HTML5 downloads and decodes replay inputs")
	var browser_publisher := LevelPublisher.new()
	browser_publisher.config_path=service.config_path
	root.add_child(browser_publisher)
	verify(browser_publisher.owned_ids.has("web-level"),"Publishing sets the browser ownership cookie")
	var live := LevelPublisher.new()
	live.config_path="user://tests/prismbound_web_live.cfg"
	root.add_child(live)
	var live_levels := await live.list_levels("hot","","")
	verify(not live_levels.has("error") and live_levels.get("status")==200,"Live Convex cloud listing works with browser CORS")
	if not live_levels.get("levels",[]).is_empty():
		var id: String=live_levels.levels[0].id
		var live_level := await live.get_level(id)
		verify(not LevelEditorCodec.decode(live_level.get("levelString","")).is_empty(),"Browser downloads an actual cloud puzzle")
		var live_replays := await live.list_replays(id,"")
		verify(not live_replays.has("error"),"Live Convex replay listing works in the browser")
	JavaScriptBridge.force_fs_sync()
	await get_tree().create_timer(2,true).timeout
	report()
