class_name CaterpillarAudioStreamPlayer
extends AudioStreamPlayer

const EAT_SFX: Array[AudioStream] = [
	preload("res://assets/minigames/caterpillar/audios/caterpillar_eat_random_01.mp3"),
	preload("res://assets/minigames/caterpillar/audios/caterpillar_eat_random_02.mp3"),
	preload("res://assets/minigames/caterpillar/audios/caterpillar_eat_random_03.mp3"),
	preload("res://assets/minigames/caterpillar/audios/caterpillar_eat_random_04.mp3"),
]


func eat() -> void:
	stream = EAT_SFX.pick_random()
	play()
