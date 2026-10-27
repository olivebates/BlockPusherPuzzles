extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ")+message)
	if not value: failures+=1
func run() -> void:
	root.get_node("Progress").enabled=false
	var juice := root.get_node("Juice")
	juice.sound("victory")
	var stream: AudioStreamWAV=juice.victory_stream
	check(stream.get_length()>1.0 and stream.get_length()<1.2,"Generated victory jingle has a short, complete musical tail")
	var peak := 0
	for offset in range(0,stream.data.size(),2): peak=maxi(peak,absi(stream.data.decode_s16(offset)))
	check(peak>1000 and peak<32767 and stream.data.decode_s16(0)==0 and stream.data.decode_s16(stream.data.size()-2)==0,"Victory audio is audible, unclipped, and starts and ends at silence")
	check(juice.victory_voice.bus=="SFX","Victory follows the player's SFX volume and mute settings")
	for voice in juice.voices:
		voice.stream=stream
		voice.play()
	paused=true
	juice.sound("victory")
	await create_timer(0.08,true).timeout
	check(juice.victory_voice.playing and juice.victory_voice.get_playback_position()>0,"Victory remains audible with every ordinary voice busy and gameplay paused")
	check(juice.victory_stream==stream,"Subsequent victories reuse the generated audio")
	stream.save_to_wav("res://.godot/victory-preview.wav")
	paused=false
	for voice in juice.voices:
		voice.stop()
		voice.stream=null
	juice.victory_voice.stop()
	juice.victory_voice.stream=null
	await process_frame
	quit(failures)
