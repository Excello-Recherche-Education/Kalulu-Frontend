class_name AdultBlock
extends Control

signal unlocked()

var challenge: AdultChallenge = AdultChallenge.new()

@onready var code_keyboard: CodeKeyboard = %CodeKeyboard
@onready var password_label: Label = %PasswordLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_reset_password()


func _reset_password() -> void:
	challenge.renew()
	password_label.text = challenge.prompt("ADULT_BOSS_BLOCK_PROMPT")


func _on_code_keyboard_password_entered(entered_password: String) -> void:
	if not challenge.accepts(entered_password):
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
