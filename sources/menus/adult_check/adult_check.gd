extends Control

const main_menu_scene_path: = "res://sources/menus/main/main_menu.tscn"
const register_scene_path := "res://sources/menus/register/register.tscn"
const symbols_names: Dictionary[String, String] = {
	"1" : "STAR",
	"2" : "BAR",
	"3" : "CIRCLE",
	"4" : "PLUS",
	"5" : "SQUARE",
	"6" : "TRIANGLE",
}

@onready var code_keyboard : CodeKeyboard = %CodeKeyboard
@onready var password_label : Label = %PasswordLabel

var password : String = ""

func _ready() -> void:
	_reset_password()
	
	OpeningCurtain.open()


func _reset_password() -> void:
	password = TeacherSettings.available_codes.pick_random()
	var password_array: = password.split("")
	password_label.text = tr("ADULT_CHECK_PROMPT").format(
		{
			"1" : tr(symbols_names[password_array[0]]),
			"2" : tr(symbols_names[password_array[1]]),
			"3" : tr(symbols_names[password_array[2]])
		}
	)


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(main_menu_scene_path)


func _on_code_keyboard_password_entered(entered_password: String) -> void:
	if password != entered_password:
		code_keyboard.reset_password()
		_reset_password()
		return
	
	await OpeningCurtain.close()
	get_tree().change_scene_to_file(register_scene_path)
