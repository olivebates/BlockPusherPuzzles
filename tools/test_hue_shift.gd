extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ")+message)
	if not value: failures+=1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var progress := root.get_node("Progress")
	progress.enabled=false
	var world: Node2D=load("res://tools/test_world.gd").new().level()
	# Added wall layers can cover the original Walls layer and must share its tint.
	var extra_walls := TileMapLayer.new()
	extra_walls.name="Walls2"
	extra_walls.tile_set=world.get_node("Walls").tile_set
	extra_walls.material=world.get_node("Walls").material.duplicate()
	extra_walls.material.set_shader_parameter("tile_color",Color(0.25,0.25,0.25,1))
	world.add_child(extra_walls)
	root.add_child(world)
	current_scene=world
	await process_frame
	progress.level=world
	var hue_layer := world.get_node("HueShift") as CanvasLayer
	check(hue_layer.layer>root.get_node("Dialogue").layer and hue_layer.get_child(0) is BackBufferCopy,"Hue pass includes world effects, map, settings and dialogue without intercepting input")
	var background := Color("246a80")
	var tiles := Color("172733")
	var tint := Color.from_hsv(0.25,0.8,1)
	var original_background: Color=world.background_color
	var original_tiles: Color=world.tile_color
	var rotator: Node2D=load(LevelData.SCENES[10]).instantiate()
	rotator.position=Vector2(800,200)
	world.get_node("Objects").add_child(rotator)
	world.change_theme(tint)
	# Dialogue pauses the tree, but palette transitions must continue.
	paused=true
	await create_timer(0.5,true).timeout
	check(is_equal_approx(world.hue_shift,HuePalette.hue_offset(tint)),"Hue changes finish while dialogue pauses the world")
	check(world.hue_material.get_shader_parameter("hue_palette")==world.hue_palette.texture,"The screen shader receives the shared palette")
	check(world.background_color==original_background and world.tile_color==original_tiles,"Color changers leave background and tile source colors, saturation and brightness unchanged")
	check(extra_walls.material.get_shader_parameter("tile_color")==world.tile_color,"Additional wall layers receive the dark source tint instead of staying gray")
	var player: CharacterBody2D=get_first_node_in_group("player")
	check(world.hue_exempt_view.get_child(0).player_sprites.has(player.get_instance_id()),"The player is included in the separate color-exclusion mask")
	check(world.hue_material.get_shader_parameter("exempt_texture")==world.hue_exempt_view.get_texture(),"Rotators and pivot circles share the exclusion mask, independently of box colors")
	var palette := HuePalette.new()
	var before := PuzzlePalette.color_for(0)
	palette.begin(0.5)
	palette.blend(0.5)
	var target := Color.from_hsv(wrapf(before.h+0.5,0,1),before.s,before.v)
	check(palette.map_color(before).is_equal_approx(before.lerp(target,0.5)),"Transition midpoint is the direct RGB midpoint, without intermediate wheel colors")
	var interrupted := palette.map_color(before)
	palette.begin(0.2)
	palette.blend(0)
	check(palette.map_color(before).is_equal_approx(interrupted),"Touching another changer starts from the exact current blend without a jump")
	palette.blend(0.5)
	target=Color.from_hsv(wrapf(before.h+0.2,0,1),before.s,before.v)
	check(palette.map_color(before).is_equal_approx(interrupted.lerp(target,0.5)),"Interrupted transitions blend straight to their new color")
	for group in ["blocks","pads","doors"]:
		var object: Node2D=get_first_node_in_group(group)
		check(object!=null and not palette.map_color(PuzzlePalette.color_for(0)).is_equal_approx(PuzzlePalette.color_for(0)),group+" receive the shared shifted palette")
	var changer: Node2D=load(LevelData.SCENES[9]).instantiate()
	world.get_node("Objects").add_child(changer)
	var properties: Array=changer.get_property_list().map(func(p): return p.name)
	check(not properties.has("background_color") and not properties.has("tile_color"),"Color changers no longer export background or tile colors")
	var level_data := LevelData.capture(world)
	check(level_data.objects.filter(func(item): return int(item[0])==9)[0].size()==6,"Level saves store the hue-cycle toggle without the removed color parameters")
	world.change_theme(tint)
	await create_timer(0.5,true).timeout
	check(is_equal_approx(world.hue_shift,HuePalette.hue_offset(tint)),"Repeated visits do not accumulate hue rotation")
	world.hue_shift=0.98
	world.change_theme(Color.from_hsv(0.02,1,1))
	await create_timer(0.5,true).timeout
	check(is_equal_approx(world.hue_shift,HuePalette.hue_offset(Color.from_hsv(0.02,1,1))),"Targets use a hue relative to teal without accumulating repeated shifts")
	var saved: Dictionary=progress.snapshot()
	world.hue_shift=0
	check(progress.apply_state(saved) and is_equal_approx(world.hue_shift,HuePalette.hue_offset(Color.from_hsv(0.02,1,1))),"Progress restores the same hue for every object")
	saved.erase("hue_shift")
	check(progress.apply_state(saved) and world.hue_shift==0,"Older progress saves remain compatible")
	paused=false
	world.reset_level()
	check(world.hue_shift==0 and world.hue_palette.map_color(before).is_equal_approx(before),"Resetting the level restores its original palette")
	check(world.background_color==HuePalette.DEFAULT_BACKGROUND and world.tile_color==HuePalette.DEFAULT_TILES,"The initial world palette restores the original teal background and tiles")
	world.change_theme(HuePalette.DEFAULT_COLOR)
	await create_timer(0.5,true).timeout
	check(world.hue_palette.map_color(before).is_equal_approx(before),"Touching a default teal changer keeps the original block colors")
	saved.erase("hue_reference")
	saved.hue_shift=HuePalette.DEFAULT_COLOR.h
	saved.theme=["999999","333333"]
	check(progress.apply_state(saved) and is_zero_approx(world.hue_shift) and world.background_color==HuePalette.DEFAULT_BACKGROUND,"Older saved progress adopts teal without rotating the original block palette")
	world.queue_free()
	await process_frame
	print("HUE SHIFT: ","PASS" if failures==0 else "FAIL")
	quit(failures)
