class_name LevelData
extends RefCounted
const SCENES = ["", "res://scenes/player.tscn", "res://scenes/push_block.tscn", "res://scenes/matching_pad.tscn", "res://scenes/door.tscn", "res://scenes/symbol_portal.tscn", "res://scenes/sliding_sphere.tscn", "res://scenes/recall_platform.tscn", "res://scenes/one_way_block.tscn", "res://scenes/color_trigger.tscn", "res://scenes/rotator_clockwise.tscn", "res://scenes/rotator_counterclockwise.tscn", "res://scenes/large_door.tscn", "res://scenes/collectible.tscn", "res://scenes/indicator.tscn", "res://scenes/npc_fox.tscn", "res://scenes/dialogue_trigger.tscn", "res://scenes/map_trigger.tscn", "res://scenes/lightning_emitter.tscn", "res://scenes/elevator_block.tscn", "res://scenes/phase_wall.tscn"]
const SCRIPTS = ["", "res://scripts/player.gd", "res://scripts/block.gd", "res://scripts/pad.gd", "res://scripts/door.gd", "res://scripts/symbol_portal.gd", "res://scripts/sphere.gd", "res://scripts/recall_platform.gd", "res://scripts/one_way.gd", "res://scripts/color_trigger.gd", "res://scripts/rotator.gd", "res://scripts/rotator.gd", "res://scripts/large_door.gd", "res://scripts/collectible.gd", "res://scripts/indicator.gd", "res://scripts/npc_fox.gd", "res://scripts/dialogue_trigger.gd", "res://scripts/map_trigger.gd", "res://scripts/lightning_emitter.gd", "res://scripts/elevator.gd", "res://scripts/phase_wall.gd"]
const ICONS = ["wall", "player", "block", "key", "door", "portal", "sphere", "platform", "one_way", "color_trigger", "rotator_clockwise", "rotator_counterclockwise", "large_door", "collectible", "indicator", "npc_fox", "dialogue_trigger", "map_trigger", "lightning", "elevator", "phase_wall"]
const MAX_BYTES = 16777216
static func platform_position(data: Dictionary, point: Vector2) -> Vector2:
	var floor_y := INF
	for tile in data.tiles:
		if int(tile[0])==int(floor(point.x/16)) and tile[1]*16>=point.y+2-0.01:
			floor_y = minf(floor_y,tile[1]*16)
	for item in data.objects:
		if int(item[0])==8 and absf(item[1]-point.x)<=8 and item[2]-8>=point.y+2-0.01:
			floor_y = minf(floor_y,item[2]-8)
	return Vector2(point.x,floor_y-2) if is_finite(floor_y) else point
static func capture(level: Node) -> Dictionary:
	var data := {"v":1,"grid":[60,34,16],"tiles":[],"objects":[]}
	for cell in level.get_node("Walls").get_used_cells():
		data.tiles.append([cell.x,cell.y])
		data.grid[0] = maxi(data.grid[0],cell.x+1)
		data.grid[1] = maxi(data.grid[1],cell.y+1)
	var object_root := level.get_node("Objects") as Node2D
	for node in object_root.find_children("*","Node2D",true,false):
		if node.get_script() == null: continue
		var kind := SCRIPTS.find(node.get_script().resource_path)
		if kind < 1: continue
		if kind in [10,11]: kind = 10 if node.clockwise else 11
		var point: Vector2 = object_root.to_local(node.global_position)
		if kind in [2,6,19]: point = object_root.to_local(node.home)
		if kind == 1: point = object_root.to_local(node.spawn_point)
		var entry := [kind,point.x,point.y]
		if kind in [2,3]: entry.append(node.block_color)
		if kind == 3: entry.append(node.id)
		if kind == 4: entry.append_array([node.required_colors,node.id])
		if kind == 5: entry.append(node.symbol)
		if kind == 12: entry.append(node.indicator_radius_tiles)
		if kind == 13: entry.append(node.persistent_id)
		if kind == 15: entry.append_array([node.character_name,node.dialogue_id])
		if kind == 16: entry.append_array([node.dialogue_id,node.text])
		if kind == 18: entry.append_array([node.direction,node.max_length_tiles,node.beam_color.to_html(),node.enabled])
		if kind == 19: entry.append(node.speed)
		if kind == 2: entry.append_array([node.push_delay,node.slide_duration])
		if kind == 6: entry.append_array([node.slide_speed,node.charge_time])
		if kind == 9: entry.append_array([node.hex_color,node.color.to_html(),node.background_color.to_html(),node.tile_color.to_html()])
		data.objects.append(entry)
		data.grid[0] = maxi(data.grid[0],int(ceil(point.x/16)))
		data.grid[1] = maxi(data.grid[1],int(ceil(point.y/16)))
	return data
