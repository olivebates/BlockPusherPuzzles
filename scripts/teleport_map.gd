extends CanvasLayer
const PANEL_COLOR := Color("26080e")
const YELLOW := Color("ffd433")
var active := false
var backdrop: ColorRect
var panel: Panel
var title: Label
var footer: Label
var view: Control
var texture: ImageTexture
var tile_bounds := Rect2i()
var platforms: Array[Node2D]=[]
var selected: Node2D
var old_pause := false
var failure := 0.0
var pulse := 0.0
var map_background := PANEL_COLOR
var map_tiles := Color("805159")
var explored := {}
var explored_bounds := Rect2i()
var last_screen := Rect2i()
func reveal_screen() -> void:
	if get_tree().paused or Progress.restoring: return
	var world := get_parent() as Node2D
	if not world or not world.get_viewport().get_camera_2d(): return
	var screen := world.get_viewport().get_visible_rect()
	var inverse := world.get_viewport().get_canvas_transform().affine_inverse()
	var area: Rect2=inverse*screen
	var first := world_tile(area.position)
	var end := world_tile(area.end-Vector2(0.001,0.001))
	var region := Rect2i(first,end-first+Vector2i.ONE)
	if region==last_screen: return
	last_screen=region
	for y in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x): explored[Vector2i(x,y)]=true
	explored_bounds=region if explored_bounds.size==Vector2i.ZERO else explored_bounds.merge(region)
func exploration_data() -> Array:
	var rows := {}
	for cell in explored:
		if not rows.has(cell.y): rows[cell.y]=[]
		rows[cell.y].append(cell.x)
	var result: Array=[]
	for y in rows:
		var xs: Array=rows[y]
		xs.sort()
		var start: int=xs[0]
		var end := start
		for x in xs.slice(1):
			if x==end+1: end=x
			else:
				result.append([y,start,end])
				start=x
				end=x
		result.append([y,start,end])
	return result
func restore_exploration(rows: Variant) -> void:
	explored.clear()
	explored_bounds=Rect2i()
	last_screen=Rect2i()
	if not rows is Array: return
	var count := 0
	for row in rows:
		if not row is Array or row.size()!=3: continue
		if not (row[0] is float or row[0] is int) or not (row[1] is float or row[1] is int) or not (row[2] is float or row[2] is int): continue
		var y := int(row[0])
		var start := int(row[1])
		var end := int(row[2])
		if end<start or end-start>4096 or count+end-start+1>4000000: continue
		count+=end-start+1
		for x in range(start,end+1): explored[Vector2i(x,y)]=true
		var region := Rect2i(start,y,end-start+1,1)
		explored_bounds=region if explored_bounds.size==Vector2i.ZERO else explored_bounds.merge(region)
func update_theme() -> void:
	var world := get_parent()
	map_background=world.background_color
	map_tiles=world.tile_color
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	style.bg_color=map_background
	style.border_color=map_tiles
class MapView extends Control:
	var map: CanvasLayer
	func _draw() -> void: map.draw_map(self)
func _ready() -> void:
	layer=90
	process_mode=Node.PROCESS_MODE_ALWAYS
	backdrop=ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color=Color(0,0,0,0.65)
	backdrop.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT: close_map())
	add_child(backdrop)
	panel=Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left=28
	panel.offset_top=20
	panel.offset_right=-28
	panel.offset_bottom=-20
	panel.mouse_filter=Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color=PANEL_COLOR
	style.border_color=YELLOW
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	title=Label.new()
	title.text="Map Teleport"
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top=9
	title.offset_bottom=35
	title.add_theme_color_override("font_color",YELLOW)
	panel.add_child(title)
	footer=Label.new()
	footer.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top=-34
	footer.offset_bottom=-8
	footer.add_theme_font_size_override("font_size",14)
	panel.add_child(footer)
	view=MapView.new()
	view.map=self
	view.mouse_filter=Control.MOUSE_FILTER_IGNORE
	view.clip_contents=true
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.offset_left=18
	view.offset_top=46
	view.offset_right=-18
	view.offset_bottom=-46
	panel.add_child(view)
	hide()
