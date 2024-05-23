extends AudioStreamPlayer

const eat_sfx: Array[AudioStream] = [
	preload("res://assets/minigames/caterpillar/audios/caterpillar_eat_random_01.mp3"),
	preload("res://assets/minigames/caterpillar/audios/caterpillar_eat_random_02.mp3"),
	preload("res://assets/minigames/caterpillar/audios/caterpillar_eat_random_03.mp3"),
	preload("res://assets/minigames/caterpillar/audios/caterpillar_eat_random_04.mp3"),
]

func eat() -> void:
	stream = eat_sfx.pick_random()
	play()
