extends CanvasLayer
const DISCORD_URL := preload("res://scripts/ending_message.gd").DISCORD_URL
const DONATE_URL := "https://ko-fi.com/snugglefox"
var bar: Control
var waiting_for_opening := true
var reveal_tween: Tween
class SupportButton extends Control:
	var caption := ""
	var url := ""
	var action: Callable
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
			if action.is_valid(): action.call()
			else: OS.shell_open(url)
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
	bar=Control.new()
	bar.name="SupportBar"
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top=0
	bar.offset_bottom=16
	bar.hide()
	add_child(bar)
	for index in 3:
		var button := SupportButton.new()
		button.name=["Discord","Donate","Level Editor"][index]
		button.caption=button.name
		button.world=get_parent()
		if index==2: button.action=LevelEditorSession.open_menu
		else: button.url=DISCORD_URL if index==0 else DONATE_URL
		button.anchor_left=index/3.0
		button.anchor_right=(index+1)/3.0
		button.anchor_bottom=1
		button.clip_contents=true
		bar.add_child(button)
	var credit := Label.new()
	credit.name="WebsiteCredit"
	credit.text="snugglefox.net"
	credit.add_theme_font_size_override("font_size",10)
	credit.add_theme_color_override("font_color",Color.WHITE)
	credit.mouse_filter=Control.MOUSE_FILTER_IGNORE
	credit.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	credit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	credit.offset_left=6
	credit.offset_right=160
	credit.offset_top=-32
	credit.offset_bottom=-18
	credit.hide()
	add_child(credit)
	bar.visibility_changed.connect(func(): credit.visible=bar.visible)

func _process(_delta: float) -> void:
	if Dialogue.active and Dialogue.dialogue_id=="opening":
		if not waiting_for_opening or bar.visible:
			if reveal_tween and reveal_tween.is_valid(): reveal_tween.kill()
			waiting_for_opening=true
			bar.hide()
			bar.offset_top=0
			bar.offset_bottom=16
		return
	if not waiting_for_opening or Progress.restoring: return
	if Progress.level!=get_parent() or not Progress.dialogues.has("opening"): return
	waiting_for_opening=false
	bar.show()
	if Juice.reduced_motion:
		bar.offset_top=-16
		bar.offset_bottom=0
		return
	reveal_tween=create_tween().set_parallel(true)
	reveal_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reveal_tween.tween_property(bar,"offset_top",-16.0,0.45)
	reveal_tween.tween_property(bar,"offset_bottom",0.0,0.45)
