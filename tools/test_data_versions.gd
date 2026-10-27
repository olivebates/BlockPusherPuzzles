extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ")+message)
	if not value: failures+=1

# Frozen version-1 layouts, independent of the current writers.
func legacy_json(prefix: String, data: Dictionary, checksum := false) -> PackedByteArray:
	var raw := JSON.stringify(data).to_utf8_buffer()
	var bytes := prefix.to_ascii_buffer()
	bytes.resize(9)
	bytes[4]=255
	bytes.encode_u32(5,raw.size())
	if checksum: bytes.append_array(ProgressCodec.digest(bytes+raw))
	bytes.append_array(raw)
	return bytes

func run() -> void:
	root.get_node("Progress").enabled=false
	check(DataVersion.current()==int(DataVersion.manifest.data_version) and not DataVersion.release().is_empty(),"All formats use the shared version manifest")
	var save := {"v":1,"marker":"Legacy progress"}
	var old_save := legacy_json("CPS1",save,true)
	var loaded_save := ProgressCodec.decode(old_save)
	check(loaded_save.get("v")==1 and loaded_save.get("marker")==save.marker,"Existing version-1 saves remain readable")
	var encoded_save := ProgressCodec.encode(save)
	check(ProgressCodec.decode(encoded_save).v==DataVersion.current() and save.v==1,"New saves carry the current version without modifying their input")
	var raw := "CPE1:"+Marshalls.raw_to_base64(PackedByteArray([3,0,1,0,0,81,85,255,2,3,16]))
	var old_level := LevelEditorCodec.decode(raw)
	check(old_level.v==1 and old_level.objects.size()==3,"Existing packed CPE1 levels remain readable")
	var old_meta := {"n":"Legacy puzzle","a":"Fox","d":"Old description","l":raw}
	var old_code := CommunityCodec.pack("CPE2:",old_meta)
	check(LevelEditorCodec.decode(old_code).metadata.d==old_meta.d,"Existing CPE2 levels without an explicit v remain readable")
	var current_raw := LevelEditorCodec.encode(old_level)
	var current_code := CommunityCodec.level(current_raw,"Versioned puzzle","Fox","New description")
	check(current_raw.begins_with("CPE3:") and LevelEditorCodec.decode(current_raw).v==DataVersion.current(),"Packed levels carry an explicit current version")
	check(CommunityCodec.metadata(current_code).v==DataVersion.current() and LevelEditorCodec.encode(LevelEditorCodec.decode(current_code))==current_code,"Community levels carry the current version and round-trip canonically")
	check(LevelData.decode(legacy_json("CPP1",old_level))==LevelData.normalize(old_level),"Existing full CPP1 level snapshots remain readable")
	check(LevelData.decode(LevelData.encode(old_level)).v==DataVersion.current(),"New full level snapshots carry the shared version")
	var first := [[0,800,800,0,1,0,100,100,0,0,0,0],[1,2400,800,0,0,0,0,0,0,0,0],[2,4000,800,0,0,0]]
	var old_replay := {"v":1,"n":"Legacy puzzle","a":"Fox","c":"Old replay","l":old_code,"fps":60,"kinds":[1,2,3],"frames":[[0,first],[2,[]]]}
	var legacy_replay := CommunityCodec.pack("CPR1:",old_replay)
	check(ReplayTrack.decode(legacy_replay).v==1,"Existing CPR1 replays and their embedded legacy levels remain readable")
	var track := ReplayTrack.new()
	track.kinds=old_replay.kinds
	track.frames=old_replay.frames
	var replay := track.encode(current_code,"Fox","New replay")
	check(ReplayTrack.decode(replay).v==DataVersion.current(),"New replays carry the same central version as saves and levels")
	for bad_version in [0,-1,1.5,"2",true,null,DataVersion.current()+1]:
		var bad := save.duplicate(true)
		bad.v=bad_version
		check(ProgressCodec.decode(legacy_json("CPS1",bad,true)).is_empty() and ProgressCodec.encode(bad).is_empty(),"Saves reject unsupported version "+str(bad_version))
		var meta := old_meta.duplicate(true)
		meta.v=bad_version
		check(LevelEditorCodec.decode(CommunityCodec.pack("CPE2:",meta)).is_empty(),"Level envelopes reject unsupported version "+str(bad_version))
		bad=old_replay.duplicate(true)
		bad.v=bad_version
		check(ReplayTrack.decode(CommunityCodec.pack("CPR1:",bad)).is_empty(),"Replays reject unsupported version "+str(bad_version))
	var bad_raw := Marshalls.base64_to_raw(current_raw.substr(5))
	bad_raw.encode_u16(0,DataVersion.current()+1)
	check(LevelEditorCodec.decode("CPE3:"+Marshalls.raw_to_base64(bad_raw)).is_empty(),"Packed levels reject unknown future versions before loading")
	var future := old_level.duplicate(true)
	future.v=DataVersion.current()+1
	check(LevelData.decode(legacy_json("CPP1",future)).is_empty() and LevelData.encode(future).is_empty() and LevelEditorCodec.encode(future).is_empty(),"Level writers and readers refuse to silently relabel future data")
	var path := "res://.godot/version-write-test.cps"
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_buffer(old_save)
	file.close()
	future=save.duplicate(true)
	future.v=DataVersion.current()+1
	check(not root.get_node("Progress").write_file(path,future) and FileAccess.get_file_as_bytes(path)==old_save,"Rejecting an unsupported save write preserves the existing file")
	var progress := root.get_node("Progress")
	progress.save_root="res://.godot/future-version-save-%d"%Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(progress.save_root)
	var game: Node2D=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	for i in 6: await process_frame
	progress.level=game
	future=progress.snapshot()
	future.v=DataVersion.current()+1
	var future_bytes := legacy_json("CPS1",future,true)
	file=FileAccess.open(progress.save_root+"/current.cps",FileAccess.WRITE)
	file.store_buffer(future_bytes)
	file.close()
	progress.enabled=true
	await progress.bind_level(game)
	check(paused and not progress.enabled and not progress.restoring and FileAccess.get_file_as_bytes(progress.save_root+"/current.cps")==future_bytes,"Opening a future-version save blocks autosaving and preserves its bytes")
	check(not DirAccess.dir_exists_absolute(progress.save_root+"/backups"),"An unsupported save does not create replacement backups")
	paused=false
	progress.level=null
	current_scene=null
	game.queue_free()
	await process_frame
	var future_code := "CPE3:"+Marshalls.raw_to_base64(bad_raw)
	path="res://.godot/future-version-draft.cpe"
	file=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(future_code)
	file.close()
	root.get_node("SaveSlots").root_path=progress.save_root+"/slots"
	root.get_node("SaveSlots").legacy_root=progress.save_root+"/no-legacy"
	var menu: Node2D=load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene=menu
	var session := root.get_node("LevelEditorSession")
	session.draft_path=path
	session.warned=true
	session.open_menu("editor")
	for i in 6: await process_frame
	var editor := current_scene
	check(editor.incompatible_draft and paused and is_instance_valid(editor.popup) and editor.save_draft() and FileAccess.get_file_as_string(path)==future_code,"Opening and exiting a future-version draft never overwrites it with an empty puzzle")
	editor.popup.actions.get_child(0).pressed.emit()
	for i in 6: await process_frame
	check(current_scene==menu and not paused and FileAccess.get_file_as_string(path)==future_code,"Back on an unsupported draft returns to its original screen without saving")
	current_scene=null
	menu.queue_free()
	await process_frame
	var fixtures := {"level":current_code,"replay":replay,"legacy_level":old_code,"legacy_replay":legacy_replay}
	FileAccess.open("res://.godot/version-fixtures.json",FileAccess.WRITE).store_string(JSON.stringify(fixtures))
	quit(failures)
