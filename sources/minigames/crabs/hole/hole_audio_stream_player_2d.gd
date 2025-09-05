class_name HoleAudioStreamPlayer
extends AudioStreamPlayer2D

const CRAB_SOUND_LIST: Array[AudioStreamMP3] = [
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
		stream = CRAB_SOUND_LIST[randi() % CRAB_SOUND_LIST.size()]
		playing = true
