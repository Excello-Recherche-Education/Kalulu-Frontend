extends AudioStreamPlayer2D

const crab_sound_list: Array[AudioStreamMP3] = [
	preload("res://assets/minigames/crabs/audio/sfx/crab_random_1.mp3"),
	preload("res://assets/minigames/crabs/audio/sfx/crab_random_1.mp3"),
	preload("res://assets/minigames/crabs/audio/sfx/crab_random_1.mp3"),
	preload("res://assets/minigames/crabs/audio/sfx/crab_random_1.mp3"),
	preload("res://assets/minigames/crabs/audio/sfx/crab_random_1.mp3"),
	preload("res://assets/minigames/crabs/audio/sfx/crab_random_1.mp3"),
	preload("res://assets/minigames/crabs/audio/sfx/crab_random_1.mp3"),
	preload("res://assets/minigames/crabs/audio/sfx/crab_random_1.mp3"),
	preload("res://assets/minigames/crabs/audio/sfx/crab_random_1.mp3"),
	preload("res://assets/minigames/crabs/audio/sfx/crab_random_1.mp3"),
	preload("res://assets/minigames/crabs/audio/sfx/crab_random_1.mp3"),
	preload("res://assets/minigames/crabs/audio/sfx/crab_random_1.mp3"),
	preload("res://assets/minigames/crabs/audio/sfx/crab_random_1.mp3"),
]

var _should_play: bool = false


func start_playing() -> void:
	_should_play = true
	_on_finished()


func stop_playing() -> void:
	_should_play = false


func _on_finished() -> void:
	if _should_play:
		stream = crab_sound_list[randi() % crab_sound_list.size()]
		playing = true
