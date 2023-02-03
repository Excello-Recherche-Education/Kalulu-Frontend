extends AudioStreamPlayer2D

const crab_sound_list: = [
	preload("res://resources/minigames/crabs/audio/sfx/crab_random_1.mp3"),
	preload("res://resources/minigames/crabs/audio/sfx/crab_random_1.mp3"),
	preload("res://resources/minigames/crabs/audio/sfx/crab_random_1.mp3"),
	preload("res://resources/minigames/crabs/audio/sfx/crab_random_1.mp3"),
	preload("res://resources/minigames/crabs/audio/sfx/crab_random_1.mp3"),
	preload("res://resources/minigames/crabs/audio/sfx/crab_random_1.mp3"),
	preload("res://resources/minigames/crabs/audio/sfx/crab_random_1.mp3"),
	preload("res://resources/minigames/crabs/audio/sfx/crab_random_1.mp3"),
	preload("res://resources/minigames/crabs/audio/sfx/crab_random_1.mp3"),
	preload("res://resources/minigames/crabs/audio/sfx/crab_random_1.mp3"),
	preload("res://resources/minigames/crabs/audio/sfx/crab_random_1.mp3"),
	preload("res://resources/minigames/crabs/audio/sfx/crab_random_1.mp3"),
	preload("res://resources/minigames/crabs/audio/sfx/crab_random_1.mp3"),
]

var should_play: = false


func start_playing() -> void:
	should_play = true
	_on_finished()


func stop_playing() -> void:
	should_play = false


func _on_finished() -> void:
	if should_play:
		stream = crab_sound_list[randi() % crab_sound_list.size()]
		playing = true
