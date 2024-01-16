extends Control

@onready var music_player : AudioStreamPlayer = $MusicStreamPlayer
@onready var version_label : Label = $Informations/BuildVersionValue

func _ready():
	version_label.text = ProjectSettings.get_setting("application/config/version")


func _on_main_button_pressed():
	print(UserDataManager.teacher)


func _on_music_stream_player_finished():
	music_player.stream_paused = false
	music_player.play()