static func valid(data: Variant, require_player := true) -> bool:
	if not data is Dictionary or data.get("v") != 1: return false
	if not data.get("grid") is Array or data.grid.size()!=3: return false
	if not data.get("tiles") is Array or data.tiles.size()>262144: return false
	if not data.get("objects") is Array or data.objects.size()>10000: return false
	for i in 3:
		if not whole(data.grid[i]): return false
	if data.grid[0]<1 or data.grid[0]>512 or data.grid[1]<1 or data.grid[1]>512 or data.grid[2]<1 or data.grid[2]>64: return false
	for cell in data.tiles:
		if not cell is Array or cell.size()!=2 or not whole(cell[0]) or not whole(cell[1]): return false
		if absf(cell[0])>8192 or absf(cell[1])>8192: return false
	var players := 0
	for item in data.objects:
		if not item is Array or item.size()<3 or not whole(item[0]): return false
		var kind := int(item[0])
		var sizes := [0,3,6,5,5,4,5,3,3,5,3,3,4,4,3,5,5,3,7,4,3]
		if kind<1 or kind>=SCENES.size(): return false
		if item.size()!=sizes[kind] and not (kind==9 and item.size()==7): return false
		if not number(item[1]) or not number(item[2]) or absf(item[1])>131072 or absf(item[2])>131072: return false
		if kind==1: players += 1
		if kind==12 and (not whole(item[3]) or item[3]<1 or item[3]>100): return false
		if kind==19 and (not number(item[3]) or item[3]<8 or item[3]>240): return false
		if kind==18:
			if not whole(item[3]) or item[3]<0 or item[3]>1: return false
			if not whole(item[4]) or item[4]<1 or item[4]>512: return false
			if not item[5] is String or not Color.html_is_valid(item[5]) or not item[6] is bool: return false
		if kind==13 and (not item[3] is String or item[3].length()>128): return false
		if kind in [15,16]:
			if not item[3] is String or not item[4] is String or item[3].length()>256 or item[4].length()>4096: return false
		if kind in [2,3,4,5]:
			if not whole(item[3]) or item[3]<0 or item[3]>(15 if kind==4 else 3): return false
		if kind in [3,4]:
			if not item[4] is String or item[4].length()>32: return false
		if kind==2 and (not number(item[4]) or not number(item[5]) or item[4]<0.01 or item[5]<0.01): return false
		if kind==6 and (not number(item[3]) or not number(item[4]) or item[3]<=0 or item[4]<0.01): return false
		if kind==9 and (not item[3] is String or item[3].length()>32 or not item[4] is String or not Color.html_is_valid(item[4])): return false
		if kind==9 and item.size()==7:
			for index in [5,6]:
				if not item[index] is String or not Color.html_is_valid(item[index]): return false
	return players==1 if require_player else players<=1
static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
static func whole(value: Variant) -> bool:
	return number(value) and float(value)==floor(float(value))
static func normalize(data: Dictionary) -> Dictionary:
	# JSON parses every number as float. Restore integer keys for grid editing,
	# otherwise [25,13] no longer matches a loaded [25.0,13.0] tile.
	var result := data.duplicate(true)
	result.v = 1
	for i in 3: result.grid[i] = int(result.grid[i])
	for tile in result.tiles:
		tile[0] = int(tile[0])
		tile[1] = int(tile[1])
	for item in result.objects:
		item[0] = int(item[0])
		item[1] = float(item[1])
		item[2] = float(item[2])
		if item[0] in [2,3,4,5,12]: item[3] = int(item[3])
		if item[0]==2:
			item[4] = float(item[4])
			item[5] = float(item[5])
		if item[0]==6:
			item[3] = float(item[3])
			item[4] = float(item[4])
		if item[0]==18:
			item[3] = int(item[3])
			item[4] = int(item[4])
		if item[0]==19: item[3]=float(item[3])
	return result
