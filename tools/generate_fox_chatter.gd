extends SceneTree
## Reproducible, quiet voiced chirps with soft attacks and no looping.
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/audio")
	for character in ["pip","sunny"]:
		for variant in 3:
			var rate := 22050
			var duration := 0.075+variant*0.007
			var count := int(rate*duration)
			var bytes := PackedByteArray()
			bytes.resize(count*2)
			var phase := 0.0
			var rng := RandomNumberGenerator.new()
			rng.seed=2307+variant
			var air := 0.0
			for i in count:
				var t := float(i)/count
				var pitch := (385.0 if character=="pip" else 285.0)*(1+variant*0.06)
				pitch*=1+0.13*sin(t*PI)-0.12*t
				phase+=TAU*pitch/rate
				air=lerpf(air,rng.randf_range(-1,1),0.2)
				var envelope := pow(sin(PI*t),1.8)
				var wave := sin(phase)*0.72+sin(phase*2)*0.2+sin(phase*3)*0.06+air*0.025
				bytes.encode_s16(i*2,int(wave*envelope*9500))
			var stream := AudioStreamWAV.new()
			stream.format=AudioStreamWAV.FORMAT_16_BITS
			stream.mix_rate=rate
			stream.loop_mode=AudioStreamWAV.LOOP_DISABLED
			stream.data=bytes
			var path := "res://assets/audio/fox_%s_%d.wav" % [character,variant+1]
			if stream.save_to_wav(path)!=OK:
				push_error("Could not generate "+path)
				quit(1)
				return
	print("Generated six soft fox chatter sounds")
	quit()
