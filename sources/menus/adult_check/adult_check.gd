extends Control

const main_menu_scene_path: = "res://sources/menus/main/main_menu.tscn"
const register_scene_path := "res://sources/menus/register/register.tscn"
const symbols_names = {
	"1" : "star",
	"2" : "bar",
	"3" : "circle",
	"4" : "plus",
	"5" : "square",
	"6" : "triangle",
}

@onready var code_keyboard : CodeKeyboard = %CodeKeyboard
@onready var password_label : Label = %PasswordLabel

var base_password_label_text : String
var password : String = ""

func _ready() -> void:
	base_password_label_text = password_label.text
	_reset_password()
	
	OpeningCurtain.open()


func _reset_password() -> void:
	password = TeacherSettings.available_codes.pick_random()
	var password_array: = password.split("")
	password_label.text = base_password_label_text % [symbols_names[password_array[0]], symbols_names[password[1]], symbols_names[password[2]]]


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(main_menu_scene_path)


func _on_code_keyboard_password_entered(entered_password: String) -> void:
	if password != entered_password:
		code_keyboard.reset_password()
		_reset_password()
		return
	
	await OpeningCurtain.close()
	get_tree().change_scene_to_file(register_scene_path)
