extends RefCounted
## Fixed physics fixture; tests never depend on the user's edited demo level.
func instance(scene: String, parent: Node, name: String, point: Vector2) -> Node2D:
	var node: Node2D = load(scene).instantiate()
	node.name = name
	node.position = point
	parent.add_child(node)
	return node
func level() -> Node2D:
	var root := Node2D.new()
	root.name = "TestWorld"
	root.set_script(load("res://scripts/main.gd"))
	var walls := TileMapLayer.new()
	walls.name = "Walls"
	walls.tile_set = load("res://assets/walls.tres")
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/walls.gdshader")
	walls.material = material
	root.add_child(walls)
	for x in 60:
		for y in range(20,25): walls.set_cell(Vector2i(x,y),0,Vector2i.ZERO)
	var objects := Node2D.new()
	objects.name = "Objects"
	root.add_child(objects)
	instance(LevelData.SCENES[1],objects,"Player",Vector2(56,313))
	var xs := [120,248,376,600]
	for i in 4:
		var block := instance(LevelData.SCENES[2],objects,"Block_%d" % i,Vector2(xs[i],312))
		block.block_color = [0,0,1,2][i]
		var pad := instance(LevelData.SCENES[3],objects,"Pad_%d" % i,Vector2(xs[i]+48,312))
		pad.block_color = block.block_color
		pad.id = "A" if i<3 else "B"
	for i in 2:
		var block := instance(LevelData.SCENES[2],objects,"WeldedLilac%d" % i,Vector2(184+i*16,312))
		block.block_color = 3
		var door := instance(LevelData.SCENES[4],objects,"Door_A" if i==0 else "Door_B",Vector2(504 if i==0 else 712,312))
		door.required_colors = 3 if i==0 else 4
		door.id = "A" if i==0 else "B"
		instance(LevelData.SCENES[5],objects,"SquarePortalA" if i==0 else "SquarePortalB",Vector2(344 if i==0 else 456,312))
		instance(LevelData.SCENES[7],objects,"RecallPlatformA" if i==0 else "RecallPlatformB",Vector2(40 if i==0 else 568,318))
	instance(LevelData.SCENES[6],objects,"WhiteSphere",Vector2(216,280))
	var camera := Camera2D.new()
	camera.name = "Camera"
	camera.set_script(load("res://scripts/camera.gd"))
	camera.zoom = Vector2(2,2)
	root.add_child(camera)
	return root
