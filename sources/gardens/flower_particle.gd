extends Control
class_name FlowerVFX

@export var sounds: Array[AudioStream] = []

@onready var particles: Array[GPUParticles2D] = [
	$Particles,
	$Particles2,
	$Particles3
]

@onready var audio_stream_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

func play() -> void:
	audio_stream_player.stream = sounds.pick_random()
	audio_stream_player.play()
	
	for p in particles:
		p.amount = randi_range(10, 16)
		p.restart()
		await get_tree().create_timer(randf_range(0.1, 0.2)).timeout
