class_name LevelEditorCodec
extends RefCounted
const PREFIX := "CPE3:"
const LEGACY_PREFIX := "CPE1:"
const MAX_CELLS := 512*512

static func unsupported_version(text: String) -> bool:
	text=text.strip_edges()
	if text.begins_with("CPE2:"):
		var value := CommunityCodec.unpack("CPE2:",text)
		if not value.is_empty() and not DataVersion.accepts(value,true): return true
		var inner: Variant=value.get("l")
		return unsupported_version(inner) if inner is String and inner.begins_with(PREFIX) else false
	if text.begins_with(PREFIX) and text.length()<=MAX_CELLS*2:
		var bytes := Marshalls.base64_to_raw(text.substr(PREFIX.length()))
		return bytes.size()>=2 and not DataVersion.readable(bytes.decode_u16(0))
	return false

# One byte per cell: a solid/player nibble and a key/rotator nibble.
# Compare lossless codecs, then Base64 only the smallest payload and header.
static func encode(data: Dictionary) -> String:
	if not LevelData.valid(data,false): return ""
	var width: int=data.grid[0]
	var height: int=data.grid[1]
	var cells := PackedByteArray()
	cells.resize(width*height)
	for tile in data.tiles:
		if tile[0]<0 or tile[0]>=width or tile[1]<0 or tile[1]>=height: return ""
		cells[tile[1]*width+tile[0]]=1
	for item in data.objects:
		var x := floori(item[1]/16.0)
		var y := floori(item[2]/16.0)
		if x<0 or x>=width or y<0 or y>=height: return ""
		var index := y*width+x
		match int(item[0]):
			1: cells[index]=(cells[index]&0xf0)|2
			2: cells[index]=(cells[index]&0xf0)|(3+int(item[3]))
			3: cells[index]=(cells[index]&0x0f)|((1+int(item[3]))<<4)
			10,11: cells[index]=(cells[index]&0x0f)|((5+int(item[0])-10)<<4)
			7: cells[index]=(cells[index]&0xf0)|7
			8: cells[index]=(cells[index]&0xf0)|8
			20: cells[index]=(cells[index]&0xf0)|9
			5: cells[index]=(cells[index]&0xf0)|(10+int(item[3]))
			18:
				if item.slice(3)!=[0,128,"8adfffff",true]: return ""
				cells[index]=(cells[index]&0xf0)|14
			_: return ""
	var payload := cells
	var codec := 255
	for mode in [FileAccess.COMPRESSION_ZSTD,FileAccess.COMPRESSION_DEFLATE,FileAccess.COMPRESSION_GZIP,FileAccess.COMPRESSION_FASTLZ]:
		var candidate := cells.compress(mode)
		if not candidate.is_empty() and candidate.size()<payload.size():
			payload=candidate
			codec=mode
	var bytes := PackedByteArray()
	bytes.resize(10)
	bytes.encode_u16(0,DataVersion.current())
	bytes.encode_u16(2,width)
	bytes.encode_u16(4,height)
	var color := Color.html(data.get("color",HuePalette.DEFAULT_BACKGROUND.to_html(false)))
	bytes[6]=color.r8
	bytes[7]=color.g8
	bytes[8]=color.b8
	bytes[9]=codec
	bytes.append_array(payload)
	var code := PREFIX+Marshalls.raw_to_base64(bytes)
	if data.has("metadata"):
		var meta: Dictionary=data.metadata
		return CommunityCodec.level(code,str(meta.get("n","")),str(meta.get("a","")),str(meta.get("d","")))
	return code

static func decode(text: String) -> Dictionary:
	text=text.strip_edges()
	if text.begins_with("CPE2:"):
		var meta := CommunityCodec.metadata(text)
		if meta.is_empty(): return {}
		var result := decode(meta.l)
		if not result.is_empty(): result.metadata={"n":meta.n,"a":meta.a,"d":meta.d}
		return result
	var versioned := text.begins_with(PREFIX)
	if (not versioned and not text.begins_with(LEGACY_PREFIX)) or text.length()>MAX_CELLS*2: return {}
	var encoded := text.substr(PREFIX.length())
	if encoded.is_empty() or encoded.length()%4!=0: return {}
	for character in encoded:
		if not character in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=": return {}
	var bytes := Marshalls.base64_to_raw(encoded)
	var offset := 2 if versioned else 0
	if bytes.size()<offset+9: return {}
	var version := bytes.decode_u16(0) if versioned else DataVersion.legacy()
	if not DataVersion.readable(version): return {}
	var width := bytes.decode_u16(offset)
	var height := bytes.decode_u16(offset+2)
	if width<1 or height<1 or width>512 or height>512: return {}
	var codec := int(bytes[offset+7])
	if codec!=255 and codec not in [FileAccess.COMPRESSION_ZSTD,FileAccess.COMPRESSION_DEFLATE,FileAccess.COMPRESSION_GZIP,FileAccess.COMPRESSION_FASTLZ]: return {}
	var cells := bytes.slice(offset+8)
	if codec!=255: cells=cells.decompress(width*height,codec)
	if cells.size()!=width*height: return {}
	var color := Color8(bytes[offset+4],bytes[offset+5],bytes[offset+6])
	var data := {"v":version,"grid":[width,height,16],"color":color.to_html(false),"tiles":[],"objects":[]}
	for index in cells.size():
		var solid := cells[index]&0x0f
		var marker := cells[index]>>4
		# Versions 1 and 2 retain their original nibble meanings. Version 3
		# extends unused solid values; legacy cells need no field conversion.
		if solid>(14 if version>=3 else 6) or marker>6 or (solid==1 and marker!=0): return {}
		var x := index%width
		var y := index/width
		var px := x*16+8
		var py := y*16+8
		if solid==1: data.tiles.append([x,y])
		elif solid==2: data.objects.append([1,px,py])
		elif solid in [3,4,5,6]: data.objects.append([2,px,py,solid-3,0.2,0.15])
		elif solid in [7,8]: data.objects.append([solid,px,py])
		elif solid==9: data.objects.append([20,px,py])
		elif solid in [10,11,12,13]: data.objects.append([5,px,py,solid-10])
		elif solid==14: data.objects.append([18,px,py,0,128,"8adfffff",true])
		if marker in [1,2,3,4]: data.objects.append([3,px,py,marker-1,"E%d_%d"%[x,y]])
		elif marker>=5: data.objects.append([10+marker-5,px,py])
	return data if LevelData.valid(data,false) else {}
