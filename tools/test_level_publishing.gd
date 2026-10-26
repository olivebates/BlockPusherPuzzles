extends SceneTree

var failures := 0
var editor: Node2D

class UploadServer extends Node:
	var server := TCPServer.new()
	var port := 18961
	var peer: StreamPeerTCP
	var received := PackedByteArray()
	var requests: Array[Dictionary]=[]
	var status := 503
	var reply := {"error":"Temporarily unavailable"}
	func _ready() -> void:
		process_mode=Node.PROCESS_MODE_ALWAYS
		for candidate in range(port,port+20):
			if server.listen(candidate,"127.0.0.1")==OK:
				port=candidate
				return
		push_error("Could not listen for the upload test")
	func _process(_delta: float) -> void:
		if not peer and server.is_connection_available():
			peer=server.take_connection()
			received.clear()
		if not peer: return
		peer.poll()
		var count := peer.get_available_bytes()
		if count>0: received.append_array(peer.get_data(count)[1])
		var text := received.get_string_from_utf8()
		var end := text.find("\r\n\r\n")
		if end<0: return
		var length := 0
		for header in text.left(end).split("\r\n"):
			if header.to_lower().begins_with("content-length:"):
				length=int(header.split(":")[1].strip_edges())
		if received.size()<end+4+length: return
		requests.append(JSON.parse_string(text.substr(end+4)))
		var body := JSON.stringify(reply)
		var response := "HTTP/1.1 %d Test\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n%s"%[status,body.to_utf8_buffer().size(),body]
		peer.put_data(response.to_utf8_buffer())
		peer.disconnect_from_host()
		peer=null
	func _exit_tree() -> void:
		server.stop()

func _initialize() -> void: call_deferred("run")

func check(condition: bool, message: String) -> void:
	print(("PASS: " if condition else "FAIL: ")+message)
	if not condition: failures+=1

func unsolved_level() -> void:
	editor.stop_play()
	editor.close_popup()
	editor.invalidate_completion()
	editor.data={"v":1,"grid":[12,9,16],"color":"005155","tiles":[],"objects":[[1,24,104],[2,56,104,1,0.2,0.15],[3,56,104,0,"A"]]}
	for x in 12: editor.data.tiles.append([x,7])
	editor.background_color=Color.html(editor.data.color)
	editor.update_theme()
	editor.layout()

func solve() -> void:
	for i in 6: await physics_frame
	var block := get_first_node_in_group("blocks")
	block.block_color=0
	for i in 12: await process_frame

