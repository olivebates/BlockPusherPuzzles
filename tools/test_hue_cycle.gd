extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ")+message)
	if not value: failures+=1
func run() -> void:
	var progress := root.get_node("Progress")
	progress.enabled=false
	var world: Node2D=load("res://tools/test_world.gd").new().level()
	root.add_child(world)
	current_scene=world
	progress.level=world
	for i in 5: await physics_frame
	var player: CharacterBody2D=get_first_node_in_group("player")
	player.set_physics_process(false)
	var cycling: Node2D=load(LevelData.SCENES[9]).instantiate()
	cycling.position=Vector2(800,100)
	cycling.cycle_hue=true
	cycling.hex_color="#ffaa55"
	world.get_node("Objects").add_child(cycling)
	cycling.touched(player)
	paused=true
	await create_timer(0.5,true).timeout
	check(world.hue_cycling and world.hue_cycle_tween and world.hue_cycle_tween.is_running(),"A cycling changer starts a hue loop even while dialogue pauses gameplay")
	var initial: float=world.hue_shift
	var map := world.get_node("TeleportMap")
	var map_colors: Array=map.screen_colors()
	var sample: Vector2i=map.world_tile(player.global_position)+Vector2i(4,0)
	map.closest_distances.erase(sample)
	map.last_player_position=Vector2.INF
	paused=false
	map.reveal_screen()
	paused=true
	world.hue_cycle_tween.custom_step(3.0)
	check(absf(wrapf(world.hue_shift-initial,-0.5,0.5)-0.25)<0.001,"The hue advances continuously through a quarter turn in three seconds")
	check(map.screen_colors()==map_colors and not world.hue_palette.map_color(world.background_color).is_equal_approx(map_colors[0]),"Automatic rainbow cycling changes the world while the map keeps its last chosen color")
	player.global_position.x+=16
	paused=false
	map.reveal_screen()
	paused=true
	check(map.seen_colors[sample]==map_colors,"A closer visit during rainbow cycling records the last known fixed map color")
	map.rebuild_map()
	check(map.map_background==map_colors[0] and map.map_tiles==map_colors[1],"Rebuilding the map during rainbow cycling keeps its panel and fallback colors stable")
	var before_wrap: Color=world.hue_palette.map_color(HuePalette.DEFAULT_BACKGROUND)
	world.hue_cycle_tween.custom_step(12.0)
	check(world.hue_palette.map_color(HuePalette.DEFAULT_BACKGROUND).is_equal_approx(before_wrap) and world.hue_cycle_tween.is_running(),"A full hue turn loops without a color discontinuity or stopping")
	var saved: Dictionary=progress.snapshot()
	world.stop_hue_cycle()
	check(progress.apply_state(saved) and world.hue_cycling,"Progress restores an active hue loop")
	var fixed: Node2D=load(LevelData.SCENES[9]).instantiate()
	fixed.position=Vector2(832,100)
	fixed.hex_color="#6655ff"
	world.get_node("Objects").add_child(fixed)
	var before_stop: Color=world.hue_palette.map_color(HuePalette.DEFAULT_BACKGROUND)
	fixed.touched(player)
	check(not world.hue_cycling and world.hue_palette.map_color(HuePalette.DEFAULT_BACKGROUND).is_equal_approx(before_stop),"A non-cycling changer stops the loop without jumping from its current color")
	var fixed_map_colors: Array=map.screen_colors()
	await create_timer(0.5,true).timeout
	var final: Color=world.hue_palette.map_color(HuePalette.DEFAULT_BACKGROUND)
	await create_timer(0.1,true).timeout
	check(is_equal_approx(world.hue_shift,HuePalette.hue_offset(fixed.selected_color())) and world.hue_palette.map_color(HuePalette.DEFAULT_BACKGROUND).is_equal_approx(final),"The ordinary changer reaches its selected color and stays there")
	check(map.screen_colors()==fixed_map_colors and fixed_map_colors[0].is_equal_approx(world.hue_palette.map_color(world.background_color)),"A deliberate color changer still updates the map immediately to its new target")
	var data := LevelData.decode(LevelData.encode(LevelData.capture(world)))
	check(data.objects.any(func(item): return item[0]==9 and item.size()==6 and item[5]==true),"Level save/load preserves the exported hue-cycle toggle")
	for item in data.objects:
		if item[0]==9: item.resize(5)
	check(LevelData.valid(data),"Older color changer records without the toggle remain valid")
	check(LevelData.apply(world,data) and get_nodes_in_group("color_triggers").all(func(trigger): return not trigger.cycle_hue),"Older levels load color changers with cycling off")
	world.start_hue_cycle()
	saved.erase("hue_cycling")
	check(progress.apply_state(saved) and not world.hue_cycling,"Older progress saves default to a fixed hue")
	world.start_hue_cycle()
	paused=false
	check(world.reset_level() and not world.hue_cycling,"Resetting the level stops hue cycling")
	current_scene=null
	world.queue_free()
	await process_frame
	quit(failures)
