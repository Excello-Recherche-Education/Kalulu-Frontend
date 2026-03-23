class_name AdultBlock
extends Control

signal unlocked()

const SYMBOLS_NAMES: Dictionary[String, String] = {
	"1": "STAR",
	"2": "BAR",
	"3": "CIRCLE",
	"4": "PLUS",
	"5": "SQUARE",
	"6": "TRIANGLE",
}

var password: String = ""

@onready var code_keyboard: CodeKeyboard = %CodeKeyboard
@onready var password_label: Label = %PasswordLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_reset_password()


func _reset_password() -> void:
	password = str(TeacherSettings.AVAILABLE_CODES.pick_random())
	var password_array: PackedStringArray = password.split("")
	password_label.text = tr("ADULT_BOSS_BLOCK_PROMPT").format(
		{
			"1": tr(SYMBOLS_NAMES[password_array[0]]),
			"2": tr(SYMBOLS_NAMES[password_array[1]]),
			"3": tr(SYMBOLS_NAMES[password_array[2]])
		}
	)


func _on_code_keyboard_password_entered(entered_password: String) -> void:
	if password != entered_password:
		code_keyboard.reset_password()
		_reset_password()
		return
	
	if UserDataManager.student_progression:
		UserDataManager.student_progression.clear_boss_block()
	
	get_tree().paused = false
	hide()
	unlocked.emit()


func show_block() -> void:
	get_tree().paused = true
	code_keyboard.reset_password()
	_reset_password()
	show()
