extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(condition: bool, message: String) -> void:
	if condition: print("PASS: ",message)
	else:
		failures += 1
		push_error("FAIL: "+message)
func frames(count: int) -> void:
	for i in count: await physics_frame
func run() -> void:
	var level: Node2D = load("res://tools/test_world.gd").new().level()
	root.add_child(level)
	current_scene = level
	await frames(12)
	var player := get_first_node_in_group("player")
	var blocks := get_nodes_in_group("blocks")
	var pads := get_nodes_in_group("pads")
	var block = blocks[0]
	check(player.is_on_floor(),"Black TileSet supports player")
	check(block.is_on_floor(),"Black TileSet supports gravity blocks")
	var start: Vector2 = block.global_position
	for i in 10:
		block.try_push(1.0,1.0/60.0)
		await frames(1)
	check(block.global_position.distance_to(start)<0.2,"Push waits more than 0.2 seconds")
	for i in 4:
		block.try_push(1.0,1.0/60.0)
		await frames(1)
	await frames(15)
	check(absf(block.global_position.x-start.x-16)<0.2,"Push eases exactly one tile")
	block.reset_home()
	await frames(3)
	check(block.global_position.distance_to(start)<0.2,"Recall restores starting location")
	player.global_position = block.global_position + Vector2(0,-15)
	await frames(4)
	check(player.touching_block() == block,"Standing on a block counts as touching for recall")
	player.global_position = Vector2(56,313)
	await frames(4)
	for i in 7:
		block.try_push(1.0,1.0/60.0)
		await frames(1)
	await frames(3)
	check(block.charge == 0,"Interrupted pushing clears charge")
	# Exercise player input and actual side contact rather than only block methods.
	player.global_position = block.global_position + Vector2(-13.1,1)
	await frames(3)
	Input.action_press("right")
	await frames(27)
	Input.action_release("right")
	check(block.global_position.x > start.x+15.5,"Grounded player input pushes block through collision contact")
	player.global_position = Vector2(56,313)
	block.reset_home()
	await frames(5)
	var floor_y: float = player.position.y
	Input.action_press("jump")
	var apex := floor_y
	for i in 42:
		await frames(1)
		apex = minf(apex,player.position.y)
	Input.action_release("jump")
	check(absf((floor_y-apex)-40)<0.8,"Full jump apex is 2.5 tiles (actual %.2f)" % (floor_y-apex))
	await frames(20)
	Input.action_press("jump")
	await frames(4)
	Input.action_release("jump")
	var short_apex: float = player.position.y
	for i in 38:
		await frames(1)
		short_apex = minf(short_apex,player.position.y)
	check(absf(floor_y-short_apex-40)<0.8,"Released jump retains the same 2.5-tile height")
	var gate := level.get_node("Objects/Door_A")
	for i in 2: blocks[i].global_position = pads[i].global_position
	await frames(5)
	check(not gate.opened,"Two cyan pads alone do not satisfy coral requirement")
	blocks[2].global_position = pads[2].global_position
	await frames(5)
	check(gate.opened,"All repeated-color and multi-color pads open door")
	blocks[0].global_position.x -= 16
	await frames(5)
	check(not gate.opened,"Removing one of two cyan blocks closes door")
	blocks[0].global_position = pads[0].global_position
	await frames(5)
	player.global_position = gate.global_position
	blocks[0].global_position.x -= 16
	await frames(5)
	check(gate.opened,"Door waits while occupied")
	player.global_position = Vector2(56,313)
	await frames(5)
	check(not gate.opened,"Door closes after occupant exits")
	var before_fall: float = block.position.y
	block.global_position = Vector2(200,220)
	await frames(10)
	check(block.position.y > 225,"Unsupported block falls under gravity")
	block.reset_home()
	await frames(5)
	check(absf(block.position.y-before_fall)<1,"Falling block recalls safely")
	print("GAMEPLAY CHECKS: ","PASS" if failures == 0 else "FAIL (%d)" % failures)
	# Let ephemeral particle tweens finish before orderly scene teardown.
	await frames(30)
	current_scene = null
	level.queue_free()
	await process_frame
	quit(failures)
