extends CanvasLayer
const DISCORD_URL := preload("res://scripts/ending_message.gd").DISCORD_URL
const DONATE_URL := "https://ko-fi.com/snugglefox"
class SupportButton extends Control:
	var caption := ""
	var url := ""
	var hovered := false
	var world: Node2D
	var background_color := Color.BLACK
	var border_color := Color.WHITE
	var font_color := Color.WHITE
	func _process(_delta: float) -> void:
		var game_color: Color=world.hue_palette.map_color(world.background_color)
		background_color=game_color.darkened(0.2)
		border_color=game_color.lightened(0.3)
		font_color=game_color.lightened(0.75)
		queue_redraw()
	func _ready() -> void:
		mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
		focus_mode=Control.FOCUS_NONE
		tooltip_text=url
		mouse_entered.connect(func(): hovered=true; queue_redraw())
		mouse_exited.connect(func(): hovered=false; queue_redraw())
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
			accept_event()
			OS.shell_open(url)
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),background_color.lightened(0.12) if hovered else background_color)
		draw_rect(Rect2(Vector2.ONE*0.5,size-Vector2.ONE),border_color,false,1)
		var font := ThemeDB.fallback_font
		var width := font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x
		var baseline := (size.y-font.get_height(10))/2+font.get_ascent(10)
		draw_string(font,Vector2((size.x-width)/2,baseline),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,10,font_color)
func _ready() -> void:
	layer=1100
	process_mode=Node.PROCESS_MODE_ALWAYS
	var bar := Control.new()
	bar.name="SupportBar"
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top=-16
	add_child(bar)
	for index in 2:
		var button := SupportButton.new()
		button.name="Discord" if index==0 else "Donate"
		button.caption=button.name
		button.world=get_parent()
		button.url=DISCORD_URL if index==0 else DONATE_URL
		button.anchor_left=index*0.5
		button.anchor_right=(index+1)*0.5
		button.anchor_bottom=1
		button.clip_contents=true
		bar.add_child(button)
