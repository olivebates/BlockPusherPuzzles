@tool
extends Node2D
const MESSAGE := preload("res://scripts/ending_message.gd")
const DISCORD_URL := MESSAGE.DISCORD_URL
const DEFAULT_TEXT := MESSAGE.PLAIN_TEXT
var text: String:
	get: return MESSAGE.PLAIN_TEXT
@export var size := Vector2(448,192):
	set(value):
		size=Vector2(maxf(16,value.x),maxf(16,value.y))
		if is_inside_tree(): update_text()
@export_range(6,48,1) var font_size := 12:
	set(value):
		font_size=value
		if is_inside_tree(): update_text()
func _ready() -> void:
	z_index=4
	$Text.meta_clicked.connect(open_link)
	update_text()
func update_text() -> void:
	var label := get_node_or_null("Text") as RichTextLabel
	if not label: return
	label.position=-size/2
	label.size=size
	label.add_theme_font_size_override("normal_font_size",font_size)
	label.add_theme_font_size_override("bold_font_size",font_size)
	label.text="[center]"+plain(MESSAGE.TITLE)+"\n"+plain(MESSAGE.VICTORY)+"\n\n"
	label.text+="[font_size=%d]" % maxi(1,roundi(font_size*0.5))+plain(MESSAGE.REQUEST)+"[/font_size]\n"
	label.text+="[b][color=#ffd433][url="+DISCORD_URL+"]"+plain(DISCORD_URL)+"[/url][/color][/b]\n"
	label.text+="[font_size=%d]" % maxi(1,roundi(font_size*2.0/3.0))+plain(MESSAGE.CLOSING)+"[/font_size][/center]"
func plain(value: String) -> String: return value.replace("[","[lb]")
func open_link(url: Variant) -> void:
	if not Engine.is_editor_hint() and str(url)==DISCORD_URL: OS.shell_open(DISCORD_URL)
