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
const help_speech_path : String = "main_menu/audio/login_screen_help_code.mp3"
const wrong_password_speech_path : String = "main_menu/audio/login_screen_feedback_wrong_password.mp3"
const right_password_speech_path : String = "main_menu/audio/login_screen_feedback_right_password.mp3"


@onready var kalulu: Control = $Kalulu
@onready var music_player : AudioStreamPlayer = $MusicStreamPlayer
@onready var buttons: GridContainer = $Buttons
@onready var icons : HBoxContainer = $Icons
@onready var teacher_timer : Timer = $InterfaceRight/TeacherButton/TeacherTimer

var password : Array = []

func _ready():
	# Connect buttons
	for button in buttons.get_children(false):
		button.connect("pressed", _on_button_pressed.bind(button))
	
	await kalulu.play_kalulu_speech(Database.get_audio_stream_for_path(help_speech_path))
	music_player.play()


func _reset_password():
	password = []
	for button in buttons.get_children(false):
		button.set_modulate(Color(1,1,1))
		button.set_disabled(false)
	
	for icon in icons.get_children(false):
		icon.texture = null


func _on_button_pressed(button : TextureButton):
	
	var index : int = button.name.to_int()
	
	password.append(button.name)
	
	button.set_modulate(Color(0.5,0.5,0.5))
	button.set_disabled(true)
	
	var password_size = password.size()
	
	var test = icons.get_node(str(password_size))
	test.texture = icons_textures[index-1]
	
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
