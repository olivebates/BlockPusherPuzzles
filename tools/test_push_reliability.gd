extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ")+message)
	if not value: failures+=1
func frames(count: int) -> void:
	for i in count: await physics_frame
func run() -> void:
	create_timer(25,true).timeout.connect(func(): quit(99))
	var game: Node2D=load("res://tools/test_world.gd").new().level()
	for child in game.get_node("Objects").get_children(): child.free()
	var objects := game.get_node("Objects")
	var player: CharacterBody2D=load(LevelData.SCENES[1]).instantiate()
	player.position=Vector2(147,313)
	objects.add_child(player)
	var block: CharacterBody2D=load(LevelData.SCENES[2]).instantiate()
	block.position=Vector2(168,312)
	objects.add_child(block)
	root.add_child(game)
	current_scene=game
	await frames(12)
	var discarded := 0
	var started := 0
	Input.action_press("right")
	for i in 180:
		var charge: float=block.charge
		var sliding: bool=block.sliding
		await frames(1)
		if not sliding and block.sliding: started+=1
		if charge>0.18 and block.charge==0 and not block.sliding: discarded+=1
	Input.action_release("right")
	await frames(18)
	check(started>=5 and discarded==0,"Repeated player pushes never discard a completed charge")
	player.set_physics_process(false)
	player.position=Vector2(56,313)
	await frames(3)
	var wall := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size=Vector2(16,16)
	collider.shape=shape
	wall.add_child(collider)
	wall.position=block.position+Vector2(16,0)
	game.add_child(wall)
	await frames(3)
	for i in 14:
		block.try_push(1,1.0/60)
		await frames(1)
	check(block.charge>=block.push_delay and not block.sliding,"A temporarily blocked push keeps its completed charge")
	wall.free()
	var before := block.position
	block.try_push(1,1.0/60)
	check(block.sliding,"Removing an obstruction starts the ready push immediately")
	await frames(15)
	check(absf(block.position.x-before.x-16)<0.2,"The retry completes exactly one tile without another charge")
	var completions := [0]
	var push_sounds := [0]
	var juice := root.get_node("Juice")
	juice.block_pushed.connect(func(): completions[0]+=1)
	juice.sound_played.connect(func(kind: String):
		if kind=="push": push_sounds[0]+=1)
	block.set_physics_process(false)
	for i in 12: block.try_push(1,1.0/60)
	var accepted_from := block.position
	check(block.sliding,"A completed charge accepts the next tile push")
	var temporary := StaticBody2D.new()
	var temporary_collider := CollisionShape2D.new()
	temporary_collider.shape=shape
	temporary.add_child(temporary_collider)
	temporary.position=accepted_from+Vector2(16,0)
	game.add_child(temporary)
	await frames(2)
	block.set_physics_process(true)
	await frames(3)
	check(block.sliding and block.position.distance_to(accepted_from)<0.01,"An obstruction appearing after the charge preserves the accepted push")
	check(push_sounds[0]==0 and completions[0]==0,"An interrupted move does not play completion feedback or consume a turn")
	temporary.free()
	await frames(16)
	check(absf(block.position.x-accepted_from.x-16)<0.01 and completions[0]==1,"The accepted push resumes one exact tile without another charge")
	block.set_physics_process(false)
	for i in 12: block.try_push(1,1.0/60)
	var midway_from := block.position
	block.set_physics_process(true)
	await frames(3)
	var midway_wall := StaticBody2D.new()
	var midway_collider := CollisionShape2D.new()
	midway_collider.shape=shape
	midway_wall.add_child(midway_collider)
	midway_wall.position=midway_from+Vector2(20,0)
	game.add_child(midway_wall)
	await frames(10)
	check(block.sliding and block.position.x>midway_from.x and block.position.x<midway_from.x+16 and completions[0]==1,"A mid-slide obstruction pauses progress without completing or restarting the push")
	midway_wall.free()
	await frames(16)
	check(absf(block.position.x-midway_from.x-16)<0.01 and completions[0]==2 and push_sounds[0]==2,"A paused move finishes at its original grid target and plays feedback exactly once")
	current_scene=null
	game.queue_free()
	await process_frame
	quit(failures)
