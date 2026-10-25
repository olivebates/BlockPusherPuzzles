extends Node
## Browser-only autoload in an isolated test copy of the project. Never shipped in-game.
var running := false
func _ready() -> void: call_deferred("run")
func _process(_delta: float) -> void:
	if running:
		var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
		if player: player.set_physics_process(false)
func report(value: Dictionary) -> void:
	JavaScriptBridge.eval("window.__webSaveResult = "+JSON.stringify(value)+";",true)
	print("WEB SAVE TEST: ",JSON.stringify(value))
func run() -> void:
	running=true
	for i in 16: await get_tree().process_frame
	var game: Node2D=get_tree().current_scene
	var progress := get_tree().root.get_node("Progress")
	var dialogue := get_tree().root.get_node("Dialogue")
	dialogue.stop()
	var player: CharacterBody2D=get_tree().get_first_node_in_group("player")
	player.set_physics_process(false)
	if str(JavaScriptBridge.get_interface("location").search).contains("read"):
		var restored := player.global_position==Vector2(-100,-130)
		var elevator := get_tree().get_first_node_in_group("elevators")
		var door := get_tree().get_first_node_in_group("large_doors")
		report({"phase":"read","web":OS.has_feature("web"),"persistent":OS.is_userfs_persistent(),"bound":progress.level==game,"restored":restored,"elevator":elevator.next_direction==-1,"door":door.passed_through,"hue_loop":game.hue_cycling})
		progress.enabled=false
		return
	player.global_position=Vector2(-100,-130)
	var elevator := get_tree().get_first_node_in_group("elevators")
	elevator.next_direction=-1
	get_tree().get_first_node_in_group("large_doors").passed_through=true
	game.change_theme(Color.from_hsv(0.2,1,1),true)
	# Let the real five-second timer save; do not call save_now here.
	await get_tree().create_timer(6.5,true).timeout
	var saved: Dictionary=progress.read_file("user://progress/current.cps")
	report({"phase":"write","web":OS.has_feature("web"),"persistent":OS.is_userfs_persistent(),"bound":progress.level==game,"saved":not saved.is_empty() and saved.player==[-100.0,-130.0],"elevators":saved.get("elevators",[]).size()})
