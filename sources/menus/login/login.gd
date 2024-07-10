extends Control

const teacher_password : String = "42"
const back_scene_path: = "res://sources/menus/main/main_menu.tscn"
const next_scene_path: = "res://sources/menus/brain/brain.tscn"
const teacher_scene_path: = "res://sources/menus/settings/teacher_settings.tscn"
const package_loader_scene_path: = "res://sources/menus/language_selection/local_package_downloader.tscn"

@onready var kalulu: Control = $Kalulu
@onready var music_player : AudioStreamPlayer = $MusicStreamPlayer
@onready var device_number_label := $DeviceNumber
@onready var keyboard : CodeKeyboard = $CodeKeyboard
@onready var teacher_timer : Timer = $InterfaceRight/TeacherButton/TeacherTimer

var help_speech: AudioStream
var wrong_password_speech: AudioStream
var right_password_speech: AudioStream

func _ready():
	# Check if the database is connected, if not go to loader
	if not Database.is_open:
		get_tree().change_scene_to_file(package_loader_scene_path)
	
	help_speech = Database.load_external_sound(Database.get_kalulu_speech_path("login_screen", "help_code"))
	wrong_password_speech = Database.load_external_sound(Database.get_kalulu_speech_path("login_screen", "feedback_wrong_password"))
	right_password_speech = Database.load_external_sound(Database.get_kalulu_speech_path("login_screen", "feedback_right_password"))
	
	if UserDataManager.teacher_settings and UserDataManager.teacher_settings.account_type == TeacherSettings.AccountType.Teacher:
		device_number_label.show()
		device_number_label.text += str(UserDataManager.get_device_settings().device_id)
	
	await OpeningCurtain.open()
	
	await kalulu.play_kalulu_speech(help_speech)
	music_player.play()


func _on_code_keyboard_password_entered(password):
	if UserDataManager.login_student(password):
		await kalulu.play_kalulu_speech(right_password_speech)
		await OpeningCurtain.close()
		get_tree().change_scene_to_file(next_scene_path)
	else:
		await kalulu.play_kalulu_speech(wrong_password_speech)
		keyboard.reset_password()


func _on_back_button_pressed():
	get_tree().change_scene_to_file(back_scene_path)


func _on_kalulu_button_pressed():
	kalulu.play_kalulu_speech(help_speech)


func _on_teacher_button_button_down():
	if keyboard.get_password_as_string() == teacher_password:
		teacher_timer.start()


func _on_teacher_button_button_up():
	teacher_timer.stop()


func _on_teacher_timer_timeout():
	await OpeningCurtain.close()
	get_tree().change_scene_to_file(teacher_scene_path)
