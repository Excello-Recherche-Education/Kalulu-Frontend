extends TextureRect
class_name Water

const water_ring_scene: PackedScene = preload("res://sources/utils/fx/water_ring.tscn")


@onready var audio_stream_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

func spawn_water_ring(position: Vector2):
	var fx: WaterRingFX = water_ring_scene.instantiate()
	fx.position = position
	fx.modulate = "a6e0d8"
	add_child(fx)
	
	if not audio_stream_player.playing:
		audio_stream_player.play()
	
	await fx.play()
	fx.queue_free()
