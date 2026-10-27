extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ")+message)
	if not value: failures+=1
func frames(count: int) -> void:
	for i in count: await physics_frame
func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func run() -> void:
	create_timer(30,true).timeout.connect(func(): quit(99))
	var progress := root.get_node("Progress")
	progress.save_root="user://tests/map_progress"
	progress.delete_progress(false)
	var game: Node2D=load("res://tools/test_world.gd").new().level()
	root.add_child(game)
	current_scene=game
	await frames(10)
	var objects := game.get_node("Objects")
	var player: CharacterBody2D=get_first_node_in_group("player")
	player.set_physics_process(false)
	var map := game.get_node("TeleportMap")
	var first := objects.get_node("RecallPlatformA")
	first.activated=true
	var far: Node2D=load(LevelData.SCENES[7]).instantiate()
	far.position=Vector2(1600,318)
	objects.add_child(far)
	far.activated=true
	var trigger: Node2D=load(LevelData.SCENES[17]).instantiate()
	trigger.position=player.position
	objects.add_child(trigger)
	var another: Node2D=load(LevelData.SCENES[17]).instantiate()
	another.position=Vector2(400,313)
	objects.add_child(another)
	await frames(3)
	for i in 3: await process_frame
	check(trigger.used and another.used and progress.map_hint_stage==1 and player.map_hint()=="TAB","One tutorial trigger consumes all triggers and shows TAB above the player")
	var walls: TileMapLayer=game.get_node("Walls")
	walls.set_cell(Vector2i(-4,-2),0,Vector2i.ZERO)
	map.rebuild_map()
	check(not map.explored.has(map.world_tile(far.global_position)) and not map.tile_bounds.has_point(Vector2i(100,20)),"Unseen distant level geometry does not expand the map")
	check(map.selectable().size()==1,"Unseen platforms are hidden from map navigation")
	var camera: Camera2D=game.get_node("Camera")
	var original_camera := camera.global_position
	camera.global_position=far.global_position
	camera.force_update_scroll()
	map.reveal_screen()
	camera.global_position=original_camera
	camera.force_update_scroll()
	key(KEY_TAB,true)
	key(KEY_TAB,false)
	for i in 3: await process_frame
	check(map.active and paused and map.title.text=="Map Teleport","TAB opens Map Teleport and pauses the game")
	check(map.selectable().size()==2 and map.selected==first,"Only visited platforms can be selected, starting with the nearest")
	check(map.texture.get_size()==Vector2(map.tile_bounds.size) and map.tile_bounds.position.x<0,"Each explored game tile is one image pixel, including negative map coordinates")
	var rect: Rect2=map.image_rect(Vector2(240,120))
	var large: Rect2=map.image_rect(Vector2(480,240))
	check(rect.size.x<=240.01 and rect.size.y<=120.01 and large.size.is_equal_approx(rect.size*2),"The map grows and shrinks proportionally to fill its viewing area")
	var panel: StyleBoxFlat=map.panel.get_theme_stylebox("panel")
	check(panel.bg_color==map.screen_colors()[0] and panel.border_color==map.screen_colors()[1] and panel.border_width_left==1,"The map panel uses the current game background and tile colors")
	var map_image: Image=map.texture.get_image()
	var wall_pixel: Vector2i=map.world_tile(walls.to_global(walls.map_to_local(Vector2i(0,20))))-map.tile_bounds.position
	var rendered_wall := map_image.get_pixelv(wall_pixel)
	var rendered_background := map_image.get_pixel(0,0)
	check(Vector3(rendered_wall.r-game.tile_color.r,rendered_wall.g-game.tile_color.g,rendered_wall.b-game.tile_color.b).length()<0.007 and Vector3(rendered_background.r-game.background_color.r,rendered_background.g-game.background_color.g,rendered_background.b-game.background_color.b).length()<0.007,"Map pixels match the game background and tiles at image byte precision")
	check(map_image.get_pixelv(Vector2i(60,20)-map.tile_bounds.position)==Color.BLACK,"Unseen tiles between explored areas remain black")
	var old_pulse: float=map.pulse
	map._process(0.2)
	check(map.pulse>old_pulse,"Platform breathing animation advances while the game is paused")
	check(map.panel.find_children("*","Label",true,false).size()==2 and map.footer.text.contains("SPACE") and map.footer.text.contains("Navigate"),"Only the map title and bottom keyboard controls are shown")
	key(KEY_TAB,true)
	key(KEY_TAB,false)
	check(not map.active and not paused and player.map_hint()=="TAB - Teleport","Closing the first map without teleporting upgrades the tutorial prompt")
	var remote_cell: Vector2i=map.world_tile(far.global_position)
	var previous_colors: Array=map.seen_colors[remote_cell].duplicate()
	var old_background: Color=game.background_color
	var old_tiles: Color=game.tile_color
	var original_player: Vector2=player.global_position
	var local_cell := Vector2i(8,19)
	var local_wall := Vector2i(8,20)
	var retreat_cell := Vector2i(0,19)
	for cell in [local_cell,local_wall,retreat_cell]: map.closest_distances.erase(cell)
	map.last_player_position=Vector2.INF
	map.reveal_screen()
	var first_colors: Array=map.screen_colors()
	game.background_color=Color("123456")
	game.tile_color=Color("abcdef")
	map.reveal_screen()
	check(map.seen_colors[local_cell]==first_colors,"A color change while standing still preserves the first closest-visit sample")
	player.global_position=original_player+Vector2(16,0)
	map.reveal_screen()
	var nearer_colors: Array=map.screen_colors()
	check(map.seen_colors[local_cell]==nearer_colors and map.seen_colors[local_wall]==nearer_colors,"Moving closer refreshes individual background and wall colors with a stationary camera")
	check(map.seen_colors[retreat_cell]==first_colors,"Tiles the player moves farther from retain their earlier closer-visit colors")
	check(map.seen_colors[remote_cell]==previous_colors,"Off-screen map cells retain their closest visible visit colors")
	game.hue_palette.reset(0.3)
	player.global_position=original_player
	map.reveal_screen()
	check(map.seen_colors[local_cell]==nearer_colors,"A later hue change from farther away cannot overwrite a closer visit")
	player.global_position=original_player+Vector2(32,0)
	map.reveal_screen()
	var shifted_colors: Array=map.screen_colors()
	check(map.seen_colors[local_cell]==shifted_colors and shifted_colors!=[game.background_color,game.tile_color],"A new closest visit captures the shader-transformed displayed colors")
	var best_distance: float=map.closest_distances[local_cell]
	game.hue_palette.reset(-0.2)
	map.reveal_screen()
	check(map.closest_distances[local_cell]==best_distance and map.seen_colors[local_cell]==shifted_colors,"Equal-distance visits keep the existing closest color")
	map.rebuild_map()
	var map_pixels: Image=map.texture.get_image()
	var local_pixel: Color=map_pixels.get_pixelv(local_cell-map.tile_bounds.position)
	var wall_color: Color=map_pixels.get_pixelv(local_wall-map.tile_bounds.position)
	var remembered_background: Color=shifted_colors[0]
	var remembered_wall: Color=shifted_colors[1]
	check(Vector3(local_pixel.r-remembered_background.r,local_pixel.g-remembered_background.g,local_pixel.b-remembered_background.b).length()<0.007 and Vector3(wall_color.r-remembered_wall.r,wall_color.g-remembered_wall.g,wall_color.b-remembered_wall.b).length()<0.007,"Map renders each closest-visit background and wall color independently of the current shader")
	check(map.layer>game.get_node("HueShift").layer and map.marker_layer.layer>map.layer,"Map pixels and markers render after the global hue shader")
	game.hue_palette.begin(0.4)
	game.hue_palette.blend(0.2)
	player.global_position=original_player+Vector2(40,0)
	map.reveal_screen()
	var target_colors: Array=map.screen_colors()
	var transition_colors := [game.hue_palette.map_color(game.background_color),game.hue_palette.map_color(game.tile_color)]
	check(target_colors!=transition_colors and map.seen_colors[local_cell]==target_colors,"Closest-visit colors use the transition target rather than an intermediate blend")
	game.hue_palette.blend(0.7)
	check(map.screen_colors()==target_colors,"Map target colors stay stable throughout a hue transition")
	game.hue_palette.begin(-0.1)
	player.global_position=original_player+Vector2(48,0)
	map.reveal_screen()
	check(map.seen_colors[local_cell]==map.screen_colors() and map.screen_colors()!=target_colors,"An interrupted transition captures its new target on a closer visit")
	game.background_color=old_background
	game.tile_color=old_tiles
	game.hue_palette.reset(0.0)
	player.global_position=original_player
	map.reveal_screen()
	check(map.open_map(),"The map can be reopened")
	var click := InputEventMouseButton.new()
	click.button_index=MOUSE_BUTTON_LEFT
	click.pressed=true
	map.backdrop.gui_input.emit(click)
	check(not map.active and not paused,"Clicking the translucent backdrop closes the map")
	map.open_map()
	key(KEY_D,true)
	key(KEY_D,false)
	check(map.selected==far,"WASD navigation selects the next platform by direction")
	key(KEY_LEFT,true)
	key(KEY_LEFT,false)
	check(map.selected==first,"Arrow navigation selects platforms too")
	map.navigate(Vector2.RIGHT)
	var guide := game.get_node("PlatformGuide")
	check(not guide.teleport_to(far),"Ordinary Q teleport still rejects off-screen platforms")
	var obstacle := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size=Vector2(16,16)
	collision.shape=shape
	obstacle.add_child(collision)
	obstacle.position=far.arrival_position()
	game.add_child(obstacle)
	for i in 3: await process_frame
	check(not map.teleport_selected() and map.active and not progress.map_teleported,"An obstructed destination keeps the map open without completing the tutorial")
	obstacle.free()
	for i in 3: await process_frame
	key(KEY_SPACE,true)
	key(KEY_SPACE,false)
	check(not map.active and not paused and player.position.distance_to(far.arrival_position())<0.2,"SPACE teleports to a visited off-screen platform and closes the map")
	check(game.get_node("Camera").position.distance_to(player.position)<0.2,"Long-distance map teleporting snaps the camera straight to the player")
	check(progress.map_teleported and progress.map_hint_stage==3 and player.map_hint().is_empty(),"The first map teleport permanently dismisses the tutorial prompt")
	player.set_physics_process(true)
	await frames(5)
	check(player.position.y>far.arrival_position().y-1 and player.velocity.y>=0,"The teleport key does not also make the player jump after arrival")
	player.set_physics_process(false)
	progress.level=game
	check(progress.save_now(),"Map tutorial completion can be saved")
	var saved: Dictionary=progress.read_file(progress.save_root+"/current.cps")
	var explored_count: int=map.explored.size()
	map.restore_exploration([])
	progress.map_hint_stage=0
	progress.map_opened=false
	progress.map_teleported=false
	check(progress.apply_state(saved) and progress.map_hint_stage==3 and progress.map_teleported,"Map tutorial and first teleport state survive compressed save/load")
	check(map.explored.size()==explored_count,"Explored map tiles survive compressed save/load")
	var legacy := saved.duplicate(true)
	legacy.erase("map_tutorial")
	check(progress.apply_state(legacy) and progress.map_hint_stage==0,"Older progress saves remain compatible without map tutorial fields")
	progress.map_opened=true
	var late: Node2D=load(LevelData.SCENES[17]).instantiate()
	late.position=player.position
	objects.add_child(late)
	await frames(3)
	check(player.map_hint()=="TAB - Teleport","A trigger after an earlier map visit uses the expanded tutorial hint")
	var level_data := LevelData.decode(LevelData.encode(LevelData.capture(game)))
	check(level_data.objects.any(func(item): return int(item[0])==17),"Map triggers survive compressed level snapshot save/load")
	root.get_node("Dialogue").begin("",StoryLines.OPENING)
	check(not map.open_map() and not map.active,"The map cannot interrupt a dialogue")
	root.get_node("Dialogue").stop()
	progress.enabled=false
	current_scene=null
	game.queue_free()
	await process_frame
	quit(failures)
