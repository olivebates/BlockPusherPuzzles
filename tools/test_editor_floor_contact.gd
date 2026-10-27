extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ")+message)
	if not value: failures+=1
func run() -> void:
	root.get_node("Progress").enabled=false
	var editor: Node2D=load("res://scenes/level_editor.tscn").instantiate()
	editor.fit_grid_to_view=false
	editor.initial_level_code=LevelEditorCodec.encode({"v":DataVersion.current(),"grid":[16,10,16],"color":"005155","tiles":[],"objects":[[1,216,88]]})
	root.add_child(editor)
	current_scene=editor
	for attempt in 3:
		editor.data.tiles=[]
		for x in 16: editor.data.tiles.append([x,7])
		editor.data.objects=[[1,216,88],[2,40,104,0,0.2,0.15],[2,72,104,1,0.2,0.15],[2,88,104,1,0.2,0.15]]
		editor.start_play()
		var block: CharacterBody2D=editor.world.get_node("Objects").get_child(1)
		check(BlockFall.floor_distance(block,1)==0,"Editor floor exists before physics quadrants synchronize (play %d)"%attempt)
		block._physics_process(1.0/60)
		check(absf(block.position.y-104)<0.001 and block.grounded,"First editor physics step keeps a floor-resting block above the floor")
		for i in 5: await physics_frame
		var welded: CharacterBody2D=editor.world.get_node("Objects").get_child(2).leader
		check(welded.members.size()==2 and absf(welded.position.y-104)<0.001,"Welded editor blocks also settle at exact floor height")
		block.try_push(1,block.push_delay)
		for i in 15: await physics_frame
		check(absf(block.position.x-56)<0.001 and absf(block.position.y-104)<0.001,"Editor block pushes immediately without an R recall")
		editor.stop_play()
		await process_frame
	current_scene=null
	editor.queue_free()
	await process_frame
	quit(failures)