func world_tile(point: Vector2) -> Vector2i: return Vector2i(floor(point/16))
func rebuild_map() -> bool:
	reveal_screen()
	update_theme()
	var world := get_parent()
	var walls := world.get_node("Walls") as TileMapLayer
	var cells: Array[Vector2i]=[]
	for cell in walls.get_used_cells(): cells.append(world_tile(walls.to_global(walls.map_to_local(cell))))
	platforms.clear()
	for platform in get_tree().get_nodes_in_group("recall_platforms"):
		platforms.append(platform)
		cells.append(world_tile(platform.global_position))
	for group in ["doors","large_doors","collectibles","story_npcs","one_way_blocks"]:
		for node in get_tree().get_nodes_in_group(group): cells.append(world_tile(node.global_position))
	for group in ["doors","large_doors","one_way_blocks"]:
		for node in get_tree().get_nodes_in_group(group):
			for collider in PuzzlePhysics.colliders(node):
				var rect := collider.global_transform*collider.shape.get_rect()
				cells.append(world_tile(rect.position))
				cells.append(world_tile(rect.end-Vector2(0.1,0.1)))
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if cells.is_empty() and player: cells.append(world_tile(player.global_position))
	if cells.is_empty(): return false
	if explored.is_empty(): return false
	tile_bounds=explored_bounds
	if tile_bounds.size.x>4096 or tile_bounds.size.y>4096: return false
	var image := Image.create(tile_bounds.size.x,tile_bounds.size.y,false,Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	for cell in explored:
		image.set_pixelv(cell-tile_bounds.position,map_background)
	for cell in walls.get_used_cells():
		var pixel := world_tile(walls.to_global(walls.map_to_local(cell)))-tile_bounds.position
		if explored.has(pixel+tile_bounds.position): image.set_pixelv(pixel,map_tiles)
	for group in ["one_way_blocks","doors","large_doors"]:
		for node in get_tree().get_nodes_in_group(group):
			for collider in PuzzlePhysics.colliders(node):
				var rect := collider.global_transform*collider.shape.get_rect()
				var begin := world_tile(rect.position+Vector2(0.1,0.1))
				var end := world_tile(rect.end-Vector2(0.1,0.1))
				for x in range(begin.x,end.x+1):
					for y in range(begin.y,end.y+1):
						var point := Vector2i(x,y)
						if explored.has(point): image.set_pixelv(point-tile_bounds.position,Color("c2a85f") if group!="one_way_blocks" else map_tiles)
	texture=ImageTexture.create_from_image(image)
	return true
func selectable() -> Array[Node2D]:
	var result: Array[Node2D]=[]
	for platform in platforms:
		if is_instance_valid(platform) and platform.activated and explored.has(world_tile(platform.global_position)): result.append(platform)
	return result
func open_map() -> bool:
	if active or get_tree().paused or Dialogue.active or Progress.restoring: return false
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if not player or not player.rotation_locks.is_empty() or not rebuild_map(): return false
	selected=null
	var distance := INF
	for platform in selectable():
		var next: float=player.global_position.distance_squared_to(platform.global_position)
		if next<distance:
			distance=next
			selected=platform
	footer.text="WASD / Arrows — Navigate     SPACE — Teleport     %s — Close" % InputBindings.prompt("map").to_upper()
	old_pause=get_tree().paused
	active=true
	get_tree().paused=true
	Progress.map_opened=true
	show()
	view.queue_redraw()
	return true
func close_map(teleported := false) -> void:
	if not active: return
	active=false
	hide()
	if teleported:
		Progress.map_teleported=true
		Progress.map_hint_stage=3
	elif Progress.map_hint_stage==1: Progress.map_hint_stage=2
	get_tree().paused=old_pause
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player: player.queue_redraw()
func navigate(direction: Vector2) -> void:
	var options := selectable()
	if options.is_empty():
		selected=null
		return
	if not is_instance_valid(selected):
		selected=options[0]
		return
	var next: Node2D
	var best := INF
	for platform in options:
		if platform==selected: continue
		var delta: Vector2=platform.global_position-selected.global_position
		if delta.dot(direction)<=0: continue
		var score := delta.length()*(3-2*delta.normalized().dot(direction))
		if score<best:
			best=score
			next=platform
	if next: selected=next
	else: selected=options[posmod(options.find(selected)+(1 if direction.x+direction.y>0 else -1),options.size())]
	view.queue_redraw()
func teleport_selected() -> bool:
	if not active or not is_instance_valid(selected): return false
	var guide := get_parent().get_node("PlatformGuide")
	if not guide.teleport_to(selected,false):
		failure=0.4
		return false
	var player := get_tree().get_first_node_in_group("player") as Node2D
	for camera in get_tree().get_nodes_in_group("game_camera"):
		camera.global_position=player.global_position
		camera.look=Vector2.ZERO
		camera.trauma=0
		camera.offset=Vector2.ZERO
		camera.reset_smoothing()
		camera.force_update_scroll()
	close_map(true)
	if Progress.enabled and Progress.level==get_parent(): Progress.save_now()
	return true
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		if active:
			close_map()
			get_viewport().set_input_as_handled()
		elif open_map(): get_viewport().set_input_as_handled()
		return
	if not active or not event is InputEventKey or not event.pressed or event.echo: return
	var code: int=event.physical_keycode if event.physical_keycode else event.keycode
	match code:
		KEY_A,KEY_LEFT: navigate(Vector2.LEFT)
		KEY_D,KEY_RIGHT: navigate(Vector2.RIGHT)
		KEY_W,KEY_UP: navigate(Vector2.UP)
		KEY_S,KEY_DOWN: navigate(Vector2.DOWN)
		KEY_SPACE: teleport_selected()
		_: return
	get_viewport().set_input_as_handled()
func _process(delta: float) -> void:
	if not active: reveal_screen()
	if not active: return
	pulse=fmod(pulse+delta*TAU/2.4,TAU)
	if map_background!=get_parent().background_color or map_tiles!=get_parent().tile_color: rebuild_map()
	failure=maxf(0,failure-delta)
	view.queue_redraw()
func image_rect(size: Vector2) -> Rect2:
	var dimensions := Vector2(tile_bounds.size)
	var scale := minf(size.x/dimensions.x,size.y/dimensions.y)
	return Rect2((size-dimensions*scale)/2,dimensions*scale)
func marker(point: Vector2, rect: Rect2) -> Vector2:
	return rect.position+(point/16-Vector2(tile_bounds.position))*rect.size/Vector2(tile_bounds.size)
func draw_map(canvas: Control) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO,canvas.size),Color.BLACK)
	if not texture: return
	var rect := image_rect(canvas.size)
	var unit := rect.size.x/tile_bounds.size.x
	canvas.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.draw_texture_rect(texture,rect,false)
	for group in ["blocks","spheres","collectibles","elevators","phase_walls"]:
		for node in get_tree().get_nodes_in_group(group):
			if not explored.has(world_tile(node.global_position)): continue
			if group=="collectibles" and node.collected: continue
			var color := Color.WHITE if group in ["spheres","phase_walls"] else Color("ffe38b") if group in ["collectibles","elevators"] else PuzzlePalette.color_for(node.block_color)
			var point := marker(node.global_position,rect)
			if not rect.has_point(point): continue
			if group in ["blocks","elevators","phase_walls"]: canvas.draw_rect(Rect2(point-Vector2.ONE*unit/2,Vector2.ONE*unit),color,group!="phase_walls",1)
			else: canvas.draw_circle(point,unit*0.4,color)
	for platform in platforms:
		if not is_instance_valid(platform): continue
		if not explored.has(world_tile(platform.global_position)): continue
		var point := marker(platform.global_position,rect)
		canvas.draw_circle(point,3,Color("d6dce5") if platform.activated else Color("61494d"))
		var radius := 6.0+sin(pulse)*1.2
		if platform.activated and platform!=selected:
			canvas.draw_arc(point,radius,0,TAU,32,Color(0.84,0.86,0.90,0.5),1,true)
		if platform==selected:
			canvas.draw_arc(point,radius,0,TAU,32,Color("ff4444") if failure>0 else YELLOW,1,true)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		var point := marker(player.global_position,rect)
		if rect.has_point(point): canvas.draw_circle(point,2,Color("ff7767"))
