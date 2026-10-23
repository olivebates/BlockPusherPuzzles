extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ")+message)
	if not value: failures+=1
func frames(count: int) -> void:
	for i in count: await physics_frame
func box(parent: Node, point: Vector2, hue := 0) -> CharacterBody2D:
	var node: CharacterBody2D=load(LevelData.SCENES[2]).instantiate()
	node.position=point
	node.block_color=hue
	parent.add_child(node)
	return node
func push(body: CharacterBody2D, direction: float) -> void:
	for i in 14:
		body.try_push(direction,1.0/60)
		await frames(1)
	await frames(55)
func run() -> void:
	create_timer(20,true).timeout.connect(func(): quit(99))
	var game: Node2D=load("res://tools/test_world.gd").new().level()
	root.add_child(game)
	current_scene=game
	await frames(8)
	get_first_node_in_group("player").set_physics_process(false)
	var walls: TileMapLayer=game.get_node("Walls")
	for x in [51,46,41,42]:
		for y in range(20,24): walls.erase_cell(Vector2i(x,y))
	var objects := game.get_node("Objects")
	var right := box(objects,Vector2(808,312))
	var left := box(objects,Vector2(760,312),1)
	var weld := box(objects,Vector2(648,312),2)
	var member := box(objects,Vector2(664,312),2)
	await frames(8)
	await push(right,1)
	check(absf(right.position.x-824)<0.2 and absf(right.position.y-376)<0.3,"Pushing right off a ledge falls into the adjacent one-tile gap")
	await push(left,-1)
	check(absf(left.position.x-744)<0.2 and absf(left.position.y-376)<0.3,"Pushing left off a ledge falls instead of resting on its corner")
	await push(weld,1)
	check(absf(weld.position.y-376)<0.3 and absf(member.position.y-weld.position.y)<0.2,"Welded boxes fall together once all support leaves the ledge")
	current_scene=null
	game.queue_free()
	await process_frame
	quit(failures)
