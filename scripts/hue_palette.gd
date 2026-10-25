class_name HuePalette
extends RefCounted
## A sampled hue wheel preserves the current RGB blend when interrupted.
const SAMPLES := 1536
const DEFAULT_COLOR := Color(0,0.6121615,0.6229425,1)
const DEFAULT_BACKGROUND := Color(0,0.31805697,0.33218518,1)
const DEFAULT_TILES := Color(0,0.08549511,0.103616185,1)
static func hue_offset(color: Color) -> float:
	return 0.0 if color.s<0.001 else wrapf(color.h-DEFAULT_COLOR.h,-0.5,0.5)
var colors := PackedColorArray()
var source := PackedColorArray()
var target := PackedColorArray()
var texture: ImageTexture
func _init() -> void: reset(0.0)
func wheel(shift: float) -> PackedColorArray:
	var result := PackedColorArray()
	for i in range(SAMPLES+1): result.append(Color.from_hsv(wrapf(float(i)/SAMPLES+shift,0.0,1.0),1,1))
	return result
func reset(shift: float) -> void:
	colors=wheel(shift)
	upload()
func begin(shift: float) -> void:
	source=colors.duplicate()
	target=wheel(shift)
func blend(amount: float) -> void:
	for i in colors.size(): colors[i]=source[i].lerp(target[i],amount)
	upload()
func upload() -> void:
	var pixels := PackedFloat32Array()
	for color in colors: pixels.append_array(PackedFloat32Array([color.r,color.g,color.b]))
	var image := Image.create_from_data(SAMPLES+1,1,false,Image.FORMAT_RGBF,pixels.to_byte_array())
	if texture: texture.update(image)
	else: texture=ImageTexture.create_from_image(image)
func map_color(color: Color) -> Color:
	var position := color.h*SAMPLES
	var index := mini(int(position),SAMPLES-1)
	var rainbow := colors[index].lerp(colors[index+1],position-index)
	var result := Color.WHITE.lerp(rainbow,color.s)*color.v
	result.a=color.a
	return result
