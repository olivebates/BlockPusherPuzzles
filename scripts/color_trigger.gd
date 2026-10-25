@tool
extends Area2D
@export var cycle_hue := false
@export var hex_color := "":
	set(value):
		hex_color = value
		queue_redraw()
@export var color := HuePalette.DEFAULT_COLOR:
	set(value):
		color = value
		queue_redraw()
func selected_color() -> Color:
	var value := hex_color.strip_edges()
	return Color.html(value) if not value.is_empty() and Color.html_is_valid(value) else color
func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("color_triggers")
		hide()
		body_entered.connect(touched)
func touched(body: Node) -> void:
	if body.is_in_group("player"):
		var scene := get_tree().current_scene
		if scene and scene.has_method("change_theme"): scene.change_theme(selected_color(),cycle_hue)
func contains_player(player: Node2D) -> bool:
	var collider := get_node("CollisionShape2D") as CollisionShape2D
	return (collider.global_transform*collider.shape.get_rect()).intersects(Rect2(player.global_position-Vector2(5,7),Vector2(10,14)))
func _draw() -> void:
	if not Engine.is_editor_hint(): return
	var points := PackedVector2Array([Vector2(0,-7),Vector2(7,0),Vector2(0,7),Vector2(-7,0)])
	draw_colored_polygon(points,selected_color())
	points.append(points[0])
	draw_polyline(points,Color("545454"),1,true)
	draw_circle(Vector2(-1.5,-2),1.3,Color(1,1,1,0.65))
func _get_configuration_warnings() -> PackedStringArray:
	if not hex_color.strip_edges().is_empty() and not Color.html_is_valid(hex_color.strip_edges()):
		return PackedStringArray(["Invalid hex color: the color picker value will be used."])
	return PackedStringArray()
