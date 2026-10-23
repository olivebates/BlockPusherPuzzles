@tool
extends CharacterBody2D
@export var slide_speed := 150.0
@export var charge_time := 0.2
var home: Vector2
var recall_available := false
var charging := false
var sliding := false
var charge := 0.0
var direction := Vector2.ZERO
var contact_latched := false
var shake := Vector2.ZERO
var recall_freeze_frames := 0
var carried_frame := -1
func _ready() -> void:
	if Engine.is_editor_hint(): return
	add_to_group("spheres")
	collision_mask|=8
	home = global_position
	var ghost := Node2D.new()
	ghost.set_script(load("res://scripts/home_outline.gd"))
	ghost.set("circular",true)
	ghost.set("white",true)
	ghost.position = home
	get_parent().add_child.call_deferred(ghost)
func _draw() -> void:
	draw_circle(shake,7.5,Color("ffffff") if recall_available else Color("dce5ef"))
	draw_arc(shake,5.5,PI,PI*1.6,12,Color.WHITE,1,true)
func touch(push_direction: Vector2) -> void:
	if sliding or charging or contact_latched: return
	contact_latched = true
	direction = Vector2(signf(push_direction.x),0) if absf(push_direction.x)>absf(push_direction.y) else Vector2(0,signf(push_direction.y))
	if direction == Vector2.ZERO: return
	charging = true
	charge = 0
func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if carried_frame==Engine.get_physics_frames():
		velocity = Vector2.ZERO
		return
	if recall_freeze_frames>0:
		recall_freeze_frames -= 1
		velocity = Vector2.ZERO
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		var gap := (player.global_position-global_position).abs()
		if gap.x > 14 or gap.y > 16: contact_latched = false
	if charging:
		charge += delta
		shake = Vector2(sin(charge*170),cos(charge*137))*0.65
		if charge >= charge_time:
			charging = false
			sliding = true
			shake = Vector2.ZERO
			Juice.sound("push",1.4)
	if sliding:
		velocity = direction*slide_speed
		if SupportCarry.move(self,velocity*delta):
			sliding = false
			velocity = Vector2.ZERO
			Juice.sound("land",1.3)
			Juice.impact(0.5,global_position)
	queue_redraw()
func reset_home() -> void:
	var previous := global_position
	if not PuzzlePhysics.teleport(self,home,[get_rid()]):
		Juice.sound("close")
		return
	sliding = false
	charging = false
	charge = 0
	shake = Vector2.ZERO
	contact_latched = true
	Juice.burst(previous,Color.WHITE,8)
	Juice.burst(home,Color.WHITE,8)
	Juice.sound("reset")

