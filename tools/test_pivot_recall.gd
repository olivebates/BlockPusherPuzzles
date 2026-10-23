extends SceneTree
var failures := 0
var objects: Node2D
var player: CharacterBody2D
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ")+message)
	if not value: failures+=1
func frames(count: int) -> void:
	for i in count: await physics_frame
func group(points: Array[Vector2], hue := 0) -> CharacterBody2D:
	var root_box: CharacterBody2D
	for point in points:
		var box: CharacterBody2D=load(LevelData.SCENES[2]).instantiate()
		box.position=point
		box.block_color=hue
		objects.add_child(box)
		box.set_physics_process(false)
		if not root_box: root_box=box
	return root_box
func pose(body: CharacterBody2D, point: Vector2, offsets: Array[Vector2]) -> void:
	body.global_position=point
	for i in body.members.size(): body.members[i].weld_offset=offsets[i]
	body.rebuild_weld_shapes()
	body.sync_members()
	body.force_update_transform()
func stand(point: Vector2) -> void:
	player.global_position=point
	player.velocity=Vector2.ZERO
	player.force_update_transform()
func erase(body: CharacterBody2D) -> void:
	for member in body.members.duplicate(): member.free()
func run() -> void:
	create_timer(25,true).timeout.connect(func(): quit(99))
	var game: Node2D=load("res://tools/test_world.gd").new().level()
	for child in game.get_node("Objects").get_children(): child.free()
	objects=game.get_node("Objects")
	player=load(LevelData.SCENES[1]).instantiate()
	player.position=Vector2(56,313)
	objects.add_child(player)
	root.add_child(game)
	current_scene=game
	await frames(8)
	player.set_physics_process(false)
	var turns := [0]
	var sounds: Array[String]=[]
	var juice := root.get_node("Juice")
	juice.block_pushed.connect(func(): turns[0]+=1)
	juice.sound_played.connect(func(kind: String): sounds.append(kind))
	var single := group([Vector2(120,312)])
	await frames(2)
	stand(Vector2(107,313))
	check(single.is_at_home() and not single.reset_home(),"A box at its original spawn refuses manual recall")
	check(player.update_recall_target()==null and not single.recall_available,"Home boxes are excluded from R targeting and highlighting")
	check(turns[0]==0 and sounds.is_empty(),"A refused home recall has no sound, effect, or rotator turn")
	pose(single,Vector2(152,312),[Vector2.ZERO])
	check(single.reset_home() and turns[0]==1 and not single.reset_home() and turns[0]==1,"A moved box recalls once and cannot spend more turns at spawn")
	erase(single)
	var horizontal := group([Vector2(264,312),Vector2(280,312),Vector2(296,312)])
	await frames(2)
	pose(horizontal,Vector2(600,264),[Vector2.ZERO,Vector2(0,-16),Vector2(0,-32)])
	stand(Vector2(600,217.8))
	await frames(2)
	check(SupportCarry.supports(horizontal,player),"The player is riding a rotated follower before its shapes are restored")
	check(horizontal.reset_home() and player.position.distance_to(Vector2(280,297.8))<0.1,"A rotated rider lands in the first free tile directly above the destination pivot")
	erase(horizontal)
	var vertical := group([Vector2(440,280),Vector2(440,296),Vector2(440,312)])
	await frames(2)
	pose(vertical,Vector2(600,232),[Vector2.ZERO,Vector2(-16,0),Vector2(-32,0)])
	stand(Vector2(600,217.8))
	await frames(2)
	check(vertical.reset_home() and player.position.distance_to(Vector2(440,265.8))<0.1,"Pivot search skips the object's own welded tiles and lands above its highest occupied tile")
	erase(vertical)
	for kind in ["wall","box"]:
		vertical=group([Vector2(440,280),Vector2(440,296),Vector2(440,312)])
		await frames(2)
		pose(vertical,Vector2(600,232),[Vector2.ZERO,Vector2(-16,0),Vector2(-32,0)])
		stand(Vector2(600,217.8))
		var obstruction: Node2D
		if kind=="box": obstruction=group([Vector2(440,264)],1)
		else:
			obstruction=StaticBody2D.new()
			var collider := CollisionShape2D.new()
			var shape := RectangleShape2D.new()
			shape.size=Vector2(16,16)
			collider.shape=shape
			obstruction.add_child(collider)
			obstruction.position=Vector2(440,264)
			game.add_child(obstruction)
		await frames(2)
		var source := player.position
		check(vertical.reset_home() and player.position==source,"A %s above the pivot stops the search and leaves the rider behind" % kind)
		obstruction.free()
		erase(vertical)
	var original := group([Vector2(264,312),Vector2(280,312),Vector2(296,312)])
	await frames(2)
	pose(original,Vector2(600,264),[Vector2.ZERO,Vector2(16,0),Vector2(32,0)])
	stand(Vector2(603,249.8))
	await frames(2)
	check(not original.has_rotated_pose() and original.reset_home() and player.position.distance_to(Vector2(267,297.8))<0.1,"Unrotated welded blocks preserve the existing rider offset instead of using the pivot")
	erase(original)
	var rotated_at_home := group([Vector2(440,312),Vector2(456,312),Vector2(456,296)])
	await frames(2)
	pose(rotated_at_home,rotated_at_home.home,[Vector2.ZERO,Vector2(0,16),Vector2(16,16)])
	stand(Vector2(427,313))
	check(not rotated_at_home.is_at_home() and player.update_recall_target()!=null,"A rotated shape whose leader is at spawn remains recallable until its complete pose is home")
	check(rotated_at_home.reset_home() and rotated_at_home.is_at_home(),"Recalling restores the complete original welded pose")
	current_scene=null
	game.queue_free()
	await process_frame
	quit(failures)
