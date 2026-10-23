extends SceneTree
var counts := {}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.get_node("Progress").enabled=false
	create_timer(20,true).timeout.connect(func(): quit(99))
	var game: Node2D=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	for i in 120: await physics_frame
	root.get_node("Juice").sound_played.connect(func(kind: String): counts[kind]=counts.get(kind,0)+1)
	var max_shake := 0.0
	for i in 300:
		await physics_frame
		max_shake=maxf(max_shake,game.get_node("Camera").trauma)
	print("IDLE SOUND COUNTS: ",counts)
	var quiet := counts.is_empty()
	print(("PASS: " if quiet else "FAIL: ")+"Settled authored level does not repeat sound effects")
	print(("PASS: " if max_shake==0 else "FAIL: ")+"Settled authored level does not continuously shake")
	current_scene=null
	game.queue_free()
	await process_frame
	quit(0 if quiet and max_shake==0 else 1)
