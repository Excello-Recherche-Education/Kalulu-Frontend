extends Control

const back_scene_path: = "res://sources/menus/main/main_menu.tscn"
const next_scene_path: = "res://sources/menus/minigame_selection.tscn"
const teacher_scene_path: = "res://sources/menus/teacher/teacher_settings.tscn"
const icons_textures = [
	preload("res://assets/menus/login/symbol01.png"),
	preload("res://assets/menus/login/symbol02.png"),
	preload("res://assets/menus/login/symbol03.png"),
	preload("res://assets/menus/login/symbol04.png"),
	preload("res://assets/menus/login/symbol05.png"),
	preload("res://assets/menus/login/symbol06.png")
]
const button_sound := preload("res://assets/menus/login/ui_play_button.mp3")
const help_speech_path : String = "main_menu/audio/login_screen_help_code.mp3"
const wrong_password_speech_path : String = "main_menu/audio/login_screen_feedback_wrong_password.mp3"
const right_password_speech_path : String = "main_menu/audio/login_screen_feedback_right_password.mp3"


@onready var kalulu: Control = $Kalulu
@onready var music_player : AudioStreamPlayer = $MusicStreamPlayer
@onready var device_number_label := $DeviceNumber
@onready var icons := [%Icon1, %Icon2, %Icon3]
@onready var keyboard := $CodeKeyboard
@onready var teacher_timer : Timer = $InterfaceRight/TeacherButton/TeacherTimer

var password : Array = []

func _ready():
	
	if UserDataManager.teacher_settings.type == TeacherSettings.Type.Teacher:
		device_number_label.show()
		device_number_label.text += str(UserDataManager.get_device_settings().device_id)
	
	await kalulu.play_kalulu_speech(Database.get_audio_stream_for_path(help_speech_path))
	music_player.play()


func _reset_password():
	password = []
	
	keyboard.reset_buttons()
	
	for icon in icons:
		icon.texture = null


func _on_code_keyboard_button_pressed(key : String):
	
	var index : int = key.to_int()
	
	password.append(key)
	var password_size = password.size()
	
	icons[password_size-1].texture = icons_textures[index-1]
	
	if password_size == 3:
		_check_password()


func _check_password():
	var code = ""
	for char_ in password:
		code += char_
	
	if UserDataManager.login_student(code):
		await kalulu.play_kalulu_speech(Database.get_audio_stream_for_path(right_password_speech_path))
		get_tree().change_scene_to_file(next_scene_path)
	else:
		await kalulu.play_kalulu_speech(Database.get_audio_stream_for_path(wrong_password_speech_path))
		_reset_password()


func _on_back_button_pressed():
	get_tree().change_scene_to_file(back_scene_path)


func _on_kalulu_button_pressed():
	kalulu.play_kalulu_speech(Database.get_audio_stream_for_path(help_speech_path))


func _on_teacher_button_button_down():
	teacher_timer.start()


func _on_teacher_button_button_up():
	teacher_timer.stop()


func _on_teacher_timer_timeout():
	get_tree().change_scene_to_file(teacher_scene_path)
