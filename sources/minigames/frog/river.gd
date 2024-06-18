@tool
extends TextureRect

const water_ring_scene: PackedScene = preload("res://sources/utils/fx/water_ring.tscn")

func spawn_water_ring(pos: Vector2) -> void:
	var fx: WaterRingFX = water_ring_scene.instantiate()
	fx.global_position = pos
	add_child(fx)
	await fx.play()
	fx.queue_free()
