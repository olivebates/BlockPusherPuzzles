extends Node
var voices: Array[AudioStreamPlayer] = []
var victory_voice: AudioStreamPlayer
var victory_stream: AudioStreamWAV
var reduced_motion := false
var volumes := {"Music":0.7,"SFX":0.8}
signal sound_played(kind: String)
signal block_pushed
func _exit_tree() -> void:
	if is_instance_valid(victory_voice):
		victory_voice.stop()
		victory_voice.stream=null
	for voice in voices:
		if is_instance_valid(voice):
			voice.stop()
			voice.stream = null
func _ready() -> void:
	var config := ConfigFile.new()
	config.load("user://audio.cfg")
	for bus_name in volumes:
		if AudioServer.get_bus_index(bus_name)<0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus_name)
		volumes[bus_name] = clampf(float(config.get_value("volume",bus_name,volumes[bus_name])),0,1)
		apply_volume(bus_name)
	for i in 12:
		var voice := AudioStreamPlayer.new()
		voice.bus = "SFX"
		add_child(voice)
		voices.append(voice)
	# Completion dialogs pause gameplay; their fanfare must still be audible.
	victory_voice=AudioStreamPlayer.new()
	victory_voice.name="VictorySound"
	victory_voice.bus="SFX"
	victory_voice.process_mode=Node.PROCESS_MODE_ALWAYS
	add_child(victory_voice)
func apply_volume(bus_name: String) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_mute(index,volumes[bus_name]<=0)
	AudioServer.set_bus_volume_db(index,linear_to_db(maxf(volumes[bus_name],0.0001)))
func set_volume(bus_name: String, amount: float) -> void:
	volumes[bus_name] = clampf(amount,0,1)
	apply_volume(bus_name)
	var config := ConfigFile.new()
	for name in volumes: config.set_value("volume",name,volumes[name])
	config.save("user://audio.cfg")
	if OS.has_feature("web"): JavaScriptBridge.force_fs_sync()
func sound(kind: String, pitch := 1.0) -> void:
	if kind=="victory":
		if not victory_stream: victory_stream=make_victory_sound()
		victory_voice.stream=victory_stream
		victory_voice.play()
		sound_played.emit(kind)
		return
	var frequency := 220.0
	var duration := 0.12
	var end_frequency := 100.0
	match kind:
		"jump": frequency = 310.0; end_frequency = 620.0
		"land": frequency = 145.0; end_frequency = 48.0; duration = 0.14
		"push": frequency = 170.0; end_frequency = 85.0; duration = 0.18
		"reset": frequency = 250.0; end_frequency = 950.0; duration = 0.28
		"open": frequency = 420.0; end_frequency = 840.0; duration = 0.32
		"close": frequency = 240.0; end_frequency = 110.0; duration = 0.22
		"pad": frequency = 660.0; end_frequency = 880.0; duration = 0.16
		"reject": frequency = 190.0; end_frequency = 65.0; duration = 0.3
		"rotate": frequency = 330.0; end_frequency = 760.0; duration = 0.2
		"collect": frequency = 700.0; end_frequency = 1400.0; duration = 0.24
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.mix_rate = 22050
	var bytes := PackedByteArray()
	var count := int(duration * 22050)
	bytes.resize(count * 2)
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		phase += TAU * lerpf(frequency, end_frequency, t) * pitch / 22050.0
		var envelope := minf(t * 35.0, 1.0) * pow(1.0 - t, 2.0)
		var wave := sin(phase)+sin(phase*2)*0.18
		if kind=="reject": wave = (sin(phase)+sin(phase*1.47))*0.65*(0.3+0.7*absf(sin(t*PI*3)))
		bytes.encode_s16(i * 2, int(wave * envelope * 6500))
	stream.data = bytes
	for voice in voices:
		if not voice.playing:
			voice.stream = stream
			voice.play()
			sound_played.emit(kind)
			break

func make_victory_sound() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=22050
	stream.loop_mode=AudioStreamWAV.LOOP_DISABLED
	# C–E–G–C, ending with a soft major chord and a clean decay.
	var frequencies := [523.251,659.255,783.991,1046.502]
	var starts := [0.0,0.11,0.22,0.36]
	var lengths := [0.18,0.18,0.21,0.70]
	var count := int(1.10*stream.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(count*2)
	for i in count:
		var seconds := float(i)/stream.mix_rate
		var sample := 0.0
		for note in frequencies.size():
			var t: float=seconds-starts[note]
			if t<0 or t>=lengths[note]: continue
			var envelope := minf(t/0.008,1.0)*pow(1.0-t/lengths[note],1.4)
			var phase: float=TAU*frequencies[note]*t
			sample+=(sin(phase)+sin(phase*2)*0.12)*envelope*0.30
			if note==3:
				for harmony in [261.626,329.628,391.995]: sample+=sin(TAU*harmony*t)*envelope*0.055
		bytes.encode_s16(i*2,clampi(roundi(sample*24000),-32767,32767))
	stream.data=bytes
	return stream
func burst(point: Vector2, color: Color, amount := 10) -> void:
	if reduced_motion: return
	for i in amount:
		var particle := Polygon2D.new()
		particle.polygon = PackedVector2Array([Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)])
		particle.color = color
		particle.position = point
		var scene := get_tree().current_scene
		scene.get_meta("effects_root",scene).add_child(particle)
		var tween := particle.create_tween().set_parallel(true)
		tween.tween_property(particle,"position",point + Vector2.from_angle(randf()*TAU)*randf_range(10,32),0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle,"modulate:a",0.0,0.35)
		tween.chain().tween_callback(particle.queue_free)
func impact(strength: float, point := Vector2.INF) -> void:
	if reduced_motion or get_tree().paused: return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if point.is_finite() and player and player.global_position.distance_to(point)>128: return
	for camera in get_tree().get_nodes_in_group("game_camera"):
		if point.is_finite() and not camera.get_viewport_rect().has_point(camera.get_viewport().get_canvas_transform()*point): continue
		camera.bump(strength)
func push_sparks(point: Vector2, color: Color, direction: float) -> void:
	if reduced_motion: return
	for i in 4:
		var particle := Polygon2D.new()
		particle.polygon = PackedVector2Array([Vector2(-0.6,-0.6),Vector2(0.6,-0.6),Vector2(0.6,0.6),Vector2(-0.6,0.6)])
		particle.color = color
		particle.position = point
		var scene := get_tree().current_scene
		scene.get_meta("effects_root",scene).add_child(particle)
		# Total angular width is 25 degrees, centered on movement direction.
		var travel := Vector2(direction,0).rotated(deg_to_rad(randf_range(-12.5,12.5)))*randf_range(12,24)
		var tween := particle.create_tween().set_parallel(true)
		tween.tween_property(particle,"position",point+travel,0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle,"modulate:a",0.0,0.24)
		tween.chain().tween_callback(particle.queue_free)
