class_name LevelPublisher
extends Node

const ENDPOINT := "https://uncommon-dachshund-960.convex.site/levels"
const COOLDOWN_SECONDS := 300
var endpoint := ENDPOINT
var config_path := "user://level_publishing.cfg"
var publisher_id := ""
var next_publish_at := 0
var monotonic_deadline := 0
var uploading := false
var owned_ids: Array=[]
var last_author := ""

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	load_state()

func load_state() -> void:
	var config := ConfigFile.new()
	config.load(config_path)
	publisher_id=str(config.get_value("publishing","publisher_id",""))
	if publisher_id.length()!=64 or not publisher_id.is_valid_hex_number():
		publisher_id=Crypto.new().generate_random_bytes(32).hex_encode()
	next_publish_at=int(config.get_value("publishing","next_publish_at",0))
	last_author=str(config.get_value("publishing","author",""))
	var saved: Variant=config.get_value("publishing","owned",[])
	owned_ids=saved if saved is Array else []
	if OS.has_feature("web"):
		var cookies: Variant=JavaScriptBridge.eval("JSON.stringify(document.cookie.split(';').map(s=>s.trim()).filter(s=>s.startsWith('cp_level_')).map(s=>decodeURIComponent(s.substring(s.indexOf('=')+1))))")
		var parsed: Variant=JSON.parse_string(str(cookies))
		owned_ids=parsed if parsed is Array else []
	monotonic_deadline=Time.get_ticks_msec()+clampi(next_publish_at-int(Time.get_unix_time_from_system()),0,COOLDOWN_SECONDS)*1000

func save_state() -> Error:
	var config := ConfigFile.new()
	config.set_value("publishing","publisher_id",publisher_id)
	config.set_value("publishing","next_publish_at",next_publish_at)
	config.set_value("publishing","owned",owned_ids)
	config.set_value("publishing","author",last_author)
	var error := config.save(config_path)
	if error==OK and OS.has_feature("web"): JavaScriptBridge.force_fs_sync()
	return error

func remember_owned(level_id: String) -> void:
	if not owned_ids.has(level_id): owned_ids.append(level_id)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("document.cookie='cp_level_'+encodeURIComponent(%s)+'='+encodeURIComponent(%s)+'; Path=/; Max-Age=34560000; SameSite=Lax'"%[JSON.stringify(level_id),JSON.stringify(level_id)])
	save_state()

func forget_owned(level_id: String) -> void:
	owned_ids.erase(level_id)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("document.cookie='cp_level_'+encodeURIComponent(%s)+'=; Path=/; Max-Age=0; SameSite=Lax'"%JSON.stringify(level_id))
	save_state()

func cooldown_remaining() -> int:
	var wall_time := clampi(next_publish_at-int(Time.get_unix_time_from_system()),0,COOLDOWN_SECONDS)
	var elapsed_time := maxi(0,ceili((monotonic_deadline-Time.get_ticks_msec())/1000.0))
	return maxi(wall_time,elapsed_time)

func cooldown_message() -> String:
	var remaining := cooldown_remaining()
	return "Please wait %d:%02d before publishing another puzzle."%[remaining/60,remaining%60]

func apply_cooldown(seconds: int) -> void:
	var duration := clampi(seconds,0,COOLDOWN_SECONDS)
	next_publish_at=int(Time.get_unix_time_from_system())+duration
	monotonic_deadline=Time.get_ticks_msec()+duration*1000
	save_state()

func api(path: String, method := HTTPClient.METHOD_GET, payload: Dictionary = {}) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout=25.0
	request.body_size_limit=4*1024*1024
	add_child(request)
	var body := "" if method==HTTPClient.METHOD_GET else JSON.stringify(payload)
	var error := request.request(endpoint.trim_suffix("/levels")+path,["Content-Type: application/json"],method,body)
	if error!=OK:
		request.queue_free()
		return {"error":"Couldn't connect. Please try again."}
	var response: Array=await request.request_completed
	request.queue_free()
	if response[0]!=HTTPRequest.RESULT_SUCCESS:
		return {"error":"Connection interrupted. Please try again."}
	var parser := JSON.new()
	if parser.parse(response[3].get_string_from_utf8())!=OK or not parser.data is Dictionary:
		return {"error":"Community levels are unavailable. Please try again later."}
	var parsed: Dictionary=parser.data
	parsed.status=int(response[1])
	return parsed

func publish(puzzle_name: String, author: String, level_string: String, request_id: String, description := "", level_id := "", revision := 0) -> Dictionary:
	if uploading: return {"error":"A puzzle is already being published."}
	if cooldown_remaining()>0: return {"error":cooldown_message()}
	if save_state()!=OK: return {"error":"Couldn't save publishing settings. Please try again."}
	var code := CommunityCodec.level(level_string,puzzle_name,author,description)
	if code.is_empty(): return {"error":"Invalid puzzle details."}
	uploading=true
	var result: Dictionary
	if level_id.is_empty():
		result=await api("/levels",HTTPClient.METHOD_POST,{"levelString":code,"publisherId":publisher_id,"requestId":request_id})
	else:
		result=await api("/level",HTTPClient.METHOD_PATCH,{"levelId":level_id,"publisherId":publisher_id,"levelString":code,"revision":revision,"requestId":request_id})
	uploading=false
	if result.get("ok")==true and result.get("levelId") is String:
		last_author=author
		remember_owned(result.levelId)
		apply_cooldown(int(result.get("retryAfterSeconds",300)))
		return result
	if result.get("status")==429:
		apply_cooldown(int(result.get("retryAfterSeconds",300)))
		return {"error":cooldown_message()}
	return {"error":result.get("error","Couldn't publish the puzzle. Please try again.")}

func list_levels(sort_order: String, search: String, cursor: String) -> Dictionary:
	return await api("/levels?sort=%s&search=%s&cursor=%s"%[sort_order.uri_encode(),search.uri_encode(),cursor.uri_encode()])

func get_level(level_id: String) -> Dictionary:
	return await api("/level?id="+level_id.uri_encode())

func list_replays(level_id: String, cursor: String) -> Dictionary:
	return await api("/replays?levelId=%s&cursor=%s"%[level_id.uri_encode(),cursor.uri_encode()])

func get_replay(replay_id: String) -> Dictionary:
	return await api("/replay?id="+replay_id.uri_encode())

func start_attempt(level_id: String, revision: int, run_id: String) -> Dictionary:
	if save_state()!=OK: return {"error":"Couldn't save publishing settings."}
	var payload := {"levelId":level_id,"revision":revision,"publisherId":publisher_id,"runId":run_id}
	var result := await api("/attempt",HTTPClient.METHOD_POST,payload)
	if result.has("error") and (not result.has("status") or int(result.status)>=500):
		await get_tree().create_timer(0.5,true).timeout
		result=await api("/attempt",HTTPClient.METHOD_POST,payload)
	return result

func delete_level(level_id: String) -> Dictionary:
	var result := await api("/level",HTTPClient.METHOD_DELETE,{"levelId":level_id,"publisherId":publisher_id})
	if result.get("ok",false): forget_owned(level_id)
	return result

func complete(level_id: String, revision: int, run_id: String, vote: Variant = null, replay_code := "") -> Dictionary:
	if save_state()!=OK: return {"error":"Couldn't save publishing settings."}
	var payload := {"levelId":level_id,"revision":revision,"publisherId":publisher_id,"runId":run_id}
	if vote!=null: payload.vote=vote
	if not replay_code.is_empty(): payload.replayString=replay_code
	return await api("/complete",HTTPClient.METHOD_POST,payload)
