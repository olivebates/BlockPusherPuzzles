extends Node
signal backups_changed
var enabled := true
var level: Node2D
var dialogues := {}
var save_root := "user://progress"
var save_elapsed := 0.0
var backup_elapsed := 0.0
var sequence := 0
var restoring := false
var map_hint_stage := 0
var map_opened := false
var map_teleported := false
var shortcut_keys := {}
var delete_shortcut_latched := false
func _input(event: InputEvent) -> void:
	if OS.has_feature("web"): return
	if not event is InputEventKey: return
	var code: int=event.physical_keycode if event.physical_keycode else event.keycode
	shortcut_keys[code]=event.pressed
	var chord: bool=(event.shift_pressed or shortcut_keys.get(KEY_SHIFT,false)) and shortcut_keys.get(KEY_Z,false) and shortcut_keys.get(KEY_M,false)
	if chord and not delete_shortcut_latched:
		delete_shortcut_latched=true
		get_viewport().set_input_as_handled()
		call_deferred("delete_progress")
	elif not chord: delete_shortcut_latched=false
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
func object_key(node: Node2D) -> String:
	if "persistent_id" in node and not node.persistent_id.is_empty(): return node.persistent_id
	var point: Vector2=node.home if "home" in node else node.global_position
	return node.get_script().resource_path+":"+str(snappedf(point.x,0.01))+":"+str(snappedf(point.y,0.01))
func bind_level(world: Node2D) -> void:
	if not enabled or restoring: return
	level=world
	restoring=true
	Dialogue.stop()
	for i in 3: await get_tree().process_frame
	if not is_instance_valid(level) or level!=world:
		restoring=false
		return
	dialogues.clear()
	map_hint_stage=0
	map_opened=false
	map_teleported=false
	var saved := read_file(save_root+"/current.cps")
	if saved.is_empty(): saved=read_file(save_root+"/current.cps.previous")
	if saved.is_empty():
		for backup in list_backups():
			var candidate := read_file(backup.path)
			if not candidate.is_empty() and candidate.scene==world.scene_file_path:
				saved=candidate
				break
	if not saved.is_empty(): apply_state(saved)
	restoring=false
	var opening := snapshot()
	if not opening.is_empty(): write_backup("launch",opening)
	if not dialogues.has("opening"): Dialogue.request_once("opening",StoryLines.OPENING)
	save_now()
func _process(delta: float) -> void:
	if not enabled or restoring or not is_instance_valid(level) or level!=get_tree().current_scene: return
	save_elapsed+=delta
	backup_elapsed+=delta
	if save_elapsed>=5:
		save_elapsed=fmod(save_elapsed,5)
		save_now()
	if backup_elapsed>=600:
		backup_elapsed=fmod(backup_elapsed,600)
		write_backup("timed",snapshot())
func vector(point: Vector2) -> Array: return [point.x,point.y]
func point(value: Array) -> Vector2: return Vector2(float(value[0]),float(value[1]))
func snapshot() -> Dictionary:
	if not is_instance_valid(level): return {}
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if not player: return {}
	var data := {"v":1,"scene":level.scene_file_path,"time":Time.get_unix_time_from_system(),"player":vector(player.global_position),"dialogues":dialogues.duplicate(true),"dialogue":Dialogue.snapshot(),"blocks":[],"spheres":[],"collected":[],"indicators":[],"platforms":[],"rotators":[],"theme":[level.background_color.to_html(),level.tile_color.to_html()]}
	data.map_tutorial={"stage":map_hint_stage,"opened":map_opened,"teleported":map_teleported}
	data.ground_history=player.safety.save_history()
	data.hue_shift=level.hue_shift
	data.hue_cycling=level.hue_cycling
	data.hue_reference=2
	data.passed_doors=[]
	for door in get_tree().get_nodes_in_group("doors")+get_tree().get_nodes_in_group("large_doors"):
		if door.passed_through: data.passed_doors.append(object_key(door))
	data.elevators=[]
	for elevator in get_tree().get_nodes_in_group("elevators"):
		if elevator.leader==elevator:
			data.elevators.append({"key":object_key(elevator),"p":vector(elevator.global_position),"next":elevator.next_direction,"direction":elevator.direction,"moving":elevator.moving,"on":elevator.was_player_on,"velocity":vector(elevator.velocity)})
	var map := level.get_node_or_null("TeleportMap")
	if map: data.map_explored=map.exploration_data()
	for body in get_tree().get_nodes_in_group("blocks"):
		if body.leader!=body: continue
		var record := {"key":object_key(body),"p":vector(body.global_position),"offsets":[],"velocity":vector(body.velocity),"moved":body.has_moved,"portal":body.portal_locked,"sliding":body.sliding,"from":vector(body.slide_from),"to":vector(body.slide_to),"t":body.slide_time}
		for member in body.members: record.offsets.append([object_key(member),member.weld_offset.x,member.weld_offset.y])
		# Save a stable pre-turn configuration if a quarter turn is in flight.
		if body.rotating and is_instance_valid(body.rotation_controller):
			var controller: Node2D=body.rotation_controller
			record.p=vector(controller.source)
			record.velocity=[0,0]
			record.sliding=false
			for i in record.offsets.size():
				record.offsets[i][1]=controller.old_offsets[i].x
				record.offsets[i][2]=controller.old_offsets[i].y
		data.blocks.append(record)
	for sphere in get_tree().get_nodes_in_group("spheres"):
		data.spheres.append({"key":object_key(sphere),"p":vector(sphere.global_position),"direction":vector(sphere.direction),"sliding":sphere.sliding,"charging":sphere.charging,"charge":sphere.charge})
	for pickup in get_tree().get_nodes_in_group("collectibles"):
		if pickup.collected: data.collected.append(object_key(pickup))
	for indicator in get_tree().get_nodes_in_group("collectible_indicators"):
		if indicator.lit: data.indicators.append(object_key(indicator))
	for platform in get_tree().get_nodes_in_group("recall_platforms"):
		if platform.activated: data.platforms.append(object_key(platform))
	for rotator in get_tree().get_nodes_in_group("rotators"):
		data.rotators.append([object_key(rotator),rotator.cooldown])
	return data
