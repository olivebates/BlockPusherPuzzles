extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	print(("PASS: " if condition else "FAIL: ")+message)
	if not condition: failures += 1
func frames(count: int) -> void:
	for i in count: await physics_frame
func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func run() -> void:
	create_timer(20,true).timeout.connect(func(): quit(99))
	var level: Node2D = load("res://scenes/level_editor.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(8)
	var editor := level.get_node("LevelEditor")
	check(editor.get_script()!=null,"Editor script loads successfully")
	check(editor.active and editor.building and paused,"Independent editor opens in paused build mode")
	check(editor.data.objects.is_empty() and editor.data.tiles.is_empty(),"New editor board is clear")
	check(editor.data.grid[0]==int(editor.board_area().size.x/16),"Default grid width fits editor area")
	check(editor.data.grid[1]==int(editor.board_area().size.y/16),"Default grid height fits editor area")
	check(editor.save_to("res://.godot/empty-editor.cpplevel"),"Blank layouts can be saved before placing a player")
	check(not editor.start_play() and editor.building,"Playtest requires a player without losing layout")
	editor.select_item(2)
	editor.selected_color = 2
	editor.paint(Vector2(400,220))
	check(editor.data.objects.back()==[2,408.0,216.0,2,0.2,0.15],"Palette places colored block with default timing")
	editor.last_cell = Vector2i(-999999,-999999)
	editor.paint(Vector2(400,220),true)
	check(editor.data.objects.is_empty(),"Grid eraser removes placed objects")
	editor.select_item(0)
	editor.last_cell = Vector2i(-999999,-999999)
	editor.paint(Vector2(400,220))
	check(editor.data.tiles.has([25,13]),"Wall paint uses native 16px tile grid")
	editor.data.grid=[80,45,8]
	editor.select_item(5)
	editor.selected_symbol=3
	editor.last_cell=Vector2i(-999999,-999999)
	editor.paint(Vector2(412,220))
	check(editor.data.objects.back()==[5,412.0,220.0,3],"Custom snap preserves portal symbol placement")
	editor.select_item(8)
	editor.last_cell=Vector2i(-999999,-999999)
	editor.paint(Vector2(444,220))
	check(editor.data.objects.back()==[8,444.0,220.0],"Palette places the new one-way block")
	editor.select_item(9)
	editor.trigger_hex="#ffaa55"
	editor.trigger_color=Color.GREEN
	editor.trigger_background=Color("283347")
	editor.trigger_tiles=Color("172c20")
	editor.last_cell=Vector2i(-999999,-999999)
	editor.paint(Vector2(452,220))
	var theme_entry: Array=LevelData.decode(LevelData.encode(editor.data)).objects.back()
	check(theme_entry==[9,452.0,220.0,"#ffaa55",Color.GREEN.to_html(),editor.trigger_background.to_html(),editor.trigger_tiles.to_html()],"Editor theme trigger keeps tint and both base colors through save/load")
	for kind in [10,11]:
		editor.select_item(kind)
		editor.last_cell=Vector2i(-999999,-999999)
		editor.paint(Vector2(460+(kind-10)*16,204))
		check(int(LevelData.decode(LevelData.encode(editor.data)).objects.back()[0])==kind,"Editor places and saves rotator direction %d" % kind)
	for kind in range(12,18):
		editor.select_item(kind)
		editor.last_cell=Vector2i(-999999,-999999)
		editor.paint(Vector2(492+(kind-12)*16,204))
		check(int(LevelData.decode(LevelData.encode(editor.data)).objects.back()[0])==kind,"Editor places and saves story object %d" % kind)
	editor.select_item(3)
	editor.selected_color=1
	editor.link_id="TEST"
	editor.last_cell=Vector2i(-999999,-999999)
	editor.paint(Vector2(420,220))
	check(editor.data.objects.back()==[3,420.0,220.0,1,"TEST"],"Key tile placement stores color and ID")
	editor.select_item(4)
	editor.required=5
	editor.last_cell=Vector2i(-999999,-999999)
	editor.paint(Vector2(428,220))
	check(editor.data.objects.back()==[4,428.0,220.0,5,"TEST"],"Door placement stores multiple required colors")
	editor.select_item(1)
	editor.last_cell=Vector2i(-999999,-999999)
	editor.paint(Vector2(40,40))
	editor.last_cell=Vector2i(-999999,-999999)
	editor.paint(Vector2(48,40))
	var players:=0
	for item in editor.data.objects:
		if item[0]==1: players+=1
	check(players==1,"Placing a second player moves the existing spawn")
	var raw:=JSON.stringify(editor.data).to_utf8_buffer()
	var encoded:=LevelData.encode(editor.data)
	var decoded:=LevelData.decode(encoded)
	check(JSON.stringify(decoded)==JSON.stringify(editor.data),"Compressed level round-trip is lossless")
	check(encoded.size()<raw.size(),"Compressed save is smaller than compact JSON")
	check(LevelData.decode(encoded.slice(0,8)).is_empty(),"Truncated save is rejected")
	var invalid:=encoded.duplicate()
	invalid[0]=0
	check(LevelData.decode(invalid).is_empty(),"Invalid file header is rejected")
	check(editor.save_to("res://.godot/editor-test.cpplevel"),"Save writes compressed level file")
	editor.data.grid=[10,10,16]
	check(editor.load_from("res://.godot/editor-test.cpplevel") and editor.data.grid==[80,45,8],"Load restores custom grid settings")
	editor.data=load("res://tools/test_fixture.gd").new().board()
	var authored:=JSON.stringify(editor.data)
	key(KEY_SPACE,true)
	await process_frame
	key(KEY_SPACE,false)
	check(not paused and not editor.building,"Space switches build to live play")
	await frames(6)
	check(level.get_node("Camera").level_bounds==Vector2(1280,720),"Custom board controls camera bounds")
	var icons_hidden:=true
	for object in level.get_node("Objects").get_children():
		if object.has_node("EditorIcon") and object.get_node("EditorIcon").visible: icons_hidden=false
	check(icons_hidden,"Identification sprites remain hidden in gameplay")
	get_first_node_in_group("blocks").position.x+=24
	editor.enter_build()
	check(JSON.stringify(editor.data)==authored,"Returning to build preserves authored layout after movement")
	check(editor.start_play(),"Build to play can repeat")
	await frames(5)
	check(get_first_node_in_group("player").velocity.y>=0,"Space mode switch does not also jump the player")
	key(KEY_SHIFT,true)
	key(KEY_Z,true)
	key(KEY_P,true)
	await frames(5)
	key(KEY_P,false)
	key(KEY_Z,false)
	key(KEY_SHIFT,false)
	check(current_scene.scene_file_path=="res://scenes/main.tscn" and not paused,"Shift+Z+P exits independent editor back to game")
	await frames(30)
	var final_scene:=current_scene
	current_scene=null
	final_scene.queue_free()
	await process_frame
	print("LEVEL EDITOR: ","PASS" if failures==0 else "FAIL (%d)" % failures)
	quit(failures)