static func encode(data: Dictionary) -> PackedByteArray:
	# Compact tuple arrays, no whitespace. Compare all supported lossless codecs.
	var raw := JSON.stringify(data).to_utf8_buffer()
	var best := raw
	var mode := 255
	for codec in [FileAccess.COMPRESSION_ZSTD,FileAccess.COMPRESSION_FASTLZ,FileAccess.COMPRESSION_DEFLATE,FileAccess.COMPRESSION_GZIP]:
		var compressed := raw.compress(codec)
		if not compressed.is_empty() and compressed.size()<best.size():
			best = compressed
			mode = codec
	var result := "CPP1".to_ascii_buffer()
	result.resize(9)
	result.encode_u32(5,raw.size())
	result[4] = mode
	result.append_array(best)
	return result
static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size()<9 or bytes.slice(0,4).get_string_from_ascii()!="CPP1": return {}
	var size := bytes.decode_u32(5)
	if size<1 or size>MAX_BYTES: return {}
	var mode := int(bytes[4])
	if mode!=255 and mode not in [FileAccess.COMPRESSION_ZSTD,FileAccess.COMPRESSION_FASTLZ,FileAccess.COMPRESSION_DEFLATE,FileAccess.COMPRESSION_GZIP]: return {}
	var raw := bytes.slice(9)
	if mode!=255: raw = raw.decompress(size,mode)
	if raw.size()!=size: return {}
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	return normalize(parsed) if valid(parsed,false) else {}
static func apply(level: Node, data: Dictionary, preserve_player := false) -> bool:
	if not valid(data): return false
	var objects := level.get_node("Objects")
	level.set_meta("fall_limit",data.grid[1]*16+64)
	for child in objects.get_children():
		if not (preserve_player and child.is_in_group("player")): child.free()
	var walls: TileMapLayer = level.get_node("Walls")
	walls.clear()
	for cell in data.tiles: walls.set_cell(Vector2i(int(cell[0]),int(cell[1])),0,Vector2i.ZERO)
	# Configure all instances before adding them; welding starts deferred after all exist.
	for item in data.objects:
		var kind := int(item[0])
		if kind==1 and preserve_player: continue
		var node: Node2D = load(SCENES[kind]).instantiate()
		node.position = Vector2(item[1],item[2])
		if kind in [2,3]: node.block_color = int(item[3])
		if kind==3: node.id = item[4]
		if kind==4:
			node.required_colors = int(item[3])
			node.id = item[4]
		if kind==5: node.symbol = int(item[3])
		if kind==12: node.indicator_radius_tiles=int(item[3])
		if kind==13: node.persistent_id=item[3]
		if kind==15:
			node.character_name=item[3]
			node.dialogue_id=item[4]
		if kind==16:
			node.dialogue_id=item[3]
			node.text=item[4]
		if kind==18:
			node.direction=int(item[3])
			node.max_length_tiles=int(item[4])
			node.beam_color=Color.html(item[5])
			node.enabled=item[6]
		if kind==19: node.speed=float(item[3])
		if kind==2:
			node.push_delay = item[4]
			node.slide_duration = item[5]
		if kind==6:
			node.slide_speed = item[3]
			node.charge_time = item[4]
		if kind==9:
			node.hex_color = item[3]
			node.color = Color.html(item[4])
			if item.size()==7:
				node.background_color = Color.html(item[5])
				node.tile_color = Color.html(item[6])
		objects.add_child(node)
	for camera in level.get_tree().get_nodes_in_group("game_camera"):
		camera.player = level.get_tree().get_first_node_in_group("player")
		camera.level_bounds = Vector2(data.grid[0]*16,data.grid[1]*16)
	return true



