extends TextureRect

const water_ring_scene: PackedScene = preload("res://sources/utils/fx/water_ring.tscn")

@export var ring_color: Color

func spawn_water_ring(pos: Vector2) -> void:
	var fx: WaterRingFX = water_ring_scene.instantiate()
	fx.position = pos
	fx.modulate = ring_color
	add_child(fx)
	await fx.play()
	fx.queue_free()
