extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ")+message)
	if not value: failures+=1
func frames(count: int) -> void:
	for i in count: await physics_frame
func wall(parent: Node, point: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size=Vector2(16,16)
	collider.shape=shape
	body.add_child(collider)
	body.position=point
	parent.add_child(body)
	return body
func run() -> void:
	create_timer(20,true).timeout.connect(func(): quit(99))
	var game: Node2D=load("res://tools/test_world.gd").new().level()
	root.add_child(game)
	current_scene=game
	var objects := game.get_node("Objects")
	var emitter: Node2D=load(LevelData.SCENES[18]).instantiate()
	emitter.position=Vector2(200,160)
	objects.add_child(emitter)
	var right_wall := wall(game,Vector2(312,160))
	wall(game,Vector2(88,160))
	var box: CharacterBody2D=load(LevelData.SCENES[2]).instantiate()
	box.position=Vector2(256,160)
	objects.add_child(box)
	box.set_physics_process(false)
	await frames(5)
	check(emitter.hit_wall and emitter.beam_end.is_equal_approx(Vector2(100,0)),"Right-facing lightning stops at its wall-mounted receiving terminal and passes movable boxes")
	check(emitter.mounted and emitter.to_global(emitter.source_face).x==96 and emitter.to_global(emitter.end_face).x==304,"Both generators sit flush against the opposing wall faces")
	check(emitter.bolts.size()==2 and emitter.bolts[0][0]==emitter.beam_start and emitter.bolts[0][-1]==emitter.beam_end,"Both animated lightning branches connect the two terminals")
	var original: PackedVector2Array=emitter.bolts[0]
	await frames(8)
	check(emitter.bolts[0]!=original,"Lightning flickers between distinct jagged paths")
	emitter.direction=1
	await frames(2)
	check(emitter.beam_end.is_equal_approx(Vector2(-100,0)),"Left-facing lightning also stops at its receiving terminal")
	emitter.direction=0
	right_wall.free()
	await frames(2)
	check(not emitter.hit_wall and absf(emitter.beam_end.x-emitter.source_face.x-emitter.max_length_tiles*16)<0.01,"Without a wall the beam uses its exported maximum length")
	var tiles: TileMapLayer=game.get_node("Walls")
	tiles.set_cell(Vector2i(20,10),0,Vector2i.ZERO)
	emitter.position.y=168
	await frames(3)
	check(emitter.hit_wall and absf(emitter.end_face.x-120)<0.01,"TileMap walls stop lightning at the tile boundary")
	emitter.enabled=false
	await frames(2)
	check(emitter.bolts.is_empty(),"Disabling the emitter clears its beam")
	var juice := root.get_node("Juice")
	juice.reduced_motion=true
	emitter.enabled=true
	await frames(2)
	check(not emitter.bolts.is_empty(),"Re-enabling lightning also restores a visible beam in reduced-motion mode")
	juice.reduced_motion=false
	emitter.enabled=false
	emitter.direction=1
	emitter.max_length_tiles=24
	emitter.beam_color=Color("ffbb55")
	var data := LevelData.decode(LevelData.encode(LevelData.capture(game)))
	var entry: Array=[]
	for item in data.objects:
		if int(item[0])==18: entry=item
	check(entry.size()==7 and int(entry[3])==1 and int(entry[4])==24 and Color.html(entry[5])==emitter.beam_color and not entry[6],"Compressed editor saves retain lightning direction, range, color, and enabled state")
	check(LevelData.apply(game,data),"Levels containing lightning emitters load successfully")
	await frames(3)
	var restored: Node2D=get_first_node_in_group("lightning_emitters")
	check(restored.direction==1 and restored.max_length_tiles==24 and not restored.enabled,"Loaded lightning objects receive their exported properties")
	current_scene=null
	game.queue_free()
	await process_frame
	quit(failures)
