class_name ReplayTrack
extends RefCounted

const ACTIONS := ["left","right","jump","down","reset_block","recall_player"]
const FPS := 60
const MAX_IDLE_FRAMES := FPS*5
const INPUT_BITS := 0x3f3f
const MAX_FRAMES := 108000
const MAX_COMMENT_LENGTH := 40
const LENGTHS := {1:12,2:11,3:6,10:7,11:7}
var actors: Array[Node2D]=[]
var kinds: Array=[]
var frames: Array=[]
var last: Array=[]
var checkpoints: Dictionary={}
var raw_size := 0
var full := false
var next_frames := PackedInt32Array()

static func inputs() -> int:
	var bits := 0
	for i in ACTIONS.size():
		if Input.is_action_pressed(ACTIONS[i]): bits|=1<<i
		if Input.is_action_just_pressed(ACTIONS[i]): bits|=1<<(i+8)
	return bits

func bind(world: Node2D) -> void:
	actors.clear()
	kinds.clear()
	for actor in world.get_node("Objects").get_children():
		if actor.get_script()==null: continue
		var kind := LevelData.SCRIPTS.find(actor.get_script().resource_path)
		if kind not in [1,2,3,10]: continue
		if kind==10 and not actor.clockwise: kind=11
		actors.append(actor)
		kinds.append(kind)

func capture(mask: int) -> void:
	if full: return
	var changes := []
	for i in actors.size():
		var actor: Node2D=actors[i]
		var state := [i,roundi(actor.position.x*100),roundi(actor.position.y*100),roundi(actor.rotation*10000)]
		match int(kinds[i]):
			1:
				var sprite := 1 if actor.visual.texture==actor.RISING_SPRITE else 2 if actor.visual.texture==actor.FALLING_SPRITE else 0
				state.append_array([int(actor.facing),sprite,roundi(actor.visual.scale.x*100),roundi(actor.visual.scale.y*100),roundi(actor.visual.rotation*10000),roundi(minf(absf(actor.velocity.y)/210.0,1)*100),int(actor.show_recall_prompt),roundi(actor.velocity.y*100)])
			2: state.append_array([roundi(actor.weld_offset.x*100),roundi(actor.weld_offset.y*100),int(actor.on_key_tile),roundi(actor.flash*100),roundi(actor.charge*10000),int(actor.recall_available),roundi(maxf(actor.flash,actor.charge/actor.push_delay)*100)])
			3: state.append_array([int(actor.filled),roundi(actor.energy*100)])
			10,11: state.append_array([actor.cooldown,roundi(actor.countdown*100),roundi(actor.failure_flash*100)])
		if i>=last.size():
			last.append(state)
			changes.append(state)
		elif last[i]!=state:
			last[i]=state
			changes.append(state)
	var frame := [mask,changes]
	frames.append(frame)
	raw_size+=JSON.stringify(frame).length()+1
	full=frames.size()>=MAX_FRAMES or raw_size>CommunityCodec.MAX_RAW-1024*1024

func encode(level_code: String, author: String, comment: String) -> String:
	var meta := CommunityCodec.metadata(level_code)
	if meta.is_empty() or frames.size()<2 or comment.length()>MAX_COMMENT_LENGTH or author.length()>40: return ""
	return CommunityCodec.pack("CPR1:",{"v":DataVersion.current(),"n":meta.n,"a":"Anonymous" if author.strip_edges().is_empty() else author.strip_edges(),"c":comment,"l":level_code,"fps":FPS,"kinds":kinds,"frames":frames})

