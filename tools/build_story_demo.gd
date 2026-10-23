extends SceneTree
func _initialize() -> void: call_deferred("build")
func build() -> void:
	var level := Node2D.new()
	level.name="StoryDemo"
	level.set_script(load("res://scripts/main.gd"))
	var walls := TileMapLayer.new()
	walls.name="Walls"
	walls.tile_set=load("res://assets/walls.tres")
	var material := ShaderMaterial.new()
	material.shader=load("res://shaders/walls.gdshader")
	walls.material=material
	level.add_child(walls)
	walls.owner=level
	for x in 42:
		for y in range(20,25): walls.set_cell(Vector2i(x,y),0,Vector2i.ZERO)
	var objects := Node2D.new()
	objects.name="Objects"
	level.add_child(objects)
	objects.owner=level
	var player: Node2D=load(LevelData.SCENES[1]).instantiate()
	player.name="Pip"
	player.position=Vector2(56,313)
	objects.add_child(player)
	player.owner=level
	var encounter: Node2D=load("res://scenes/large_door_encounter.tscn").instantiate()
	encounter.position=Vector2(288,312)
	level.add_child(encounter)
	encounter.owner=level
	var trigger: Node2D=load("res://scenes/dialogue_trigger.tscn").instantiate()
	trigger.position=Vector2(168,296)
	objects.add_child(trigger)
	trigger.owner=level
	var camera := Camera2D.new()
	camera.name="Camera"
	camera.set_script(load("res://scripts/camera.gd"))
	level.add_child(camera)
	camera.owner=level
	var packed := PackedScene.new()
	packed.pack(level)
	ResourceSaver.save(packed,"res://scenes/story_demo.tscn")
	level.free()
	quit()
