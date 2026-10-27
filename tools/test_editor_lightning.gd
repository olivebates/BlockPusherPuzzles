extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ")+message)
	if not value: failures+=1
func paint(editor: Node2D, kind: int, cell: Vector2i) -> void:
	editor.select_tool(kind,0)
	editor.erase=false
	editor.last_cell=Vector2i(-1,-1)
	editor.stroke_saved=false
	editor.paint_at(cell)
func run() -> void:
	root.get_node("Progress").enabled=false
	var editor: Node2D=load("res://scenes/level_editor.tscn").instantiate()
	editor.fit_grid_to_view=false
	editor.initial_level_code=LevelEditorCodec.encode({"v":DataVersion.current(),"grid":[16,10,16],"color":"005155","tiles":[],"objects":[[1,216,136]]})
	root.add_child(editor)
	current_scene=editor
	paint(editor,18,Vector2i(8,4))
	var emitter: Array=editor.data.objects[1]
	check(editor.lightning_cells(emitter)==Rect2i(0,4,16,1),"Unmounted lightning extends left and right to the editor boundaries")
	paint(editor,2,Vector2i(2,4))
	check(editor.data.objects.size()==2,"Left half of a bidirectional beam also reserves its occupied cells")
	paint(editor,0,Vector2i(3,4))
	paint(editor,0,Vector2i(12,4))
	check(editor.lightning_cells(emitter)==Rect2i(4,4,8,1),"Floor tiles trim both beam ends to the new walls")
	paint(editor,2,Vector2i(2,4))
	check(editor.data.objects.size()==3,"Objects can be placed behind a newly inserted beam wall")
	paint(editor,0,Vector2i(8,4))
	check(editor.data.objects.any(func(item): return item[0]==18) and editor.lightning_cells(emitter)==Rect2i(4,4,4,1),"Painting a wall on the emitter anchor keeps the remaining beam attached to that wall")
	editor.undo()
	emitter=editor.data.objects[1]
	check(editor.lightning_cells(emitter)==Rect2i(4,4,8,1),"Undo restores the full span and original emitter anchor")
	var code: String=LevelEditorCodec.encode(editor.data)
	check(not code.is_empty() and LevelEditorCodec.encode(LevelEditorCodec.decode(code))==code,"Adjusted wall and emitter positions round-trip through existing packed codes")
	editor.start_play()
	for i in 3: await physics_frame
	var live: Node2D=get_first_node_in_group("lightning_emitters")
	check(live.to_global(live.source_face).x==64 and live.to_global(live.end_face).x==192,"Playtest lightning uses exactly the editor's two wall boundaries")
	editor.stop_play()
	await process_frame
	editor.erase=true
	editor.last_cell=Vector2i(-1,-1)
	editor.paint_at(Vector2i(12,4))
	check(editor.data.objects.any(func(item): return item[0]==18) and editor.lightning_cells(emitter).end.x==16,"Erasing a terminal wall expands the beam without deleting its emitter")
	editor.data.tiles=[]
	editor.data.objects=[[1,216,136],[18,136,72,0,128,"8adfffff",true]]
	editor.start_play()
	for i in 3: await physics_frame
	live=get_first_node_in_group("lightning_emitters")
	check(live.to_global(live.beam_start).x<live.global_position.x and live.to_global(live.beam_end).x>live.global_position.x,"An unmounted custom emitter is bidirectional in gameplay too")
	editor.stop_play()
	current_scene=null
	editor.queue_free()
	await process_frame
	quit(failures)
