extends SceneTree
## Rebuilds the sample level. Ordinary level editing never needs this script.
func _initialize() -> void:
	call_deferred("build")
func own(node: Node, parent: Node, root: Node) -> void:
	parent.add_child(node)
	node.owner = root
func surface() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.resource_local_to_scene = true
	mat.shader = load("res://shaders/surface.gdshader")
	return mat
func save_scene(node: Node, path: String) -> void:
	var kind := LevelData.SCENES.find(path)
	if kind>0: EditorArt.attach(node,kind)
	var packed := PackedScene.new()
	packed.pack(node)
	ResourceSaver.save(packed,path)
	node.free()
func actor_scene(path: String, script_path: String, player := false) -> void:
	var body := CharacterBody2D.new()
	body.name = "Player" if player else "PushBlock"
	body.set_script(load(script_path))
	body.collision_layer = 2 if player else 4
	body.collision_mask = 5 if player else 7
	body.floor_snap_length = 2
	var collider := CollisionShape2D.new()
	collider.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(10,14) if player else Vector2(15.8,15.8)
	collider.shape = shape
	own(collider,body,body)
	if player:
		var sprite := Sprite2D.new()
		sprite.name = "Visual"
		sprite.texture = load("res://assets/playerSprite.png")
		sprite.material = surface()
		own(sprite,body,body)
	else: body.material = surface()
	save_scene(body,path)
func build() -> void:
	actor_scene("res://scenes/player.tscn","res://scripts/player.gd",true)
	actor_scene("res://scenes/push_block.tscn","res://scripts/block.gd")
	var pad := Node2D.new()
	pad.name = "MatchingPad"
	pad.set_script(load("res://scripts/pad.gd"))
	pad.material = surface()
	pad.z_index = -1
	save_scene(pad,"res://scenes/matching_pad.tscn")
	var door := StaticBody2D.new()
	door.name = "Door"
	door.set_script(load("res://scripts/door.gd"))
	door.collision_layer = 1
	door.collision_mask = 6
	door.material = surface()
	var door_collider := CollisionShape2D.new()
	door_collider.name = "CollisionShape2D"
	var door_shape := RectangleShape2D.new()
	door_shape.size = Vector2(16,16)
	door_collider.shape = door_shape
	door_collider.position.y = 0
	own(door_collider,door,door)
	save_scene(door,"res://scenes/door.tscn")
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(16,16)
	tiles.add_physics_layer()
	tiles.set_physics_layer_collision_layer(0,1)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load("res://assets/wall.svg")
	atlas.texture_region_size = Vector2i(16,16)
	atlas.create_tile(Vector2i.ZERO)
	tiles.add_source(atlas,0)
	var data := atlas.get_tile_data(Vector2i.ZERO,0)
	data.set_collision_polygons_count(0,1)
	data.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(-8,-8),Vector2(8,-8),Vector2(8,8),Vector2(-8,8)]))
	ResourceSaver.save(tiles,"res://assets/walls.tres")
	tiles.take_over_path("res://assets/walls.tres")
	var root := Node2D.new()
	root.name = "Main"
	root.set_script(load("res://scripts/main.gd"))
	var walls := TileMapLayer.new()
	walls.name = "Walls"
	walls.tile_set = tiles
	var wall_material := ShaderMaterial.new()
	wall_material.shader = load("res://shaders/walls.gdshader")
	walls.material = wall_material
	own(walls,root,root)
	for x in 60:
		for y in range(20,25): walls.set_cell(Vector2i(x,y),0,Vector2i.ZERO)
	for y in range(4,20):
		walls.set_cell(Vector2i(0,y),0,Vector2i.ZERO)
		walls.set_cell(Vector2i(59,y),0,Vector2i.ZERO)
	# Jump practice at the far end: exactly one- and two-tile steps.
	for x in range(48,51): walls.set_cell(Vector2i(x,19),0,Vector2i.ZERO)
	for x in range(52,55):
		for y in range(18,20): walls.set_cell(Vector2i(x,y),0,Vector2i.ZERO)
	var objects := Node2D.new()
	objects.name = "Objects"
	own(objects,root,root)
	var player: Node = load("res://scenes/player.tscn").instantiate()
	player.position = Vector2(56,313)
	own(player,objects,root)
	# Two cyan pads demonstrate ALL-of-same-color requirements.
	var block_cells := [Vector2i(7,19),Vector2i(15,19),Vector2i(23,19),Vector2i(37,19)]
	var pad_cells := [Vector2i(10,19),Vector2i(18,19),Vector2i(26,19),Vector2i(40,19)]
	var hues := [0,0,1,2]
	for i in block_cells.size():
		var block: Node = load("res://scenes/push_block.tscn").instantiate()
		block.name = "Block_%d" % i
		block.position = Vector2(block_cells[i]*16)+Vector2(8,8)
		block.block_color = hues[i]
		own(block,objects,root)
		var target: Node = load("res://scenes/matching_pad.tscn").instantiate()
		target.name = "Pad_%d" % i
		target.position = Vector2(pad_cells[i]*16)+Vector2(8,8)
		target.block_color = hues[i]
		target.id = "A" if i < 3 else "B"
		own(target,objects,root)
	for i in 2:
		var gate: Node = load("res://scenes/door.tscn").instantiate()
		gate.name = "Door_A" if i == 0 else "Door_B"
		gate.position = Vector2(504 if i == 0 else 712,312)
		gate.required_colors = 3 if i == 0 else 4
		gate.id = "A" if i == 0 else "B"
		own(gate,objects,root)
	var camera := Camera2D.new()
	camera.name = "Camera"
	camera.set_script(load("res://scripts/camera.gd"))
	camera.position = Vector2(224,200)
	camera.zoom = Vector2(2,2)
	own(camera,root,root)
	load("res://tools/demo_objects.gd").new().add_examples(root)
	save_scene(root,"res://scenes/main.tscn")
	print("Generated editable level and reusable scenes.")
	quit()
