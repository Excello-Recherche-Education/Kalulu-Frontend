extends Control

const teacher_password : String = "42"
const back_scene_path: = "res://sources/menus/main/main_menu.tscn"
const next_scene_path: = "res://sources/menus/minigame_selection.tscn"
const teacher_scene_path: = "res://sources/menus/teacher/teacher_settings.tscn"
const help_speech_path : String = "main_menu/audio/login_screen_help_code.mp3"
const wrong_password_speech_path : String = "main_menu/audio/login_screen_feedback_wrong_password.mp3"
const right_password_speech_path : String = "main_menu/audio/login_screen_feedback_right_password.mp3"

@onready var kalulu: Control = $Kalulu
@onready var music_player : AudioStreamPlayer = $MusicStreamPlayer
@onready var device_number_label := $DeviceNumber
@onready var keyboard : CodeKeyboard = $CodeKeyboard
@onready var teacher_timer : Timer = $InterfaceRight/TeacherButton/TeacherTimer

func _ready():
	if UserDataManager.teacher_settings and UserDataManager.teacher_settings.account_type == TeacherSettings.AccountType.Teacher:
		device_number_label.show()
		device_number_label.text += str(UserDataManager.get_device_settings().device_id)
	
	await kalulu.play_kalulu_speech(Database.get_audio_stream_for_path(help_speech_path))
	music_player.play()


func _on_code_keyboard_password_entered(password):
	if UserDataManager.login_student(password):
		await kalulu.play_kalulu_speech(Database.get_audio_stream_for_path(right_password_speech_path))
		get_tree().change_scene_to_file(next_scene_path)
	else:
		await kalulu.play_kalulu_speech(Database.get_audio_stream_for_path(wrong_password_speech_path))
		keyboard.reset_password()


func _on_back_button_pressed():
	get_tree().change_scene_to_file(back_scene_path)


func _on_kalulu_button_pressed():
	kalulu.play_kalulu_speech(Database.get_audio_stream_for_path(help_speech_path))


func _on_teacher_button_button_down():
	if keyboard.get_password_as_string() == teacher_password:
		teacher_timer.start()


func _on_teacher_button_button_up():
	teacher_timer.stop()


func _on_teacher_timer_timeout():
	get_tree().change_scene_to_file(teacher_scene_path)
