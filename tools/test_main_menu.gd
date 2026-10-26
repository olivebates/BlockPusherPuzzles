extends SceneTree
var failures := 0
var progress: Node
var slots: Node
var session: Node

func _initialize() -> void: call_deferred("run")
func _process(_delta: float) -> bool:
	var player := get_first_node_in_group("player")
	if player: player.set_physics_process(false)
	return false
func check(condition: bool, label: String) -> void:
	print(("PASS: " if condition else "FAIL: ")+label)
	if not condition: failures+=1
func settle(count := 12) -> void:
	for i in count: await process_frame
func freeze_player() -> CharacterBody2D:
	root.get_node("Dialogue").stop()
	var player := get_first_node_in_group("player") as CharacterBody2D
	player.set_physics_process(false)
	return player
func capture(name: String) -> void:
	if "--capture" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/"+name+".png")

func run() -> void:
	create_timer(90,true).timeout.connect(func(): quit(99))
	progress=root.get_node("Progress")
	slots=root.get_node("SaveSlots")
	session=root.get_node("LevelEditorSession")
	session.service.endpoint="http://127.0.0.1:1/levels"
	session.draft_path="res://.godot/menu-editor-test.cpe"
	var test_root := "res://.godot/menu-test-%d"%Time.get_ticks_msec()
	slots.root_path=test_root+"/slots"
	slots.legacy_root=test_root+"/legacy"
	progress.save_root=slots.legacy_root
	var game: Node2D=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	await settle()
	var player := freeze_player()
	player.position=Vector2(-100,-130)
	for pickup in get_nodes_in_group("collectibles").slice(0,2): pickup.set_collected(true)
	check(progress.save_now(),"Legacy game save can still be written after adding the main menu")
	progress.write_backup("timed",progress.snapshot())
	progress.enabled=false
	progress.level=null
	current_scene=null
	game.queue_free()
	await settle(2)
	var menu: Node2D=load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene=menu
	await settle(5)
	check(menu.page=="home" and menu.content.get_child(0).text=="PRISMBOUND","Game starts with the Prismbound title and home menu")
	check(menu.background.material is ShaderMaterial,"Home menu has a live shader background")
	check(menu.content.get_child(3).text=="Play Game" and menu.content.get_child(4).get_child_count()==2,"Home offers Play Game, Level Editor and Custom Levels")
	check(slots.names.size()==3 and slots.slot_info(0).name=="Original Save" and slots.slot_info(0).orbs==2,"Existing progress migrates to slot one with its collected-orb count")
	check(FileAccess.file_exists(slots.legacy_root+"/current.cps") and DirAccess.get_files_at(slots.slot_root(0)+"/backups").size()==DirAccess.get_files_at(slots.legacy_root+"/backups").size(),"Migration preserves the original save and copies its backups")
	await capture("prismbound-home")
	menu.show_slots()
	check(menu.content.get_child_count()==5 and menu.content.get_child(1).text.contains("Original Save") and menu.content.get_child(1).text.contains("2 orbs"),"Save selection shows exactly three slots with name and orb count")
	await capture("prismbound-slots")
	menu.choose_slot(0)
	await settle()
	game=current_scene
	player=freeze_player()
	check(progress.level==game and progress.save_root==slots.slot_root(0) and player.position==Vector2(-100,-130),"Selecting an existing slot restores its player and binds autosaving to that slot")
	var settings: Node=game.get_node("AudioSettings")
	settings.open_settings()
	await settle(3)
	check(settings.group_panels.size()==3 and settings.group_panels[0].get_theme_stylebox("panel").content_margin_top==8,"Settings group audio, controls and progress in three padded panels")
	check(settings.reset_button.text=="Reset to default" and settings.reset_button.size.x<settings.reset_button.get_parent().size.x,"Reset to default has a compact button instead of filling the row")
	check(settings.menu.get_theme_stylebox("panel").bg_color==game.hue_palette.map_color(game.background_color),"Settings theme follows the game's current palette")
	check(settings.menu.size.y<=root.get_visible_rect().size.y,"Settings fit within the game viewport")
	await capture("prismbound-settings")
	settings.menu.hide()
	var backup_point := Vector2(-120,-130)
	player.position=backup_point
	progress.write_backup("timed",progress.snapshot())
	var target_backup: String=progress.list_backups()[0].path
	player.position=Vector2(-180,-130)
	progress.save_now()
	settings.open_settings()
	var index := -1
	for i in range(1,settings.backup_picker.item_count):
		if settings.backup_picker.get_item_metadata(i)==target_backup: index=i
	settings.select_backup(index)
	check(settings.restore_confirmation.visible and player.position==Vector2(-180,-130),"Selecting a backup asks for confirmation before changing progress")
	settings.restore_confirmation.canceled.emit()
	settings.restore_confirmation.hide()
	check(player.position==Vector2(-180,-130),"Canceling backup restore keeps current progress")
	settings.select_backup(index)
	settings.restore_confirmation.confirmed.emit()
	settings.restore_confirmation.hide()
	check(player.position==backup_point,"Confirming the backup restores the selected state")
	check(slots.return_to_menu(),"Main Menu saves the active slot before leaving gameplay")
	await settle(5)
	menu=current_scene
	menu.show_slots()
	menu.choose_slot(1)
	check(is_instance_valid(menu.popup) and menu.slot_name.max_length==32,"An empty slot opens a name field")
	menu.create_save()
	check(not menu.slot_error.text.is_empty(),"Empty save names are rejected")
	menu.slot_name.text="Second Light"
	menu.create_save()
	await settle()
	player=freeze_player()
	check(slots.selected==1 and progress.save_root==slots.slot_root(1) and progress.snapshot().collected.is_empty(),"Creating slot two starts a fresh game independently of slot one")
	player.position=Vector2(-200,-130)
	check(progress.save_now() and slots.slot_info(0).orbs==2 and slots.slot_info(1).orbs==0,"Saving one slot preserves the other slot's progress and orb count")
	check(not slots.create_slot(3,"Fourth"),"Only three save slots can be created")
	slots.initialized_root=""
	slots.initialize()
	check(slots.names[1]=="Second Light","Slot names survive reloading the saved configuration")
	slots.return_to_menu()
	await settle(5)
	menu=current_scene
	menu.choose_slot(0)
	await settle()
	player=freeze_player()
	check(player.position==backup_point and progress.snapshot().collected.size()==2,"Returning to slot one restores its own saved state")
	slots.return_to_menu()
	await settle(5)
	menu=current_scene
	session.open_menu("editor",true)
	check(paused and session.overlay.rows.get_child(0).text==session.WARNING,"Main-menu Level Editor shows the spoiler warning")
	session.close_menu()
	session.open_menu("editor",true)
	session.accept_warning()
	await settle(8)
	check(current_scene.scene_file_path=="res://scenes/level_editor.tscn" and session.suspended_game==menu and not progress.enabled,"Editor can open directly from the main menu without a gameplay save")
	session.exit_editor()
	await settle(8)
	check(current_scene==menu and is_instance_valid(session.overlay) and paused,"Editor Exit restores the main menu with custom-level selection open")
	var style: StyleBoxFlat=session.overlay.actions.get_child(0).get_theme_stylebox("normal")
	check(style.bg_color==Color("8564ad"),"Make Levels uses a lilac base color")
	session.close_menu()
	session.open_menu("browser",true)
	check(session.overlay.rows.get_child(0).text==session.WARNING,"Main-menu Custom Levels also shows the spoiler warning")
	session.accept_warning()
	await settle(3)
	check(session.overlay.rows.get_child(0) is CommunityBrowser and current_scene==menu,"Custom Levels opens browsing without starting a save slot")
	session.close_menu()
	progress.enabled=false
	current_scene=null
	menu.queue_free()
	for voice in root.get_node("Juice").voices:
		voice.stop()
		voice.stream=null
	await settle(2)
	quit(failures)