func run() -> void:
	create_timer(40,true).timeout.connect(func(): quit(99))
	root.get_node("Progress").enabled=false
	var config_path := "res://.godot/publishing-test.cfg"
	if FileAccess.file_exists(config_path): DirAccess.remove_absolute(config_path)
	editor=load("res://scenes/level_editor.tscn").instantiate()
	editor.draft_path="res://.godot/publishing-no-draft.cpe"
	editor.publisher_settings_path=config_path
	root.add_child(editor)
	current_scene=editor
	await process_frame
	unsolved_level()
	var toolbar: Node=editor.ui.get_node("Toolbar").get_child(0)
	check(toolbar.get_child(toolbar.get_child_count()-2).text=="Publish" and toolbar.get_child(toolbar.get_child_count()-1).text=="Exit","Publish sits immediately left of Exit")
	editor.request_publish()
	check(paused and editor.popup.rows.get_child(0).text=="You must complete the puzzle before publishing","Unverified publishing shows the completion requirement")
	check(editor.popup.actions.get_child(0).text=="Okay","Completion requirement offers Okay")
	editor.popup.actions.get_child(0).pressed.emit()
	check(editor.playing and editor.publishing_test and not paused,"Okay starts a publishing test")
	check(editor.publish_hint.visible and editor.publish_hint.text=="You must complete the puzzle before publishing." and editor.publish_hint.horizontal_alignment==HORIZONTAL_ALIGNMENT_LEFT,"Publishing test displays the bottom-left instruction")
	await solve()
	check(not editor.playing and paused and is_instance_valid(editor.upload_name),"Winning the required test opens the upload prompt automatically")
	check(editor.popup.actions.get_child(0).text=="Back" and editor.popup.actions.get_child(1).text=="Publish","Upload prompt offers Back and Publish")
	check(editor.popup.rows.get_child(1).get_child(0).text=="Puzzle Name" and editor.popup.rows.get_child(2).get_child(0).text=="Author","Upload prompt labels both text fields")
	check(editor.upload_description.max_length==100,"Publish prompt limits the description to 100 characters")
	check(not editor.publish_hint.visible,"Completion hides the publishing-test reminder")
	var verified: String=editor.verified_level_code
	check(not verified.is_empty() and verified==LevelEditorCodec.encode(editor.data),"Win verifies the authored draft rather than simulated block positions")
	editor.close_popup()
	editor.request_publish()
	check(editor.popup.rows.get_child(0).text=="Publish puzzle","An unchanged verified level skips the required test")
	editor.close_popup()
	# Undoing a real edit still requires a new win, even if it restores the same code.
	editor.select_tool(0,0)
	editor.stroke_saved=false
	editor.paint_cell(Vector2i(8,3))
	editor.undo()
	check(editor.verified_level_code.is_empty() and LevelEditorCodec.encode(editor.data)==verified,"Edit followed by undo invalidates the previous completion")
	editor.toggle_play()
	await solve()
	check(editor.popup.rows.get_child(0).text=="Good job!\n\n You beat the level!","Ordinary playtest wins retain the victory message")
	editor.close_popup()
	editor.request_publish()
	check(editor.popup.rows.get_child(0).text=="Publish puzzle","Ordinary playtest wins also qualify for publishing")
	editor.upload_level()
	check(editor.upload_error.text=="Enter a Puzzle Name and Author." and not editor.publisher.uploading,"Empty metadata is rejected without starting an upload")
	editor.close_popup()
	# Opening a picker without changing the color preserves verification.
	editor.show_color_picker()
	editor.close_popup()
	check(not editor.verified_level_code.is_empty(),"Opening the color picker alone does not invalidate a win")
	editor.show_color_picker()
	editor.popup.rows.get_child(1).color_changed.emit(Color.RED)
	editor.close_popup()
	check(editor.verified_level_code.is_empty(),"Changing the level color requires completing the puzzle again")
	# Starting publish during an existing test keeps that run and sets its intent.
	unsolved_level()
	editor.toggle_play()
	var running_world: Node2D=editor.world
	editor.request_publish()
	editor.begin_publish_test()
	check(editor.world==running_world and editor.publishing_test,"Publishing during a test continues the existing run")
	editor.stop_play()
	check(not editor.publishing_test and not editor.publish_hint.visible,"Returning to editing cancels the pending upload prompt")
	unsolved_level()
	editor.request_publish()
	editor.begin_publish_test()
	await solve()
	var fixture := UploadServer.new()
	root.add_child(fixture)
	editor.publisher.endpoint="http://127.0.0.1:%d/levels"%fixture.port
	editor.upload_name.text="  Test puzzle  "
	editor.upload_author.text="  Test author  "
	editor.upload_description.text="Push every block onto a matching key."
	var encoded := LevelEditorCodec.encode(editor.data)
	editor.upload_level()
	check(editor.upload_button.disabled and editor.upload_back.disabled and not editor.upload_name.editable,"Upload disables form changes and duplicate clicks while in flight")
	for i in 120:
		await process_frame
		if not editor.publisher.uploading: break
	check(not editor.publisher.uploading and not editor.upload_error.text.is_empty() and not editor.upload_button.disabled,"Failed upload keeps the form open and supports retry")
	check(editor.publisher.cooldown_remaining()==0,"Failed upload does not start a cooldown")
	var request_id: String=editor.upload_request_id
	fixture.status=201
	fixture.reply={"ok":true,"levelId":"test-level","retryAfterSeconds":300}
	editor.upload_level()
	for i in 120:
		await process_frame
		if not editor.publisher.uploading: break
	check(editor.popup.rows.get_child(0).text=="Puzzle published!","Successful upload confirms publication")
	var uploaded := CommunityCodec.metadata(fixture.requests[1].levelString)
	check(fixture.requests.size()==2 and uploaded.l==encoded and uploaded.n=="Test puzzle" and uploaded.a=="Test author" and uploaded.d=="Push every block onto a matching key.","HTTP upload embeds the authored level, name, author, and description inside its compressed string")
	check(fixture.requests[0].requestId==request_id and fixture.requests[1].requestId==request_id,"Retry reuses its upload ID to prevent duplicate levels")
	check(editor.publisher.cooldown_remaining() in [299,300],"Success starts the five-minute cooldown")
	editor.close_popup()
	editor.request_publish()
	check(editor.popup.rows.get_child(0).text.begins_with("Please wait "),"Publish explains the remaining cooldown")
	var reopened := LevelPublisher.new()
	reopened.config_path=config_path
	root.add_child(reopened)
	check(reopened.publisher_id==editor.publisher.publisher_id and reopened.cooldown_remaining() in [299,300],"Identity and cooldown survive creating a new publisher")
	# Server rejection restores the cooldown when local state is stale.
	editor.publisher.apply_cooldown(0)
	fixture.status=429
	fixture.reply={"retryAfterSeconds":123}
	var blocked: Dictionary=await editor.publisher.publish("Another","Author",encoded,"c".repeat(32))
	check(not blocked.get("ok",false) and editor.publisher.cooldown_remaining() in [122,123],"Server cooldown is honored by the client")
	editor.close_popup()
	editor.publisher.apply_cooldown(2)
	editor.request_publish()
	var initial_message: String=editor.popup.rows.get_child(0).text
	await create_timer(1.1,true).timeout
	check(editor.popup.rows.get_child(0).text!=initial_message,"Cooldown message counts down while the game is paused")
	await create_timer(1.2,true).timeout
	check(editor.popup.rows.get_child(0).text=="You can publish now.","Cooldown message updates when publishing becomes available")
	editor.close_popup()
	editor.show_upload_prompt()
	editor.publisher.apply_cooldown(2)
	await create_timer(0.3,true).timeout
	check(editor.upload_button.disabled and editor.upload_button.text.begins_with("Publish (0:"),"Publish form displays a ticking cooldown and disables early uploads")
	await create_timer(2.1,true).timeout
	check(not editor.upload_button.disabled and editor.upload_button.text=="Publish","Publish form re-enables itself when the cooldown expires")
	reopened.queue_free()
	editor.close_popup()
	current_scene=null
	editor.queue_free()
	fixture.queue_free()
	await process_frame
	DirAccess.remove_absolute(config_path)
	# Let the dummy audio backend release any sounds still playing at teardown.
	for voice in root.get_node("Juice").voices:
		voice.stop()
		voice.stream=null
	await create_timer(0.1,true).timeout
	quit(failures)
