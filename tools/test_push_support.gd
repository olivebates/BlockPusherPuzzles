extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ")+message)
	if not value: failures+=1
func frames(count: int) -> void:
	for i in count: await physics_frame
func box(parent: Node, point: Vector2) -> CharacterBody2D:
	var body: CharacterBody2D=load(LevelData.SCENES[2]).instantiate()
	body.position=point
	parent.add_child(body)
	return body
func run() -> void:
	create_timer(20,true).timeout.connect(func(): quit(99))
	var game: Node2D=load("res://tools/test_world.gd").new().level()
	for child in game.get_node("Objects").get_children(): child.free()
	var objects := game.get_node("Objects")
	var player: CharacterBody2D=load(LevelData.SCENES[1]).instantiate()
	player.position=Vector2(312,298)
	objects.add_child(player)
	var base := box(objects,Vector2(312,312))
	box(objects,Vector2(328,312))
	var upright := box(objects,Vector2(328,296))
	root.add_child(game)
	current_scene=game
	await frames(10)
	check(base.members.size()==3 and SupportCarry.supports(base,player),"The player stands on the lower arm of a welded box")
	Input.action_press("right")
	await frames(34)
	Input.action_release("right")
	await frames(12)
	check(base.position.x>=327.8 and upright.position.x-base.position.x>15.8,"A grounded player can push the welded box they are standing on through its upright side")
	player.position=Vector2(600,298)
	player.velocity=Vector2.ZERO
	var right_base := box(objects,Vector2(600,312))
	box(objects,Vector2(584,312))
	box(objects,Vector2(584,296))
	await frames(10)
	Input.action_press("left")
	await frames(34)
	Input.action_release("left")
	await frames(12)
	check(right_base.position.x<=584.2,"Standing on a welded box also permits pushing it left")
	var walls: TileMapLayer=game.get_node("Walls")
	walls.set_cell(Vector2i(45,18),0,Vector2i.ZERO)
	var flush := box(objects,Vector2(728,280))
	await frames(8)
	player.position=Vector2(716.98,260)
	player.velocity=Vector2(0,80)
	player.recall_freeze_frames=0
	Input.action_press("right")
	await frames(60)
	Input.action_release("right")
	check(flush.position.distance_to(Vector2(728,280))<0.2,"Falling alongside a box and its flush wall cannot push the box from a wall-edge contact")
	check(player.position.y>300,"The player falls past the flush wall edge rather than hanging on it")
	current_scene=null
	game.queue_free()
	await process_frame
	quit(failures)
