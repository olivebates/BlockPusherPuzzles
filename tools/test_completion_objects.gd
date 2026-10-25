extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ")+message)
	if not value: failures+=1
func run() -> void:
	root.get_node("Progress").enabled=false
	var game: Node2D=load("res://tools/test_world.gd").new().level()
	root.add_child(game)
	current_scene=game
	for i in 5: await physics_frame
	var player: CharacterBody2D=get_first_node_in_group("player")
	player.set_physics_process(false)
	var objects := game.get_node("Objects")
	var door: Node2D=load(LevelData.SCENES[12]).instantiate()
	objects.add_child(door)
	var collider: CollisionShape2D=door.get_node("CollisionShape2D")
	check(collider.shape.size==Vector2(32,64) and collider.position.y+collider.shape.size.y/2==8,"The large door is four tiles high and retains its floor alignment")
	var area: Node2D=load(LevelData.SCENES[21]).instantiate()
	area.position=Vector2(480,240)
	area.size=Vector2(640,320)
	objects.add_child(area)
	area.set_process(false)
	player.position=area.position
	area._process(1.0/60)
	check(area.active and area.rockets.size()==1,"Entering the celebration area launches fireworks")
	check(area.rockets[0].start.y>area.get_viewport_rect().size.y and area.rockets[0].target.y<area.get_viewport_rect().size.y,"Firework rockets launch from the bottom of the screen")
	area.explode(area.rockets[0])
	check(area.sparks.size()==40,"Firework rockets burst into colored sparks")
	player.position=Vector2(40,313)
	area.launch_wait=0
	var count: int=area.rockets.size()
	area._process(1.0/60)
	check(not area.active and area.rockets.size()==count,"Leaving the area stops new launches while existing fireworks finish")
	root.get_node("Juice").reduced_motion=true
	area._process(1.0/60)
	check(area.rockets.is_empty() and area.sparks.is_empty(),"The gentle-motion setting suppresses fireworks")
	root.get_node("Juice").reduced_motion=false
	var text: Node2D=load(LevelData.SCENES[22]).instantiate()
	text.position=Vector2(480,210)
	objects.add_child(text)
	check(text.get_node("Text").get_parsed_text()==text.DEFAULT_TEXT,"The completion text preserves the requested wording and line breaks")
	check(text.get_node("Text").text.contains("[url="+text.MESSAGE.DISCORD_URL+"]"),"The completion message includes a clickable Discord link")
	check(text.get_node("Text").text.contains("[font_size=6]"+text.MESSAGE.REQUEST) and text.get_node("Text").text.contains("[font_size=8]"+text.MESSAGE.CLOSING),"The request and closing use half-size and two-thirds-size text")
	check(text.get_node("Text").text.contains("[b][color=#ffd433][url="),"The Discord link is bold and gold")
	var authored: Node2D=load("res://scenes/main.tscn").instantiate()
	var final_text: Node2D=authored.get_node("CompletionText")
	final_text.update_text()
	check(final_text.text==text.MESSAGE.PLAIN_TEXT and final_text.get_node("Text").text.contains("[font_size=6]"+text.MESSAGE.REQUEST+"[/font_size]"),"The authored ending uses the central message and always formats the request at half font size")
	authored.free()
	check(area.z_index<player.z_index and area.z_index<text.z_index,"The dark celebration backdrop and fireworks draw behind the player and text")
	check(area.z_index+area.fireworks.z_index==2,"Fireworks stay visible above floor tiles and below the player")
	var data := LevelData.capture(game)
	var saved := LevelData.decode(LevelData.encode(data))
	check(not saved.is_empty() and saved.objects.any(func(item): return item[0]==21 and item[3]==640 and item[4]==320) and saved.objects.any(func(item): return item[0]==22 and item.size()==6),"Both completion objects survive save/load without duplicating the message")
	check(LevelData.apply(game,saved),"Saved celebration objects can be instantiated again")
	var legacy := saved.duplicate(true)
	for item in legacy.objects:
		if item[0]==22: item.insert(3,"An old message copied into a saved level")
	check(LevelData.valid(legacy) and LevelData.apply(game,legacy) and game.get_node("Objects/CompletionText").text==preload("res://scripts/ending_message.gd").PLAIN_TEXT,"Older saved levels use the central message instead of stale text copies")
	for i in 2: await process_frame
	var bar: Control=game.get_node("SupportLinks/SupportBar")
	var discord: Control=bar.get_node("Discord")
	var donate: Control=bar.get_node("Donate")
	check(bar.size.y==16 and bar.size.x==game.get_viewport_rect().size.x and bar.get_global_rect().end.y==game.get_viewport_rect().end.y,"The support bar is sixteen pixels high and fills the bottom edge")
	check(discord.size.x+donate.size.x==bar.size.x and discord.url==preload("res://scripts/ending_message.gd").DISCORD_URL and donate.url=="https://ko-fi.com/snugglefox","Discord and Donate buttons fill the bar and use the supplied links")
	var theme_before: Color=discord.background_color
	game.hue_palette.reset(0.25)
	discord._process(0)
	var game_color: Color=game.hue_palette.map_color(game.background_color)
	check(discord.background_color.is_equal_approx(game_color.darkened(0.2)) and discord.background_color!=theme_before and discord.font_color!=Color.WHITE,"Support button backgrounds and font colors follow the game palette")
	var editor: Node2D=load("res://scripts/level_editor.gd").new()
	game.add_child(editor)
	await editor.open_blank()
	editor.selected=21
	editor.paint(Vector2(200,200))
	editor.selected=22
	editor.paint(Vector2(216,200))
	check(editor.data.objects.size()==2 and editor.data.objects[0][0]==21 and editor.data.objects[1][0]==22 and LevelData.valid(editor.data,false),"The editor palette can place and save both new completion objects")
	paused=false
	current_scene=null
	game.queue_free()
	await process_frame
	quit(failures)
