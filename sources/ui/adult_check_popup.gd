class_name AdultCheckPopup
extends CanvasLayer
## Asks whoever is holding the device to prove they are an adult, then gets out
## of the way.
##
## The instruction names three symbols to tap. A child young enough to be playing
## cannot read it, which is the whole gate -- so unlike a password there is
## nothing to remember and nothing to enter unseen.
##
## A wrong answer asks again with different symbols rather than saying no, so
## there is nothing to learn by guessing.

signal passed()
signal cancelled()

var challenge: AdultChallenge = AdultChallenge.new()

@onready var prompt_label: Label = %Prompt
@onready var keypad: CodeKeypad = %Keypad
@onready var close_button: TextureButton = %CloseButton


func _ready() -> void:
	# The cross is drawn from a white icon so it can be tinted per surface; on the
	# dialog's white card it takes the brand navy.
	close_button.self_modulate = Design.NAVY
	keypad.code_entered.connect(_on_code_entered)
	close_button.pressed.connect(_on_close_pressed)
	hide()
	_ask()


## Opens the dialog on a challenge nobody has seen yet.
func open() -> void:
	_ask()
	show()


func _ask() -> void:
	challenge.renew()
	prompt_label.text = challenge.prompt("ADULT_CHECK_PROMPT")
	if is_node_ready():
		keypad.clear()


func _on_code_entered(code: String) -> void:
	if not challenge.accepts(code):
		Log.info("AdultCheckPopup: Wrong answer, asking again")
		_ask()
		return
	Log.info("AdultCheckPopup: Passed")
	hide()
	passed.emit()


func _on_close_pressed() -> void:
	hide()
	cancelled.emit()
