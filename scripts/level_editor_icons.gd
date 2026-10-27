class_name LevelEditorIcons
extends RefCounted
const ART := preload("res://scripts/puzzle_art.gd")
static var surface: ShaderMaterial

static func surface_material() -> ShaderMaterial:
	if not surface:
		surface=ShaderMaterial.new()
		surface.shader=preload("res://shaders/surface.gdshader")
	return surface

class Visual extends Node2D:
	var kind := 0
	var hue := 0
	var on_key := false
	var exposed_edges: Array=[Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]
	var beam_from := Vector2(-6,0)
	var beam_to := Vector2(6,0)
	func _draw() -> void:
		match kind:
			0: draw_texture(preload("res://assets/wall.svg"),Vector2(-8,-8))
			1: draw_texture(preload("res://assets/playerSprite.png"),Vector2(-8,-8))
			2: LevelEditorIcons.ART.draw_block(self,PuzzlePalette.color_for(hue),on_key)
			3: LevelEditorIcons.ART.draw_pad(self,PuzzlePalette.color_for(hue))
			10,11: LevelEditorIcons.ART.draw_rotator(self,kind==10)
			5: LevelEditorIcons.ART.draw_portal(self,hue)
			7: LevelEditorIcons.ART.draw_recall_platform(self)
			8: LevelEditorIcons.ART.draw_one_way(self,Color("cccccc"))
			20: LevelEditorIcons.ART.draw_pass_through(self,exposed_edges)
			18:
				draw_line(beam_from,beam_to,Color("8adfff"),3)
				for end in [beam_from,beam_to]: draw_rect(Rect2(end-Vector2(1,6),Vector2(3,12)),Color("8adfff"))

class Outline extends Node2D:
	var paths: Array[PackedVector2Array]=[]
	var pivot := Vector2.ZERO
	var hue := 0
	func _draw() -> void:
		for path in paths: draw_polyline(path,PuzzlePalette.color_for(hue),1,false)
		WeldOutline.draw_pivot(self,pivot)

static func tile(kind: int, hue: int, background: Color, on_key := false) -> Visual:
	var visual := Visual.new()
	visual.kind=kind
	visual.hue=hue
	visual.on_key=on_key
	if kind==0:
		var walls := ShaderMaterial.new()
		walls.shader=preload("res://shaders/walls.gdshader")
		walls.set_shader_parameter("tile_color",background.darkened(0.72))
		visual.material=walls
	elif kind in [1,2,3]: visual.material=surface_material()
	return visual

static func block_group(points: Array[Vector2], hue: int, keys: Dictionary = {}) -> Node2D:
	var group := Node2D.new()
	group.set_meta("block_cells",points.size())
	group.position=points[0]
	var offsets: Array[Vector2]=[]
	var center := Vector2.ZERO
	for point in points:
		var visual := tile(2,hue,Color.BLACK,keys.get(point,-1)==hue)
		visual.position=point-group.position
		offsets.append(visual.position)
		group.add_child(visual)
		center+=visual.position
	center/=points.size()
	var outline := Outline.new()
	outline.hue=hue
	outline.paths=WeldOutline.contours(offsets)
	outline.pivot=offsets[0]
	for point in offsets:
		if point.distance_squared_to(center)<outline.pivot.distance_squared_to(center)-0.01: outline.pivot=point
	group.add_child(outline)
	return group

static func create(kind: int, hue: int, background: Color) -> Node2D:
	if kind==2:
		var points: Array[Vector2]=[Vector2.ZERO]
		return block_group(points,hue)
	return tile(kind,hue,background)

# Use the game's orthogonal, same-color welding rule without physics or groups.
static func block_components(objects: Array) -> Array[Dictionary]:
	var remaining := {}
	for item in objects:
		if item[0]==2: remaining[Vector2(item[1],item[2])]=int(item[3])
	var components: Array[Dictionary]=[]
	while not remaining.is_empty():
		var first: Vector2=remaining.keys()[0]
		var hue: int=remaining[first]
		var points: Array[Vector2]=[first]
		remaining.erase(first)
		var cursor := 0
		while cursor<points.size():
			for direction in [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]:
				var neighbor: Vector2=points[cursor]+direction*16
				if remaining.get(neighbor,-1)!=hue: continue
				remaining.erase(neighbor)
				points.append(neighbor)
			cursor+=1
		components.append({"hue":hue,"points":points})
	return components
