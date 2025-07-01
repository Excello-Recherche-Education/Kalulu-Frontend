@tool
extends TextureRect

class_name River

const WATER_RING_SCENE: PackedScene = preload("res://sources/utils/fx/water_ring.tscn")

func spawn_water_ring(pos: Vector2) -> void:
	var fx: WaterRingFX = WATER_RING_SCENE.instantiate()
	fx.global_position = pos
	add_child(fx)
	await fx.play()
	fx.queue_free()
