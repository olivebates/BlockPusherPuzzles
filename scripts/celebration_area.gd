@tool
extends Node2D
@export var size := Vector2(512,256):
	set(value):
		size=Vector2(maxf(16,value.x),maxf(16,value.y))
		queue_redraw()
var active := false
var launch_wait := 0.0
var rockets: Array[Dictionary]=[]
var sparks: Array[Dictionary]=[]
var fireworks: Node2D
class FireworkView extends Node2D:
	var area: Node2D
	func _draw() -> void: area.draw_fireworks(self)
func _ready() -> void:
	z_index=-10
	if not Engine.is_editor_hint():
		add_to_group("celebration_areas")
		fireworks=FireworkView.new()
		fireworks.area=self
		# Above floors and blocks, below the player's Z=3 and completion text Z=4.
		fireworks.z_index=12
		add_child(fireworks)
func contains_player() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	return player!=null and not player.noclip and Rect2(-size/2,size).has_point(to_local(player.global_position))
func launch() -> void:
	var screen := get_viewport_rect().size
	var start := Vector2(randf_range(screen.x*0.08,screen.x*0.92),screen.y+8)
	rockets.append({"start":start,"point":start,"target":Vector2(start.x+randf_range(-50,50),randf_range(screen.y*0.12,screen.y*0.5)),"time":0.0,"duration":randf_range(0.8,1.2),"color":Color.from_hsv(randf(),0.65,1)})
func explode(rocket: Dictionary) -> void:
	for i in 40:
		var velocity := Vector2.from_angle(TAU*i/40+randf_range(-0.06,0.06))*randf_range(45,125)
		var life := randf_range(0.7,1.5)
		sparks.append({"point":rocket.point,"velocity":velocity,"life":life,"duration":life,"color":rocket.color})
func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	active=contains_player()
	if Juice.reduced_motion:
		rockets.clear()
		sparks.clear()
		queue_redraw()
		if is_instance_valid(fireworks): fireworks.queue_redraw()
		return
	launch_wait=maxf(0,launch_wait-delta)
	if active and launch_wait<=0:
		launch()
		launch_wait=randf_range(0.45,0.8)
	for i in range(rockets.size()-1,-1,-1):
		var rocket := rockets[i]
		rocket.time+=delta
		var fraction := minf(rocket.time/rocket.duration,1)
		rocket.point=rocket.start.lerp(rocket.target,1-pow(1-fraction,1.4))
		if fraction>=1:
			explode(rocket)
			rockets.remove_at(i)
	for i in range(sparks.size()-1,-1,-1):
		var spark := sparks[i]
		spark.life-=delta
		if spark.life<=0:
			sparks.remove_at(i)
			continue
		spark.velocity.y+=65*delta
		spark.point+=spark.velocity*delta
	queue_redraw()
	if is_instance_valid(fireworks): fireworks.queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(-size/2,size),Color("252525"))
	if Engine.is_editor_hint():
		draw_rect(Rect2(-size/2,size),Color("606060"),false,1)
func draw_fireworks(canvas: Node2D) -> void:
	# Keep launches attached to the bottom of the screen as the camera moves.
	canvas.draw_set_transform_matrix(canvas.get_global_transform_with_canvas().affine_inverse())
	for rocket in rockets:
		canvas.draw_line(rocket.point+Vector2(0,14),rocket.point,Color(rocket.color,0.5),1.2,true)
		canvas.draw_circle(rocket.point,1.6,Color.WHITE)
	for spark in sparks:
		var alpha: float=clampf(spark.life/spark.duration,0,1)
		canvas.draw_line(spark.point-spark.velocity*0.035,spark.point,Color(spark.color,alpha),1.3,true)
		canvas.draw_circle(spark.point,1,Color(spark.color,alpha))
