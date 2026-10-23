extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ")+message)
	if not value: failures += 1
func frames(count: int) -> void:
	for i in count: await physics_frame
func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func box(parent: Node, point: Vector2, hue := 0) -> CharacterBody2D:
	var node: CharacterBody2D=load(LevelData.SCENES[2]).instantiate()
	node.position=point
	node.block_color=hue
	parent.add_child(node)
	return node
func obstacle(parent: Node, point: Vector2, size := Vector2(16,16)) -> StaticBody2D:
	var body := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size=size
	collider.shape=shape
	body.add_child(collider)
	body.position=point
	parent.add_child(body)
	return body
func run() -> void:
	create_timer(30,true).timeout.connect(func(): quit(99))
	var game: Node2D=load("res://tools/test_world.gd").new().level()
	root.add_child(game)
	current_scene=game
	await frames(10)
	var objects := game.get_node("Objects")
	var player: CharacterBody2D=get_first_node_in_group("player")
	player.set_physics_process(false)
	for direction in [-1,1]:
		var falling := box(objects,Vector2(680,248),2)
		player.position=Vector2(680+direction*10.85,281)
		player.force_update_transform()
		await frames(40)
		check(falling.position.y>300 and not falling.supported_by_player,"A player beside a falling box does not hold it up (%s side)" % ("left" if direction<0 else "right"))
		check(falling.get_collision_exceptions().is_empty(),"Falling restores temporary player collision exclusions")
		falling.free()
	var supported := box(objects,Vector2(680,248),2)
	player.position=Vector2(680,281)
	player.force_update_transform()
	await frames(30)
	check(supported.supported_by_player and absf(supported.position.y-264)<0.2,"Standing underneath a falling box still supports it on the grid")
	player.position.x+=11.5
	player.force_update_transform()
	await frames(30)
	check(supported.position.y>300 and not supported.supported_by_player,"A supported box resumes falling when the player moves beside it")
	supported.free()
	player.position=Vector2(56,313)
	player.set_physics_process(true)
	var block := box(objects,Vector2(808,312))
	var walls: TileMapLayer=game.get_node("Walls")
	for x in [48,49,51,52]: walls.set_cell(Vector2i(x,19),0,Vector2i.ZERO)
	player.position=Vector2(808,297)
	player.velocity=Vector2.ZERO
	await frames(8)
	Input.action_press("right")
	await frames(24)
	Input.action_release("right")
	check(player.position.x>826 and player.position.y<298,"Player walks right from a box onto an adjacent solid tile without jumping")
	player.position=Vector2(808,297)
	player.velocity=Vector2.ZERO
	await frames(5)
	Input.action_press("left")
	await frames(24)
	Input.action_release("left")
	check(player.position.x<790 and player.position.y<298,"Player also walks left across the box-to-tile seam")
	player.set_physics_process(false)
	player.position=Vector2(56,313)
	for x in [48,49,51,52]: walls.erase_cell(Vector2i(x,19))
	# The left ceiling catches the player's edge, but the tile above home is clear.
	var ledge := obstacle(game,Vector2(792,296))
	block.position=Vector2(856,312)
	block.resting_x=856
	player.position=Vector2(804,312)
	await frames(2)
	block.reset_home()
	check(block.position.distance_to(block.home)<0.01 and player.position.y<298 and player.position.x>=804 and player.position.x<=808,"Recall clears a ledge while preserving the block's exact spawn")
	ledge.queue_free()
	await frames(3)
	block.position=Vector2(856,312)
	block.resting_x=856
	# The current player collider extends six pixels below its origin.
	player.position=Vector2(856,298.1)
	player.force_update_transform()
	await frames(2)
	block.reset_home()
	check(player.position.distance_to(Vector2(808,297.9))<0.4 and block.position.distance_to(block.home)<0.1 and player.velocity==Vector2.ZERO,"Recalling a ridden block carries the player safely to its home")
	player.position=Vector2(56,313)
	var sphere: CharacterBody2D=objects.get_node("WhiteSphere")
	sphere.position=Vector2(856,280)
	sphere.sliding=false
	sphere.charging=false
	player.position=Vector2(856,266)
	player.force_update_transform()
	await frames(2)
	sphere.reset_home()
	check(absf(player.position.x-sphere.home.x)<0.2 and player.position.y<sphere.home.y-14 and player.velocity==Vector2.ZERO,"Recalling a ridden sphere carries the player too")
	# A moved box only advertises R when its left or right side is obstructed.
	block.position=Vector2(856,312)
	block.resting_x=856
	player.position=Vector2(842,313)
	player.update_recall_target()
	check(not player.show_recall_prompt,"Unobstructed displaced boxes have no R prompt")
	var side := obstacle(game,Vector2(872,312))
	await frames(2)
	player.update_recall_target()
	check(player.show_recall_prompt,"A side obstruction enables the R prompt")
	side.queue_free()
	# An upside-down L can hang from the player while its side member is pushed.
	player.position=Vector2(744,313)
	var overhead := box(objects,Vector2(744,264),3)
	box(objects,Vector2(760,264),3)
	var contact := box(objects,Vector2(760,280),3)
	await frames(55)
	check(overhead.leader.members.size()==3 and overhead.supported_by_player and absf(overhead.position.y-296)<0.2,"Welded overhang rests on the player's grid tile")
	player.set_physics_process(true)
	player.velocity=Vector2.ZERO
	Input.action_press("jump")
	await frames(1)
	Input.action_release("jump")
	var held_y: float=overhead.position.y
	await frames(10)
	check(absf(overhead.position.y-held_y)<0.2 and overhead.supported_by_player and absf(overhead.velocity.y)<0.01,"Jumping beneath a supported weld does not restart its gravity")
	await frames(15)
	Input.action_press("right")
	await frames(7)
	check(overhead.push_contact==contact and overhead.charge>0 and contact.leader==overhead,"Only the side member actually being pushed owns the welded push charge")
	await frames(23)
	Input.action_release("right")
	check(overhead.position.x>759 and absf(contact.position.x-overhead.position.x-16)<0.2,"A player-supported welded block can still be pushed as one object")
	player.set_physics_process(false)
	# Snapshot restore also resets stateful objects and keeps the same player instance.
	var initial: Dictionary=game.initial_level.duplicate(true)
	var expected_blocks := 0
	for item in initial.objects:
		if int(item[0])==2: expected_blocks+=1
	player.position=Vector2(900,200)
	var retained_point := player.position
	var retained_id := player.get_instance_id()
	objects.get_node("RecallPlatformA").activated=true
	game.background_color=Color.RED
	walls.erase_cell(Vector2i(0,20))
	key(KEY_SHIFT,true)
	key(KEY_Z,true)
	key(KEY_O,true)
	await frames(3)
	key(KEY_O,false)
	key(KEY_Z,false)
	key(KEY_SHIFT,false)
	check(player.get_instance_id()==retained_id and player.position==retained_point,"Shift+Z+O resets the world while preserving the exact player instance and position")
	check(get_nodes_in_group("blocks").size()==expected_blocks and get_nodes_in_group("recall_platforms").all(func(p): return not p.activated),"Reset restores the original objects and clears platform activation")
	check(walls.get_cell_source_id(Vector2i(0,20))==0 and game.background_color==game.initial_background,"Reset restores wall tiles and the original theme")
	await frames(3)
	current_scene=null
	game.queue_free()
	await process_frame
	print("RECALL AND SUPPORT: ","PASS" if failures==0 else "FAIL")
	quit(failures)
