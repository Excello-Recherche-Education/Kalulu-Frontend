extends Control

const MAIN_MENU_SCENE_PATH: String = "res://sources/menus/main/main_menu.tscn"
const REGISTER_SCENE_PATH: String = "res://sources/menus/register/register.tscn"
const SYMBOLS_NAMES: Dictionary[String, String] = {
	"1" : "STAR",
	"2" : "BAR",
	"3" : "CIRCLE",
	"4" : "PLUS",
	"5" : "SQUARE",
	"6" : "TRIANGLE",
}

@onready var code_keyboard : CodeKeyboard = %CodeKeyboard
@onready var password_label : Label = %PasswordLabel

var password: String = ""

func _ready() -> void:
	_reset_password()
	
	OpeningCurtain.open()


func _reset_password() -> void:
	password = str(TeacherSettings.AVAILABLE_CODES.pick_random())
	var password_array: PackedStringArray = password.split("")
	password_label.text = tr("ADULT_CHECK_PROMPT").format(
		{
			"1" : tr(SYMBOLS_NAMES[password_array[0]]),
			"2" : tr(SYMBOLS_NAMES[password_array[1]]),
			"3" : tr(SYMBOLS_NAMES[password_array[2]])
		}
	)


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _on_code_keyboard_password_entered(entered_password: String) -> void:
	if password != entered_password:
		code_keyboard.reset_password()
		_reset_password()
		return
	
	await OpeningCurtain.close()
	get_tree().change_scene_to_file(REGISTER_SCENE_PATH)
