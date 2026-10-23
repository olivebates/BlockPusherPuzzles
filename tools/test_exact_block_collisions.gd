extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ")+message)
	if not value: failures+=1
func frames(count: int) -> void:
	for i in count: await physics_frame
func box(parent: Node, point: Vector2, hue: int) -> CharacterBody2D:
	var body: CharacterBody2D=load(LevelData.SCENES[2]).instantiate()
	body.position=point
	body.block_color=hue
	parent.add_child(body)
	return body
func run() -> void:
	create_timer(25,true).timeout.connect(func(): quit(99))
	var game: Node2D=load("res://tools/test_world.gd").new().level()
	for child in game.get_node("Objects").get_children(): child.free()
	var objects := game.get_node("Objects")
	var player: CharacterBody2D=load(LevelData.SCENES[1]).instantiate()
	player.position=Vector2(56,313)
	objects.add_child(player)
	root.add_child(game)
	current_scene=game
	var walls: TileMapLayer=game.get_node("Walls")
	for x in [16,18,26,29]:
		for y in range(8,20): walls.set_cell(Vector2i(x,y),0,Vector2i.ZERO)
	var single := box(objects,Vector2(280,152),0)
	var welded := box(objects,Vector2(440,152),1)
	var member := box(objects,Vector2(456,152),1)
	check(single.get_node("CollisionShape2D").shape.size==Vector2(16,16) and single.get_node("CollisionShape2D").position==Vector2.ZERO,"Box hitboxes are exactly 16 by 16 and centered on their sprites")
	await frames(75)
	check(absf(single.position.y-312)<0.001 and absf(single.position.x-280)<0.001,"A full-size box falls through an exactly 16-pixel shaft flush against both walls")
	check(welded.members.size()==2 and absf(welded.position.y-312)<0.001 and absf(member.position.y-312)<0.001,"A welded pair falls through an exactly 32-pixel shaft without catching wall edges")
	check(PuzzlePhysics.colliders(welded).all(func(collider): return collider.shape.size==Vector2(16,16)),"Every welded member retains its full 16-pixel collision shape")
	check(single.grounded,"Actual floor overlap stops the fall and reports grounded contact")
	walls.erase_cell(Vector2i(17,20))
	await frames(30)
	check(absf(single.position.y-328)<0.001 and absf(single.position.x-280)<0.001,"Removing support lets a flush full-size box fall to the next tile without a corner perch")
	current_scene=null
	game.queue_free()
	await process_frame
	quit(failures)
