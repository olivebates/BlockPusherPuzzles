extends Node

const GAME_SCENE := "res://scenes/main.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"
var root_path := "user://save_slots"
var legacy_root := "user://progress"
var names: Array[String]=["","",""]
var fresh_slots: Array[bool]=[false,false,false]
var selected := -1
var initialized_root := ""

func slot_root(index: int) -> String: return root_path+"/slot_%d"%(index+1)

func initialize() -> void:
	if initialized_root==root_path: return
	names=["","",""]
	fresh_slots=[false,false,false]
	var config := ConfigFile.new()
	config.load(root_path+"/slots.cfg")
	for i in 3:
		names[i]=str(config.get_value("slots",str(i),"")).left(32)
		fresh_slots[i]=config.get_value("fresh",str(i),false)==true
	if not config.get_value("migration","done",false):
		# Copy the old save and backups; the original files remain recoverable.
		var legacy := Progress.read_file(legacy_root+"/current.cps")
		if legacy.is_empty(): legacy=Progress.read_file(legacy_root+"/current.cps.previous")
		if not legacy.is_empty() and names[0].is_empty():
			if Progress.write_file(slot_root(0)+"/current.cps",legacy):
				names[0]="Original Save"
				for file in ["current.cps.previous"]:
					var data := Progress.read_file(legacy_root+"/"+file)
					if not data.is_empty(): Progress.write_file(slot_root(0)+"/"+file,data)
				for file in DirAccess.get_files_at(legacy_root+"/backups") if DirAccess.dir_exists_absolute(legacy_root+"/backups") else []:
					if file.ends_with(".cps"):
						var data := Progress.read_file(legacy_root+"/backups/"+file)
						if not data.is_empty(): Progress.write_file(slot_root(0)+"/backups/"+file,data)
		if not persist_names(): return
	initialized_root=root_path

func persist_names() -> bool:
	if DirAccess.make_dir_recursive_absolute(root_path)!=OK: return false
	var config := ConfigFile.new()
	for i in 3:
		config.set_value("slots",str(i),names[i])
		config.set_value("fresh",str(i),fresh_slots[i])
	config.set_value("migration","done",true)
	if config.save(root_path+"/slots.cfg")!=OK: return false
	if OS.has_feature("web"): JavaScriptBridge.force_fs_sync()
	return true

func slot_info(index: int) -> Dictionary:
	initialize()
	var data := Progress.read_file(slot_root(index)+"/current.cps")
	if data.is_empty(): data=Progress.read_file(slot_root(index)+"/current.cps.previous")
	return {"name":names[index],"occupied":not names[index].is_empty() or not data.is_empty(),"orbs":data.get("collected",[]).size()}

func create_slot(index: int, label: String) -> bool:
	initialize()
	label=label.strip_edges()
	if index<0 or index>=3 or label.is_empty() or label.length()>32 or slot_info(index).occupied: return false
	names[index]=label
	fresh_slots[index]=true
	if persist_names(): return true
	names[index]=""
	fresh_slots[index]=false
	return false

func needs_fresh_start() -> bool:
	return selected>=0 and Progress.save_root==slot_root(selected) and fresh_slots[selected]

func finish_fresh_start() -> void:
	if not needs_fresh_start(): return
	fresh_slots[selected]=false
	persist_names()

func activate(index: int) -> bool:
	if index<0 or index>=3 or not slot_info(index).occupied: return false
	selected=index
	Progress.enabled=true
	Progress.restoring=false
	Progress.level=null
	Progress.dialogues.clear()
	Progress.save_root=slot_root(index)
	Progress.save_elapsed=0
	Progress.backup_elapsed=0
	Progress.sequence=0
	Progress.backups_changed.emit()
	return true

func clear_active_name() -> void:
	if selected<0 or Progress.save_root!=slot_root(selected): return
	names[selected]=""
	persist_names()
	selected=-1

func delete_slot(index: int) -> bool:
	initialize()
	if index<0 or index>=3: return false
	if index==selected and Progress.enabled and is_instance_valid(Progress.level): return false
	var folder := slot_root(index)
	var files: Array[String]=[folder+"/current.cps",folder+"/current.cps.previous",folder+"/current.cps.tmp"]
	for file in files:
		if FileAccess.file_exists(file) and DirAccess.remove_absolute(file)!=OK: return false
	var old_name := names[index]
	names[index]=""
	if not persist_names():
		names[index]=old_name
		return false
	if selected==index: selected=-1
	return true

func return_to_menu() -> bool:
	if Progress.restoring: return false
	if Progress.enabled and is_instance_valid(Progress.level) and not Progress.save_now(): return false
	Dialogue.stop()
	Progress.enabled=false
	Progress.level=null
	get_tree().paused=false
	get_tree().change_scene_to_file(MENU_SCENE)
	return true
