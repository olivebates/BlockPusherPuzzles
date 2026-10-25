extends SceneTree
## Run with a rendering driver; checks both sides of the player's silhouette.
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ")+message)
	if not value: failures+=1
func difference(a: Color, b: Color) -> float:
	return maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
func capture(sprite: Sprite2D, shown: bool) -> Image:
	sprite.visible=shown
	# Allow the separate mask viewport to synchronize visibility before drawing.
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run() -> void:
	create_timer(20,true).timeout.connect(func(): quit(99))
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(960,600) if "--integer-scale" in OS.get_cmdline_user_args() else Vector2i(1280,800)
	await process_frame
	root.get_node("Progress").enabled=false
	var game: Node2D=load("res://tools/test_world.gd").new().level()
	root.add_child(game)
	current_scene=game
	game.set_process(false)
	var camera: Camera2D=game.get_node("Camera")
	camera.set_process(false)
	camera.position=Vector2(300,230)
	camera.zoom=Vector2(2,2)
	for node in get_nodes_in_group("player")+get_nodes_in_group("blocks")+get_nodes_in_group("spheres"): node.set_physics_process(false)
	var player: CharacterBody2D=get_first_node_in_group("player")
	player.position=Vector2(200.3,230.2)
	var sprite: Sprite2D=player.visual
	# Keep source colors constant between captures so edge comparisons are exact.
	sprite.material=null
	var poses := [player.IDLE_SPRITE,player.RISING_SPRITE,player.FALLING_SPRITE]
	for pose in poses.size():
		sprite.texture=poses[pose]
		sprite.flip_h=pose==1
		sprite.rotation=0.045*(pose-1)
		sprite.scale=Vector2(0.8,1.18) if pose==1 else Vector2.ONE
		game.hue_palette.reset(0.0)
		var plain := await capture(sprite,true)
		var background := await capture(sprite,false)
		check(game.hue_exempt_view.size==plain.get_size(),"Exclusion mask matches the framebuffer at "+str(plain.get_size()))
		var screen_transform := root.get_stretch_transform()*sprite.get_global_transform_with_canvas()
		var bounds: Rect2=screen_transform*sprite.get_rect()
		var area := Rect2i(bounds.position.floor(),bounds.size.ceil()+Vector2(1,1)).grow(3).intersection(Rect2i(Vector2i.ZERO,plain.get_size()))
		game.change_theme(Color.from_hsv(0.02,1,1))
		game.theme_tween.pause()
		for blend in [0.5,1.0]:
			game.hue_palette.blend(blend)
			var shifted := await capture(sprite,true)
			var shifted_background := await capture(sprite,false)
			var player_pixels := 0
			var background_pixels := 0
			var recolored := 0
			var halo := 0
			for y in range(area.position.y,area.end.y):
				for x in range(area.position.x,area.end.x):
					if difference(plain.get_pixel(x,y),background.get_pixel(x,y))>0.015:
						player_pixels+=1
						if difference(plain.get_pixel(x,y),shifted.get_pixel(x,y))>0.015: recolored+=1
					else:
						background_pixels+=1
						if difference(shifted_background.get_pixel(x,y),shifted.get_pixel(x,y))>0.015: halo+=1
			var context := " (pose %d, blend %.1f)" % [pose,blend]
			check(player_pixels>50 and recolored==0,"Player edge pixels retain their original colors"+context)
			check(background_pixels>50 and halo==0,"Background pixels beside the player shift without a colored outline"+context)
	sprite.visible=true
	current_scene=null
	game.queue_free()
	await process_frame
	quit(failures)
