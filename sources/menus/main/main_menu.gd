extends Control

const next_scene_path: = "res://sources/menus/login/login.tscn"

@onready var music_player : AudioStreamPlayer = $MusicStreamPlayer
@onready var version_label : Label = $Informations/BuildVersionValue
@onready var teacher_label : Label = $Informations/TeacherValue
@onready var device_id_label : Label = $Informations/DeviceIDValue

@onready var kalulu : Control = $Kalulu
@onready var login : Control = $Login

func _ready():
	version_label.text = ProjectSettings.get_setting("application/config/version")
	teacher_label.text = UserDataManager.device_settings.teacher
	device_id_label.text = str(UserDataManager.device_settings.device_id)


func _on_main_button_pressed():
	if UserDataManager.device_settings.teacher:
		get_tree().change_scene_to_file(next_scene_path)
	else:
		kalulu.visible = false
		kalulu.stop_speech()
		login.visible = true


func _on_back_button_pressed():
	login.visible = false
	kalulu.visible = true
	kalulu.start_speech()


func _on_login_in():
	get_tree().change_scene_to_file(next_scene_path)


func _on_music_stream_player_finished():
	music_player.stream_paused = false
	music_player.play()
