extends Node

@onready var music_player := $MusicPlayer

const main_menu_music := preload("res://assets/menus/main/ui_title_card_music.mp3")

func _ready():
	music_player.stream = main_menu_music
	music_player.play()

func _on_music_player_finished():
	music_player.stream_paused = false
	music_player.play()

func play_music(music : AudioStream):
	music_player.stream = music
	music_player.play()
