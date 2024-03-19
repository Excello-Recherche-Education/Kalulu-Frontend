extends AudioStreamPlayer2D
class_name CrabAudioStreamPlayer

const crab_sound_list: = [
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

var is_playing: = false


func start_playing() -> void:
	is_playing = true
	_on_finished()


func stop_playing() -> void:
	is_playing = false


func _on_finished() -> void:
	if is_playing:
		stream = crab_sound_list[randi() % crab_sound_list.size()]
		playing = true
