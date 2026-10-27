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
	preload("res://scripts/puzzle_art.gd").draw_portal(self,symbol)
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
