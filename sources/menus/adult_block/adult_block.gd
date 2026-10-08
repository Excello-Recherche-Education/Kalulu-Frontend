class_name AdultBlock
extends Control
## Stops the game after too many failed boss attempts, until an adult steps in.
##
## Asked through the same AdultCheckPopup as the way into the teacher settings,
## with its own wording -- it tells the adult why the game stopped and what to do
## about it -- and without the cross: closing it would be the way past.

signal unlocked()

## The prompt column for this wording. It is a paragraph rather than a one-line
## heading, and set as a heading in the dialog's usual column it runs the card off
## the top and bottom of the screen; body text over a wider column keeps the card
## on screen in every interface language.
const PROMPT_WIDTH: float = 2100.0
const PROMPT_VARIATION: StringName = &"CardBody"

@onready var adult_check: AdultCheckPopup = %AdultCheck


func _ready() -> void:
	# The block pauses the game, and the keypad has to keep answering meanwhile.
	process_mode = Node.PROCESS_MODE_ALWAYS
	adult_check.prompt_label.theme_type_variation = PROMPT_VARIATION
	adult_check.prompt_label.custom_minimum_size.x = PROMPT_WIDTH
	adult_check.passed.connect(_on_adult_check_passed)
	hide()


func show_block() -> void:
	get_tree().paused = true
	show()
	adult_check.open()


func _on_adult_check_passed() -> void:
	if UserDataManager.student_progression:
		UserDataManager.student_progression.clear_boss_block()

	get_tree().paused = false
	hide()
	unlocked.emit()
