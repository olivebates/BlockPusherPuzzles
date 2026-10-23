extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ")+message)
	if not value: failures+=1
func frames(count: int) -> void:
	for i in count: await physics_frame
func box(parent: Node, point: Vector2, hue := 0) -> CharacterBody2D:
	var node: CharacterBody2D=load(LevelData.SCENES[2]).instantiate()
	node.position=point
	node.block_color=hue
	parent.add_child(node)
	return node
func run() -> void:
	create_timer(25,true).timeout.connect(func(): quit(99))
	var game: Node2D=load("res://tools/test_world.gd").new().level()
	root.add_child(game)
	current_scene=game
	await frames(10)
	var player: CharacterBody2D=get_first_node_in_group("player")
	var objects := game.get_node("Objects")
	var walls: TileMapLayer=game.get_node("Walls")
	var block := box(objects,Vector2(808,312))
	var weld := box(objects,Vector2(824,312))
	await frames(4)
	check(block.welded_neighbor(Vector2.RIGHT) and weld.welded_neighbor(Vector2.LEFT) and not block.welded_neighbor(Vector2.LEFT),"Welded members hide shared edges while keeping their exterior outline")
	player.position=Vector2(795,313)
	player.velocity=Vector2.ZERO
	walls.set_cell(Vector2i(50,18),0,Vector2i.ZERO)
	await frames(6)
	Input.action_press("right")
	await frames(8)
	Input.action_release("right")
	Input.action_press("jump")
	await frames(16)
	Input.action_release("jump")
	check(player.position.y<290,"Jumping against a block clears the tile above its flush side")
	player.set_physics_process(false)
	player.position=Vector2(56,313)
	walls.erase_cell(Vector2i(50,18))
	block.position.x+=48
	block.resting_x=block.position.x
	block.sync_members()
	var occupying := box(objects,block.home,1)
	await frames(3)
	var sounds: Array[String]=[]
	var juice := root.get_node("Juice")
	juice.sound_played.connect(func(kind: String): sounds.append(kind))
	check(not block.reset_home(),"An occupied welded spawn refuses recall")
	check(block.home_marker.failure_flash>0 and weld.home_marker.failure_flash>0 and block.home_marker.z_index>occupying.z_index,"All welded home markers flash a red X above the occupying block")
	check(sounds.has("reject"),"Failed manual recall plays the generated negative sound")
	occupying.queue_free()
	await frames(3)
	# No headroom at home: return the body, leaving its rider at the source.
	var single := box(objects,Vector2(904,312),2)
	await frames(3)
	single.position=Vector2(936,312)
	single.resting_x=936
	player.position=Vector2(936,296.9)
	player.force_update_transform()
	walls.set_cell(Vector2i(56,18),0,Vector2i.ZERO)
	await frames(2)
	var source := player.position
	check(single.reset_home() and single.position.distance_to(single.home)<0.2 and player.position==source,"A rider stays behind when the destination has no free tile above it")
	var platform: StaticBody2D=load(LevelData.SCENES[7]).instantiate()
	platform.position=Vector2(872,318)
	objects.add_child(platform)
	player.position=Vector2(872,240)
	walls.set_cell(Vector2i(54,12),0,Vector2i.ZERO)
	await frames(4)
	check(platform.activated,"A player high in the clear column activates the platform")
	platform.activated=false
	player.position=Vector2(872,176)
	await frames(3)
	check(not platform.activated,"A ceiling tile blocks platform activation from above it")
	var settings := game.get_node("AudioSettings")
	settings.menu.popup_centered()
	for i in 3: await process_frame
	var allowed := ["Music","Sound Effects","Backups","Delete Progresse"]
	for name in root.get_node("InputBindings").NAMES.values(): allowed.append(name)
	var labels_ok := true
	for child in settings.menu.find_children("*","Label",true,false):
		if not child.is_visible_in_tree(): continue
		if not child.text.is_empty() and child.text not in allowed: labels_ok=false
	check(labels_ok and settings.menu.title.is_empty() and not settings.menu.get_ok_button().visible,"Settings retain only volume and action labels")
	check(settings.binding_buttons.reset_block[2].text.is_empty(),"Unbound key slots are empty")
	var panel: StyleBoxFlat=settings.menu.get_theme_stylebox("panel")
	check(panel.bg_color==game.background_color and panel.border_width_left==1,"Settings use the current game background with a thin dark outline")
	settings.menu.hide()
	current_scene=null
	game.queue_free()
	await process_frame
	quit(failures)
