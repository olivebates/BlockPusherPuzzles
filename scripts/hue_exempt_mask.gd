extends Node2D
var player_sprites := {}
## A screen-aligned mask, isolated from the main scene's visibility hierarchy.
func _ready() -> void: process_mode=Node.PROCESS_MODE_ALWAYS
func _process(_delta: float) -> void:
	for player in get_tree().get_nodes_in_group("player"):
		var sprite: Sprite2D=player.visual
		if not player_sprites.has(player.get_instance_id()):
			var copy := Sprite2D.new()
			add_child(copy)
			player_sprites[player.get_instance_id()]=copy
		var copy: Sprite2D=player_sprites[player.get_instance_id()]
		copy.texture=sprite.texture
		copy.texture_filter=sprite.texture_filter
		copy.material=sprite.material
		copy.transform=sprite.get_global_transform_with_canvas()
		copy.flip_h=sprite.flip_h
		copy.flip_v=sprite.flip_v
		copy.offset=sprite.offset
		copy.centered=sprite.centered
		copy.modulate=sprite.modulate
		copy.visible=sprite.is_visible_in_tree()
	for id in player_sprites.keys():
		if not is_instance_id_valid(id):
			player_sprites[id].queue_free()
			player_sprites.erase(id)
	queue_redraw()
func _draw() -> void:
	for rotator in get_tree().get_nodes_in_group("rotators"):
		if not rotator.is_visible_in_tree(): continue
		draw_set_transform_matrix(rotator.get_global_transform_with_canvas())
		rotator.draw_shape(self)
	for block in get_tree().get_nodes_in_group("blocks"):
		if block.leader!=block or not block.is_visible_in_tree(): continue
		draw_set_transform_matrix(block.get_global_transform_with_canvas())
		WeldOutline.draw_pivot(self,block.to_local(block.rotation_pivot_member().global_position))