func valid(data: Dictionary) -> bool:
	if not data.get("hue_cycling",false) is bool: return false
	if not data.get("passed_doors",[]) is Array: return false
	for key in data.get("passed_doors",[]):
		if not key is String: return false
	if data.get("v")!=1 or not data.get("scene","") is String: return false
	if not vector_valid(data.get("player")): return false
	if not data.get("ground_history",[]) is Array or data.get("ground_history",[]).size()>100: return false
	for point in data.get("ground_history",[]):
		if not vector_valid(point): return false
	if not data.get("elevators",[]) is Array or data.get("elevators",[]).size()>10000: return false
	for record in data.get("elevators",[]):
		if not record is Dictionary or not record.get("key") is String or not vector_valid(record.get("p")): return false
		# JSON restores numeric fields as floats, including authored +/-1 directions.
		for field in ["next","direction"]:
			if not LevelData.number(record.get(field)) or absf(float(record[field]))!=1.0: return false
		if not record.get("moving") is bool or not record.get("on") is bool or not vector_valid(record.get("velocity")): return false
	if not data.get("dialogues",{}) is Dictionary or not data.get("dialogue",{}) is Dictionary: return false
	if not data.get("map_tutorial",{}) is Dictionary: return false
	var tutorial: Dictionary=data.get("map_tutorial",{})
	if not LevelData.whole(tutorial.get("stage",0)) or tutorial.get("stage",0)<0 or tutorial.get("stage",0)>3: return false
	if not tutorial.get("opened",false) is bool or not tutorial.get("teleported",false) is bool: return false
	for field in ["blocks","spheres","collected","indicators","platforms","rotators"]:
		if not data.get(field) is Array or data[field].size()>10000: return false
	for field in ["blocks","spheres"]:
		for record in data[field]:
			if not record is Dictionary or not record.get("key") is String or not vector_valid(record.get("p")): return false
			if field=="blocks":
				if not record.get("offsets") is Array: return false
				for offset in record.offsets:
					if not offset is Array or offset.size()!=3 or not offset[0] is String or not vector_valid(offset.slice(1)): return false
	var dialogue: Dictionary=data.get("dialogue",{})
	if not dialogue.is_empty():
		if not dialogue.get("lines") is Array or dialogue.lines.is_empty() or dialogue.lines.size()>1000: return false
		for line in dialogue.lines:
			if not line is Array or line.size()!=2 or not line[0] is String or not line[1] is String: return false
	return true
func vector_valid(value: Variant) -> bool:
	return value is Array and value.size()==2 and LevelData.number(value[0]) and LevelData.number(value[1]) and absf(value[0])<1000000 and absf(value[1])<1000000
