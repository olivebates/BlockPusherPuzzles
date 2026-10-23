extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ")+message)
	if not value: failures += 1
func run() -> void:
	create_timer(20,true).timeout.connect(func(): quit(99))
	var game: Node2D = load("res://tools/test_world.gd").new().level()
	root.add_child(game)
	current_scene = game
	await process_frame
	var trigger: Area2D = load(LevelData.SCENES[9]).instantiate()
	trigger.hex_color = "#ffffff"
	trigger.background_color = Color("283347")
	trigger.tile_color = Color("172c20")
	trigger.position = Vector2(800,80)
	game.get_node("Objects").add_child(trigger)
	var platform: StaticBody2D = load(LevelData.SCENES[8]).instantiate()
	platform.position = Vector2(832,80)
	game.get_node("Objects").add_child(platform)
	trigger.touched(get_first_node_in_group("player"))
	await create_timer(0.5).timeout
	check(game.background_color.is_equal_approx(trigger.background_color),"White tint preserves the exact manual background color")
	check(game.tile_color.is_equal_approx(trigger.tile_color),"White tint preserves the exact manual tile color")
	check(platform.tile_color.is_equal_approx(trigger.tile_color),"One-way tiles use the exact custom tile color too")
	var saved := LevelData.decode(LevelData.encode(LevelData.capture(game)))
	var entry: Array = []
	for item in saved.objects:
		if int(item[0])==9: entry=item
	check(entry.size()==7 and entry[5]==trigger.background_color.to_html() and entry[6]==trigger.tile_color.to_html(),"Compressed level preserves both custom colors")
	check(LevelData.apply(game,saved),"Saved custom theme can be reloaded")
	var loaded: Node
	for object in game.get_node("Objects").get_children():
		if object.get_script().resource_path==LevelData.SCRIPTS[9]: loaded=object
	check(loaded.background_color==Color("283347") and loaded.tile_color==Color("172c20"),"Reload restores the trigger's exported colors")
	for item in saved.objects:
		if int(item[0])==9: item.resize(5)
	check(LevelData.apply(game,saved),"Older levels without custom base colors still load")
	for object in game.get_node("Objects").get_children():
		if object.get_script().resource_path==LevelData.SCRIPTS[9]: loaded=object
	check(loaded.background_color==Color(0.6,0.6,0.6,1) and loaded.tile_color==Color(0.2,0.2,0.2,1),"Older triggers retain the existing darkness defaults")
	current_scene = null
	game.queue_free()
	await process_frame
	quit(failures)