static func decode(code: String) -> Dictionary:
	var value := CommunityCodec.unpack("CPR1:",code)
	if not DataVersion.accepts(value) or value.get("fps")!=FPS: return {}
	for field in ["n","a","c","l"]:
		if not value.get(field) is String: return {}
	if value.n.length()>80 or value.a.length()>40 or value.c.length()>100 or value.a.strip_edges().is_empty(): return {}
	var level := LevelEditorCodec.decode(value.l)
	if level.is_empty() or not value.get("kinds") is Array or not value.get("frames") is Array: return {}
	var expected := []
	for item in level.objects:
		if int(item[0]) in [1,2,3,10,11]: expected.append(int(item[0]))
	for i in value.kinds.size():
		if not LevelData.whole(value.kinds[i]): return {}
		value.kinds[i]=int(value.kinds[i])
	if value.kinds!=expected or value.frames.size()<2 or value.frames.size()>MAX_FRAMES: return {}
	for frame_index in value.frames.size():
		var frame: Variant=value.frames[frame_index]
		if not frame is Array or frame.size()!=2 or not LevelData.whole(frame[0]) or frame[0]<0 or frame[0]>65535 or not frame[1] is Array: return {}
		var seen := {}
		for state in frame[1]:
			if not state is Array or state.is_empty() or not LevelData.whole(state[0]): return {}
			var index := int(state[0])
			if index<0 or index>=expected.size() or seen.has(index) or state.size()!=LENGTHS[expected[index]]: return {}
			seen[index]=true
			for number in state:
				if not LevelData.number(number) or absf(number)>1e9: return {}
		if frame_index==0 and seen.size()!=expected.size(): return {}
	return value

func load_recording(value: Dictionary) -> bool:
	if kinds!=value.kinds: return false
	frames=value.frames
	checkpoints.clear()
	next_frames.resize(frames.size())
	var idle_start := 0
	var state: Array=[]
	state.resize(kinds.size())
	for i in frames.size():
		next_frames[i]=mini(i+1,frames.size()-1)
		if int(frames[i][0])&INPUT_BITS!=0:
			trim_idle(idle_start,i)
			idle_start=i+1
		for change in frames[i][1]: state[int(change[0])]=change
		if i%120==0: checkpoints[i]=state.duplicate()
	trim_idle(idle_start,frames.size())
	return true

# Keep five seconds of each input-free interval, then seek directly to the
# next input. Original frames and timestamps remain available for scrubbing.
func trim_idle(start: int, end: int) -> void:
	for i in range(start+MAX_IDLE_FRAMES,end): next_frames[i]=mini(end,frames.size()-1)

func next_frame(current: int) -> int:
	return next_frames[clampi(current,0,next_frames.size()-1)]

func seek(frame_index: int) -> int:
	var target := clampi(frame_index,0,frames.size()-1)
	var start := target-target%120
	var state: Array=checkpoints[start].duplicate()
	for i in range(start+1,target+1):
		for change in frames[i][1]: state[int(change[0])]=change
	for entry in state: apply_state(entry)
	return int(frames[target][0])

func apply_state(state: Array) -> void:
	var index := int(state[0])
	var actor: Node2D=actors[index]
	actor.position=Vector2(state[1],state[2])/100
	actor.rotation=float(state[3])/10000
	match int(kinds[index]):
		1:
			actor.facing=float(state[4])
			actor.visual.flip_h=actor.facing<0
			actor.visual.texture=[actor.IDLE_SPRITE,actor.RISING_SPRITE,actor.FALLING_SPRITE][clampi(int(state[5]),0,2)]
			actor.visual.scale=Vector2(state[6],state[7])/100
			actor.visual.rotation=float(state[8])/10000
			actor.visual.material.set_shader_parameter("energy",float(state[9])/100)
			actor.show_recall_prompt=state[10]!=0
			actor.velocity.y=float(state[11])/100
		2:
			actor.weld_offset=Vector2(state[4],state[5])/100
			actor.on_key_tile=state[6]!=0
			actor.flash=float(state[7])/100
			actor.charge=float(state[8])/10000
			actor.recall_available=state[9]!=0
			actor.material.set_shader_parameter("energy",float(state[10])/100)
			if is_instance_valid(actor.outline): actor.outline.queue_redraw()
		3:
			actor.filled=state[4]!=0
			actor.energy=float(state[5])/100
			if actor.material: actor.material.set_shader_parameter("energy",actor.energy)
		10,11:
			actor.cooldown=int(state[4])
			actor.countdown=float(state[5])/100
			actor.failure_flash=float(state[6])/100
	actor.queue_redraw()