func apply_state(data: Dictionary) -> bool:
	if not is_instance_valid(level) or not valid(data) or data.scene!=level.scene_file_path: return false
	var nodes := {}
	for group in ["blocks","spheres","collectibles","collectible_indicators","recall_platforms","rotators","elevators"]:
		for node in get_tree().get_nodes_in_group(group): nodes[object_key(node)]=node
	for record in data.blocks:
		if not nodes.has(record.key): continue
		var body: CharacterBody2D=nodes[record.key]
		if body.leader!=body: continue
		if is_instance_valid(body.rotation_controller): body.rotation_controller.cancel()
		body.global_position=point(record.p)
		body.rotation=0
		for offset in record.offsets:
			if nodes.has(offset[0]) and nodes[offset[0]] in body.members: nodes[offset[0]].weld_offset=Vector2(offset[1],offset[2])
		body.rebuild_weld_shapes()
		body.resting_x=body.global_position.x
		body.velocity=point(record.get("velocity",[0,0]))
		body.sliding=record.get("sliding",false)
		body.slide_from=point(record.get("from",record.p))
		body.slide_to=point(record.get("to",record.p))
		body.slide_time=float(record.get("t",0))
		body.has_moved=record.get("moved",false)
		body.portal_locked=record.get("portal",false)
		body.supported_by_player=false
		body.grounded=false
		body.automatic_recall_wait=0
		body.recall_freeze_frames=2
		body.sync_members()
		body.force_update_transform()
	for record in data.spheres:
		if not nodes.has(record.key): continue
		var sphere: CharacterBody2D=nodes[record.key]
		sphere.global_position=point(record.p)
		sphere.direction=point(record.get("direction",[0,0]))
		sphere.sliding=record.get("sliding",false)
		sphere.charging=record.get("charging",false)
		sphere.charge=float(record.get("charge",0))
		sphere.recall_freeze_frames=2
		sphere.force_update_transform()
	for record in data.get("elevators",[]):
		if not nodes.has(record.key): continue
		var elevator: CharacterBody2D=nodes[record.key]
		if elevator.leader!=elevator: continue
		elevator.global_position=point(record.p)
		elevator.next_direction=int(record.next)
		elevator.direction=int(record.direction)
		elevator.moving=record.moving
		elevator.was_player_on=record.on
		elevator.velocity=point(record.velocity)
		elevator.sync_members()
		elevator.force_update_transform()
	for pickup in get_tree().get_nodes_in_group("collectibles"): pickup.set_collected(object_key(pickup) in data.collected)
	for indicator in get_tree().get_nodes_in_group("collectible_indicators"): indicator.lit=object_key(indicator) in data.indicators
	for door in get_tree().get_nodes_in_group("large_doors"): door.restore_state()
	for door in get_tree().get_nodes_in_group("doors")+get_tree().get_nodes_in_group("large_doors"):
		door.passed_through=object_key(door) in data.get("passed_doors",[])
		door.passage.entry_side=0
		door.passage.entered=false
	for platform in get_tree().get_nodes_in_group("recall_platforms"): platform.activated=object_key(platform) in data.platforms
	for entry in data.rotators:
		if not entry is Array or entry.size()!=2 or not nodes.has(entry[0]): continue
		var rotator: Node2D=nodes[entry[0]]
		rotator.cooldown=clampi(int(entry[1]),0,3)
		rotator.countdown=rotator.cooldown
	if data.get("theme") is Array and data.theme.size()==2:
		if level.theme_tween and level.theme_tween.is_valid(): level.theme_tween.kill()
		level.stop_hue_cycle()
		level.background_color=Color.html(data.theme[0])
		level.tile_color=Color.html(data.theme[1])
		level.hue_shift=float(data.get("hue_shift",0.0))
		# Older saves used red as the hue origin and could restore the temporary
		# gray palette. Keep object progress while adopting the teal baseline.
		if int(data.get("hue_reference",1))<2:
			level.background_color=HuePalette.DEFAULT_BACKGROUND
			level.tile_color=HuePalette.DEFAULT_TILES
			if not is_zero_approx(level.hue_shift): level.hue_shift=wrapf(level.hue_shift-HuePalette.DEFAULT_COLOR.h,-0.5,0.5)
		level.hue_palette.reset(level.hue_shift)
		if data.get("hue_cycling",false): level.start_hue_cycle()
		level.apply_theme()
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	player.global_position=point(data.player)
	player.velocity=Vector2.ZERO
	player.rotation_locks.clear()
	player.recall_freeze_frames=2
	player.safety.restore_history(data.get("ground_history",[]))
	player.force_update_transform()
	player.reset_physics_interpolation()
	dialogues=data.dialogues.duplicate(true)
	var map_state: Dictionary=data.get("map_tutorial",{})
	map_hint_stage=clampi(int(map_state.get("stage",0)),0,3)
	map_opened=map_state.get("opened",false)
	map_teleported=map_state.get("teleported",false)
	if map_teleported: map_hint_stage=3
	elif map_opened and map_hint_stage==1: map_hint_stage=2
	player.queue_redraw()
	var map := level.get_node_or_null("TeleportMap")
	if map: map.restore_exploration(data.get("map_explored",[]))
	Dialogue.restore(data.dialogue)
	for camera in get_tree().get_nodes_in_group("game_camera"):
		camera.global_position=player.global_position
		camera.reset_smoothing()
	return true
