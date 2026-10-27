class_name CommunityCodec
extends RefCounted

const MAX_RAW := 32*1024*1024
const MAX_CODE := 900000

# Levels and replays share a size-prefixed, gzip-compressed JSON envelope.
# Gzip is supported by Godot and the Convex runtime's small JS decoder.
static func pack(prefix: String, value: Dictionary) -> String:
	var raw := JSON.stringify(value).to_utf8_buffer()
	if raw.size()>MAX_RAW: return ""
	var compressed := raw.compress(FileAccess.COMPRESSION_GZIP)
	var bytes := PackedByteArray()
	bytes.resize(5)
	bytes[0]=3 if compressed.size()<raw.size() else 255
	bytes.encode_u32(1,raw.size())
	bytes.append_array(compressed if bytes[0]==3 else raw)
	var code := prefix+Marshalls.raw_to_base64(bytes)
	return code if code.length()<=MAX_CODE else ""

static func unpack(prefix: String, code: String) -> Dictionary:
	if not code.begins_with(prefix) or code.length()>MAX_CODE: return {}
	var encoded := code.substr(prefix.length())
	if encoded.length()%4!=0: return {}
	var bytes := Marshalls.base64_to_raw(encoded)
	if bytes.size()<6 or Marshalls.raw_to_base64(bytes)!=encoded: return {}
	var size := bytes.decode_u32(1)
	if size<2 or size>MAX_RAW or bytes[0] not in [3,255]: return {}
	var raw := bytes.slice(5)
	if bytes[0]==3: raw=raw.decompress(size,FileAccess.COMPRESSION_GZIP)
	if raw.size()!=size: return {}
	var parser := JSON.new()
	if parser.parse(raw.get_string_from_utf8())!=OK: return {}
	return parser.data if parser.data is Dictionary else {}

static func level(code: String, puzzle_name: String, author: String, description: String) -> String:
	if puzzle_name.strip_edges().is_empty() or author.strip_edges().is_empty(): return ""
	if puzzle_name.length()>80 or author.length()>40 or description.length()>100: return ""
	if code.begins_with("CPE2:"): code=str(metadata(code).get("l",""))
	if LevelEditorCodec.decode(code).is_empty(): return ""
	return pack("CPE2:",{"v":DataVersion.current(),"n":puzzle_name.strip_edges(),"a":author.strip_edges(),"d":description,"l":code})

static func metadata(code: String) -> Dictionary:
	var value := unpack("CPE2:",code)
	if not DataVersion.accepts(value,true): return {}
	if not value.get("n") is String or not value.get("a") is String or not value.get("d") is String or not value.get("l") is String: return {}
	if value.n.length()>80 or value.a.length()>40 or value.d.length()>100 or not (value.l.begins_with("CPE1:") or value.l.begins_with("CPE3:")): return {}
	return value
