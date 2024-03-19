extends Node

@onready var music_player : AudioStreamPlayer = $MusicPlayer

const main_menu_music: AudioStream = preload("res://assets/menus/main/ui_title_card_music.mp3")

func _ready() -> void:
	play(main_menu_music)

func _on_music_player_finished() -> void:
	music_player.stream_paused = false
	music_player.play()

func play(music : AudioStream) -> void:
	music_player.stream = music
	music_player.play()

func stop() -> void:
	music_player.stop()
