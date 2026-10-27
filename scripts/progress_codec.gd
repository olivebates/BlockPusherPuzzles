class_name ProgressCodec
extends RefCounted
const LIMIT := 16777216
static func digest(bytes: PackedByteArray) -> PackedByteArray:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish()
static func encode(data: Dictionary) -> PackedByteArray:
	var current := DataVersion.stamp(data)
	if current.is_empty(): return PackedByteArray()
	var raw := JSON.stringify(current).to_utf8_buffer()
	var best := raw
	var mode := 255
	for codec in [FileAccess.COMPRESSION_ZSTD,FileAccess.COMPRESSION_DEFLATE,FileAccess.COMPRESSION_GZIP,FileAccess.COMPRESSION_FASTLZ]:
		var packed := raw.compress(codec)
		if not packed.is_empty() and packed.size()<best.size():
			best=packed
			mode=codec
	var bytes := "CPS1".to_ascii_buffer()
	bytes.resize(9)
	bytes[4]=mode
	bytes.encode_u32(5,raw.size())
	bytes.append_array(digest(bytes+best))
	bytes.append_array(best)
	return bytes
static func decode(bytes: PackedByteArray) -> Dictionary:
	var data := unpack(bytes)
	return data if DataVersion.accepts(data) else {}

# Inspect the verified container before deciding whether its schema can load.
static func unpack(bytes: PackedByteArray) -> Dictionary:
	if bytes.size()<41 or bytes.size()>LIMIT or bytes.slice(0,4).get_string_from_ascii()!="CPS1": return {}
	var size := bytes.decode_u32(5)
	if size<1 or size>LIMIT: return {}
	var mode := int(bytes[4])
	if mode!=255 and mode not in [FileAccess.COMPRESSION_ZSTD,FileAccess.COMPRESSION_DEFLATE,FileAccess.COMPRESSION_GZIP,FileAccess.COMPRESSION_FASTLZ]: return {}
	var raw := bytes.slice(41)
	if digest(bytes.slice(0,9)+raw)!=bytes.slice(9,41): return {}
	if mode!=255: raw=raw.decompress(size,mode)
	if raw.size()!=size: return {}
	var data: Variant=JSON.parse_string(raw.get_string_from_utf8())
	return data if data is Dictionary else {}
