extends Node

@onready var music_player : AudioStreamPlayer = $MusicPlayer

const main_menu_music := preload("res://assets/menus/main/ui_title_card_music.mp3")

func _ready():
	play(main_menu_music)

func _on_music_player_finished():
	music_player.stream_paused = false
	music_player.play()

func play(music : AudioStream):
	music_player.stream = music
	music_player.play()

func stop():
	music_player.stop()
