extends SceneTree
## Run after capture_hue_transition.gd with a rendering driver.
func _initialize() -> void:
	var before := Image.load_from_file("res://.godot/hue-before.png")
	var after := Image.load_from_file("res://.godot/hue-after.png")
	var mask := Image.load_from_file("res://.godot/hue-mask.png")
	# The shader samples all render targets by normalized screen UV, including
	# when Windows DPI scaling gives them different backing resolutions.
	mask.resize(before.get_width(),before.get_height(),Image.INTERPOLATE_NEAREST)
	var checked := 0
	var failures := 0
	for y in mask.get_height():
		for x in mask.get_width():
			if mask.get_pixel(x,y).a<0.99: continue
			checked+=1
			var a := before.get_pixel(x,y)
			var b := after.get_pixel(x,y)
			if maxf(maxf(absf(a.r-b.r),absf(a.g-b.g)),absf(a.b-b.b))>0.08: failures+=1
	print("Exempt rendered pixels checked: ",checked,"; unexpected color changes: ",failures)
	var passed := checked>100 and failures==0
	print("HUE RENDER: ","PASS" if passed else "FAIL")
	quit(0 if passed else 1)
