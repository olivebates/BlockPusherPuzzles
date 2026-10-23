extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	print(("PASS: " if condition else "FAIL: ")+message)
	if not condition: failures += 1
func frames(count: int) -> void:
	for i in count: await physics_frame
func obstruction(level: Node, point: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	body.position = point
	level.add_child(body)
	return body
func run() -> void:
	var level: Node2D = load("res://tools/test_world.gd").new().level()
	root.add_child(level)
	current_scene = level
	await frames(12)
	var player: CharacterBody2D = get_first_node_in_group("player")
	var objects := level.get_node("Objects")
	var block: CharacterBody2D = objects.get_node("Block_0")
	var weld: CharacterBody2D = objects.get_node("WeldedLilac0")
	var follower: CharacterBody2D = objects.get_node("WeldedLilac1")
	check(weld.leader == follower.leader and weld.members.size() == 2,"Touching same-color blocks weld at startup")
	check(PuzzlePhysics.colliders(weld).size() == 2,"Welded body has one collision shape per tile")
	var start: Vector2 = weld.global_position
	for i in 14:
		weld.try_push(1.0,1.0/60)
		await frames(1)
	await frames(14)
	check(absf(weld.position.x-start.x-16)<0.2 and absf(follower.position.x-weld.position.x-16)<0.1,"Weld slides one tile and preserves shape")
	follower.reset_home()
	check(weld.position.distance_to(start)<0.2,"Recalling any welded member recalls whole group")
	player.global_position = block.home+Vector2(-18,0)
	block.position.x += 32
	check(player.update_recall_target() == block and block.recall_available,"Extra five pixels allow recall and highlight")
	block.position.x -= 32
	player.global_position = Vector2(56,313)
	block.position.x += 32
	player.global_position = block.home
	block.reset_home()
	check(player.position.y < block.home.y-14,"Occupied block spawn places player on top")
	block.position.x += 32
	player.global_position = block.home
	var ceiling := obstruction(level,block.home+Vector2(0,-16),Vector2(16,16))
	await frames(1)
	block.reset_home()
	check(player.position.x < block.home.x-12,"Blocked top places player to the left")
	block.position.x += 32
	player.global_position = block.home
	var left := obstruction(level,block.home+Vector2(-16,0),Vector2(16,16))
	await frames(1)
	block.reset_home()
	check(player.position.x > block.home.x+12,"Blocked top and left place player to the right")
	ceiling.queue_free()
	left.queue_free()
	player.position = Vector2(56,313)
	await frames(2)
	block.position = Vector2(344,312)
	block.has_moved = true
	block.portal_locked = false
	block.check_portals()
	check(absf(block.position.x-456)<0.2,"Matching symbol teleports to nearest other portal")
	block.check_portals()
	check(absf(block.position.x-456)<0.2,"Portal lock prevents immediate return teleport")
	block.reset_home()
	var extra: Node2D = load("res://scenes/symbol_portal.tscn").instantiate()
	extra.position = Vector2(328,312)
	level.add_child(extra)
	var wrong: Node2D = load("res://scenes/symbol_portal.tscn").instantiate()
	wrong.symbol = 2
	wrong.position = Vector2(340,312)
	level.add_child(wrong)
	block.position = Vector2(344,312)
	block.has_moved = true
	block.portal_locked = false
	block.check_portals()
	check(absf(block.position.x-328)<0.2,"Portal selects nearest matching symbol and ignores closer different symbols")
	block.reset_home()
	extra.queue_free()
	wrong.queue_free()
	await frames(2)
	var blocked_destination := obstruction(level,Vector2(456,312),Vector2(16,16))
	await frames(1)
	block.position = Vector2(344,312)
	block.has_moved = true
	block.portal_locked = false
	block.check_portals()
	check(absf(block.position.x-344)<0.2,"Blocked portal destination never overlaps solid geometry")
	block.reset_home()
	blocked_destination.queue_free()
	await frames(2)
	weld.position = Vector2(344,312)
	weld.sync_members()
	weld.has_moved = true
	weld.portal_locked = false
	weld.check_portals()
	check(absf(weld.position.x-456)<0.2 and absf(follower.position.x-472)<0.2,"Teleport preserves entire welded group")
	weld.reset_home()
	var sphere: CharacterBody2D = objects.get_node("WhiteSphere")
	var origin: Vector2 = sphere.position
	await frames(12)
	check(sphere.position.distance_to(origin)<0.01,"Sphere has no gravity")
	sphere.touch(Vector2.RIGHT)
	await frames(10)
	check(sphere.charging and sphere.position.distance_to(origin)<0.01,"Sphere shakes in place for 0.2 seconds")
	var stopper := obstruction(level,origin+Vector2(70,0),Vector2(16,16))
	await frames(40)
	check(not sphere.sliding and sphere.position.x > origin.x+40 and sphere.position.x < origin.x+56,"Sphere slides until hitting a wall")
	player.position = sphere.home
	sphere.reset_home()
	check(sphere.position.distance_to(origin)<0.01 and player.position.y < origin.y-14,"Sphere recall displaces player on occupied spawn")
	var ceiling_sphere := obstruction(level,sphere.home+Vector2(0,-16),Vector2(16,16))
	var left_sphere := obstruction(level,sphere.home+Vector2(-16,0),Vector2(16,16))
	var right_sphere := obstruction(level,sphere.home+Vector2(16,0),Vector2(16,16))
	sphere.position.x += 32
	player.position = sphere.home
	await frames(1)
	var before_recall: Vector2 = sphere.position
	sphere.reset_home()
	check(sphere.position.distance_to(before_recall)<0.1,"Fully obstructed recall leaves object in place")
	ceiling_sphere.queue_free()
	left_sphere.queue_free()
	right_sphere.queue_free()
	stopper.queue_free()
	player.position = Vector2(56,313)
	sphere.position = Vector2(216,200)
	player.position = sphere.home+Vector2(-18,0)
	check(player.update_recall_target() == sphere,"Sphere can be recalled from its empty spawn")
	player.position = objects.get_node("RecallPlatformB").arrival_position()
	player.velocity = Vector2.ZERO
	await frames(5)
	player.position = Vector2(550,313)
	level.get_node("Camera").position=player.position
	level.get_node("Camera").force_update_scroll()
	await process_frame
	await process_frame
	var guide := level.get_node("PlatformGuide")
	check(guide.nearest == objects.get_node("RecallPlatformB"),"Nearest recall platform selected and glowing")
	check(guide.recall() and player.position.distance_to(guide.nearest.arrival_position())<0.1,"Platform recall places player safely on top")
	var gate := objects.get_node("Door_A")
	check(gate.get_node("CollisionShape2D").shape.size == Vector2(16,16),"Doors occupy one tile")
	check(ProjectSettings.get_setting("display/window/stretch/aspect") == "expand","Viewport fills the window without distorting pixels")
	await frames(30)
	current_scene = null
	level.queue_free()
	await process_frame
	print("NEW MECHANICS: ","PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(failures)