func read_file(path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if not file or file.get_length()>ProgressCodec.LIMIT: return {}
	var data := ProgressCodec.decode(file.get_buffer(file.get_length()))
	return data if valid(data) else {}
func write_file(path: String, data: Dictionary, atomic := false) -> bool:
	if data.is_empty(): return false
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir())!=OK: return false
	var target := path+".tmp" if atomic else path
	var file := FileAccess.open(target,FileAccess.WRITE)
	if not file: return false
	file.store_buffer(ProgressCodec.encode(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error!=OK: return false
	if atomic:
		if FileAccess.file_exists(path+".previous"): DirAccess.remove_absolute(path+".previous")
		if FileAccess.file_exists(path) and DirAccess.rename_absolute(path,path+".previous")!=OK: return false
		if DirAccess.rename_absolute(target,path)!=OK:
			if FileAccess.file_exists(path+".previous"): DirAccess.rename_absolute(path+".previous",path)
			return false
	if OS.has_feature("web"): JavaScriptBridge.force_fs_sync()
	return true
func save_now() -> bool:
	return write_file(save_root+"/current.cps",snapshot(),true) if enabled and is_instance_valid(level) else false
func list_backups() -> Array:
	var result: Array=[]
	if not DirAccess.dir_exists_absolute(save_root+"/backups"): return result
	for file in DirAccess.get_files_at(save_root+"/backups"):
		if not file.ends_with(".cps"): continue
		var parts := file.get_basename().split("_")
		if parts.size()!=3 or parts[0] not in ["timed","launch"]: continue
		result.append({"path":save_root+"/backups/"+file,"kind":parts[0],"time":int(parts[1])/1000.0,"name":file})
	result.sort_custom(func(a: Dictionary,b: Dictionary): return a.name>b.name if a.time==b.time else a.time>b.time)
	return result
func write_backup(kind: String, data: Dictionary) -> bool:
	sequence+=1
	var stamp := int(Time.get_unix_time_from_system()*1000)
	var path := save_root+"/backups/%s_%016d_%06d.cps" % [kind,stamp,sequence]
	if not write_file(path,data): return false
	var count := 0
	for backup in list_backups():
		if backup.kind!=kind: continue
		count+=1
		if count>(20 if kind=="timed" else 5): DirAccess.remove_absolute(backup.path)
	if OS.has_feature("web"): JavaScriptBridge.force_fs_sync()
	backups_changed.emit()
	return true
func restore_backup(path: String) -> bool:
	var allowed := false
	for backup in list_backups():
		if backup.path==path: allowed=true
	if not allowed: return false
	var data := read_file(path)
	if data.is_empty() or not is_instance_valid(level): return false
	Dialogue.stop()
	if not apply_state(data): return false
	if not dialogues.has("opening"): Dialogue.request_once("opening",StoryLines.OPENING)
	save_now()
	return true
func delete_progress(restart := true) -> void:
	Dialogue.stop()
	dialogues.clear()
	map_hint_stage=0
	map_opened=false
	map_teleported=false
	for file in ["current.cps","current.cps.previous","current.cps.tmp"]:
		if FileAccess.file_exists(save_root+"/"+file): DirAccess.remove_absolute(save_root+"/"+file)
	for backup in list_backups(): DirAccess.remove_absolute(backup.path)
	save_elapsed=0
	backup_elapsed=0
	level=null
	backups_changed.emit()
	if OS.has_feature("web"): JavaScriptBridge.force_fs_sync()
	if restart:
		get_tree().paused=false
		get_tree().change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		shortcut_keys.clear()
		delete_shortcut_latched=false
	if what in [NOTIFICATION_WM_CLOSE_REQUEST,NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		if enabled and is_instance_valid(level) and not restoring: save_now()
