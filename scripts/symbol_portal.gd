@tool
extends Node2D
enum Symbol { SQUARE, CIRCLE, TRIANGLE, STAR }
@export var symbol: Symbol = Symbol.SQUARE:
	set(value):
		symbol = value
		queue_redraw()
func _ready() -> void:
	if not Engine.is_editor_hint(): add_to_group("symbol_portals")
func _draw() -> void:
	var orange := Color("ffac59")
	draw_rect(Rect2(-7.5,-7.5,15,15),Color(orange,0.07))
	draw_rect(Rect2(-7.5,-7.5,15,15),orange,false,1)
	match symbol:
		Symbol.SQUARE: draw_rect(Rect2(-3,-3,6,6),orange,false,0.8)
		Symbol.CIRCLE: draw_arc(Vector2.ZERO,3.5,0,TAU,24,orange,0.8,true)
		Symbol.TRIANGLE: draw_polyline(PackedVector2Array([Vector2(0,-4),Vector2(4,3),Vector2(-4,3),Vector2(0,-4)]),orange,0.8,true)
		Symbol.STAR:
			var points := PackedVector2Array()
			for i in 11: points.append(Vector2.from_angle(-PI/2+i*PI/5)*(4.5 if i%2 == 0 else 2.0))
			draw_polyline(points,orange,0.8,true)
func transport(body: CharacterBody2D, member: Node2D) -> void:
	var nearest: Node2D
	var distance := INF
	for portal in get_tree().get_nodes_in_group("symbol_portals"):
		if portal == self or portal.symbol != symbol: continue
		var next_distance := global_position.distance_squared_to(portal.global_position)
		if next_distance < distance:
			distance = next_distance
			nearest = portal
	if nearest == null: return
	var destination: Vector2 = nearest.global_position-(member.global_position-body.global_position)
	var previous := body.global_position
	if not PuzzlePhysics.teleport(body,destination,body.body_rids()): return
	body.portal_locked = true
	body.sliding = false
	body.charge = 0
	body.flash = 1
	body.resting_x = destination.x
	body.sync_members()
	Juice.burst(previous,Color("ffac59"),10)
	Juice.burst(destination,Color("ffac59"),10)
	Juice.sound("reset",1.2)
