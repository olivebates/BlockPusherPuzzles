extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ")+message)
	if not value: failures+=1
func frames(count: int) -> void:
	for i in count: await physics_frame
func run() -> void:
	create_timer(20,true).timeout.connect(func(): quit(99))
	for offset in [-0.19,0.19]:
		for direction in [-1,1]:
			for block_first in [false,true]:
				await push_offset_box(offset,direction,block_first)
	quit(failures)
func push_offset_box(offset: float, direction: int, block_first: bool) -> void:
	var game: Node2D=load("res://tools/test_world.gd").new().level()
	for child in game.get_node("Objects").get_children(): child.free()
	var objects := game.get_node("Objects")
	var player: CharacterBody2D=load(LevelData.SCENES[1]).instantiate()
	player.position=Vector2(168-direction*21,313)
	objects.add_child(player)
	var block: CharacterBody2D=load(LevelData.SCENES[2]).instantiate()
	# Fall onto the floor from a valid fractional spawn, without starting embedded.
	block.position=Vector2(168,296+offset)
	objects.add_child(block)
	if block_first: objects.move_child(block,0)
	root.add_child(game)
	current_scene=game
	await frames(24)
	var context := " (offset %.2f, direction %d, block first %s)" % [offset,direction,block_first]
	var unsupported := 0
	for i in 12:
		await frames(1)
		if not block.grounded: unsupported+=1
	check(unsupported==0 and absf(block.position.y-312)<0.001,"A resting box keeps exact grounded contact"+context)
	var action := "right" if direction>0 else "left"
	Input.action_press(action)
	for i in 40:
		await frames(1)
		if block.sliding: break
	Input.action_release(action)
	await frames(12)
	check(absf(block.position.x-168-direction*16)<0.001,"A fractional spawn accepts a player push and finishes exactly one tile"+context)
	current_scene=null
	game.queue_free()
	await process_frame
