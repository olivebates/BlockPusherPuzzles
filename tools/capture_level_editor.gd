extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	root.get_node("Progress").enabled=false
	var editor: Node2D=load("res://scenes/level_editor.tscn").instantiate()
	editor.draft_path="res://.godot/capture-no-draft.cpe"
	root.add_child(editor)
	current_scene=editor
	for i in 6: await process_frame
	editor.data={"v":1,"grid":[48,23,16],"color":"005155","tiles":[],"objects":[[1,56,264]]}
	for x in 48: editor.data.tiles.append([x,17])
	for hue in 4:
		editor.data.objects.append([2,136+hue*128,264,hue,0.2,0.15])
		editor.data.objects.append([3,184+hue*128,264,hue,"A%d"%hue])
	editor.data.objects.append([2,152,264,0,0.2,0.15])
	editor.data.objects.append([2,152,248,0,0.2,0.15])
	editor.data.objects.append([10,664,264])
	editor.data.objects.append([11,696,264])
	editor.layout()
	var mode := "editor"
	if "--play" in OS.get_cmdline_user_args() or "--spawn-outlines" in OS.get_cmdline_user_args():
		editor.toggle_play()
		mode="play"
		if "--spawn-outlines" in OS.get_cmdline_user_args():
			for i in 3: await process_frame
			for block in get_nodes_in_group("blocks"):
				block.set_physics_process(false)
				block.position.y-=48
			mode="spawn-outlines"
	elif "--export" in OS.get_cmdline_user_args():
		editor.show_export()
		mode="export"
	elif "--color" in OS.get_cmdline_user_args():
		editor.show_color_picker()
		mode="color"
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/level-editor-"+mode+".png")
	if "--animation" in OS.get_cmdline_user_args():
		var before := root.get_texture().get_image()
		await create_timer(0.45).timeout
		await RenderingServer.frame_post_draw
		var after := root.get_texture().get_image()
		var changed := 0
		for y in range(before.get_height()*86/100,before.get_height()*94/100):
			for x in range(before.get_width()/4,before.get_width()*3/4):
				if before.get_pixel(x,y)!=after.get_pixel(x,y): changed+=1
		print("ANIMATION: palette pixels changed="+str(changed))
	print("CAPTURE: "+mode+" toolbar="+str(editor.ui.get_node("Toolbar").get_rect())+" board="+str(editor.board.get_rect()))
	quit()
