extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var audio := root.get_node("Juice")
	var controls := root.get_node("InputBindings")
	if "--write" in OS.get_cmdline_user_args():
		audio.set_volume("Music",0.24)
		audio.set_volume("SFX",0.58)
		controls.set_slot("recall_player",0,controls.key_event(KEY_E))
		controls.set_slot("recall_player",1,controls.key_event(KEY_T))
		controls.set_slot("recall_player",2,controls.key_event(KEY_Y))
		print("PASS: Saved audio volumes for next session")
		quit(0)
	else:
		var passed := is_equal_approx(audio.volumes.Music,0.24) and is_equal_approx(audio.volumes.SFX,0.58)
		passed = passed and is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))),0.58)
		passed = passed and controls.prompt("recall_player")=="E" and InputMap.action_get_events("recall_player").size()==3
		print("PASS: Audio and three keybinds restored in a separate process" if passed else "FAIL: Settings persistence")
		quit(0 if passed else 1)
