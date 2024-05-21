extends TextureRect
class_name Water

const water_ring_scene: PackedScene = preload("res://sources/utils/fx/water_ring.tscn")

@export var ring_color: Color

@onready var audio_stream_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

func spawn_water_ring(position: Vector2):
	var fx: WaterRingFX = water_ring_scene.instantiate()
	fx.position = position
	fx.modulate = ring_color
	add_child(fx)
	
	if not audio_stream_player.playing:
		audio_stream_player.position = position
		audio_stream_player.play()
	
	await fx.play()
	fx.queue_free()
