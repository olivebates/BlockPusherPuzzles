extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ")+message)
	if not value: failures+=1
func paint(editor: Node2D, kind: int, hue: int, cell: Vector2i) -> void:
	editor.select_tool(kind,hue)
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
	for x in 16: editor.data.tiles.append([x,7])
	paint(editor,3,1,Vector2i(5,6))
	var protected: Dictionary=editor.data.duplicate(true)
	for kind in [0,1,5,7,8,10,11,18,20]: paint(editor,kind,0,Vector2i(5,6))
	paint(editor,2,0,Vector2i(5,6))
	check(editor.data==protected,"Other tiles and mismatched pushable blocks cannot cover a key")
	paint(editor,7,0,Vector2i(5,2))
	check(editor.data==protected,"A Q platform cannot snap onto a key from a cell above it")
	paint(editor,2,1,Vector2i(5,6))
	check(editor.data==protected,"Even a matching pushable block cannot be placed on an outlined key")
	paint(editor,2,1,Vector2i(7,6))
	var before_key: Dictionary=editor.data.duplicate(true)
	paint(editor,3,1,Vector2i(7,6))
	check(editor.data==before_key,"Placing the key second cannot create an overlapping block and key either")
	paint(editor,7,0,Vector2i(2,2))
	var item: Array=editor.data.objects[-1]
	editor.sync_controls()
	var visual: Node2D
	for child in editor.board.content.get_children():
		if child is LevelEditorIcons.Visual and child.kind==7: visual=child
	check(visual!=null and visual.position==Vector2(40,110),"Editor Q platform sits flush on the same floor as gameplay")
	check(item[2]==40,"Snapping the Q preview preserves its authored packed layout position")
	editor.start_play()
	for i in 4: await physics_frame
	var live: Node2D=get_first_node_in_group("recall_platforms")
	check(live.position==visual.position,"Editor and playing Q platform positions match exactly")
	editor.stop_play()
	editor.erase=true
	editor.last_cell=Vector2i(-1,-1)
	editor.paint_at(Vector2i(2,6))
	check(not editor.data.objects.any(func(object): return object[0]==7),"Right clicking the visible floor-snapped platform deletes its authored instance")
	current_scene=null
	editor.queue_free()
	await process_frame
	quit(failures)
