extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.get_node("Progress").enabled=false
	var game: Node2D=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	get_first_node_in_group("player").set_physics_process(false)
	for i in 60: await physics_frame
	root.get_node("Dialogue").stop()
	var leaders: Array=[]
	for block in get_nodes_in_group("blocks"):
		block.set_physics_process(false)
		if block.leader==block: leaders.append(block)
	var samples: Array[float]=[]
	for frame in 180:
		await physics_frame
		var start := Time.get_ticks_usec()
		for block in leaders: block._physics_process(1.0/60)
		samples.append((Time.get_ticks_usec()-start)/1000.0)
	var mean := 0.0
	for sample in samples: mean+=sample/samples.size()
	samples.sort()
	var result := {"leaders":leaders.size(),"blocks":get_nodes_in_group("blocks").size(),"frames":samples.size(),"mean_ms":mean,"p95_ms":samples[int(samples.size()*0.95)]}
	print("BLOCK BENCHMARK: "+JSON.stringify(result))
	var target := "res://.godot/blocks-"+("before" if "--before" in OS.get_cmdline_user_args() else "after")+".json"
	FileAccess.open(target,FileAccess.WRITE).store_string(JSON.stringify(result))
	current_scene=null
	game.queue_free()
	await process_frame
	quit()
