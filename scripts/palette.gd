class_name PuzzlePalette
extends RefCounted
enum Hue { CYAN, CORAL, GOLD, LILAC }
const COLORS = [Color("58e4ec"), Color("ff827d"), Color("f9cf72"), Color("b69aff")]
const NAMES = ["CYAN", "CORAL", "GOLD", "LILAC"]
static func color_for(hue: int) -> Color:
	return COLORS[clampi(hue, 0, 3)]
