@tool
class_name Step
extends Control

signal back(step: Step)
signal next(step: Step)

@export var step_name: String
@export_multiline var question: String
@export_multiline var infos: String
@export var data: Resource

## Where the question board sits with no keyboard open, so the lift is applied
## to the scene's own position rather than to wherever it was left last time.
var question_board_offsets: Vector2 = Vector2.ZERO

@onready var question_label: Label = %QuestionLabel
@onready var info_label: Label = %InfoLabel
@onready var form_validator: FormValidator = %FormValidator
@onready var form_binder: FormBinder = %FormBinder
@onready var form_container: Control = %FormContainer
@onready var keyboard_spacer: KeyboardSpacer = $FormValidator/FormBinder/Control
@onready var question_board: Control = get_node_or_null("PanelContainer") as Control


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if question_board:
		question_board_offsets = Vector2(question_board.offset_top, question_board.offset_bottom)
	keyboard_spacer.lift_changed.connect(_on_keyboard_lift_changed)


## Keeps the question with its form when the keyboard pushes the form up.
##
## The question hangs over the field column with barely a gap, so a form lifted
## on its own slides straight under it -- trading one thing covering the fields
## for another. Moving both by the same amount slides the question off the top
## instead, which is what a phone does with everything above the field anyway.
func _on_keyboard_lift_changed(lift: float) -> void:
	if not question_board:
		return
	question_board.offset_top = question_board_offsets.x - lift
	question_board.offset_bottom = question_board_offsets.y - lift


## Turns the question board into a real card, for the steps that show one.
##
## base_step blanks that panel so a question reads straight off the background,
## and a local override beats a type variation -- so a step that sets the Card
## variation on it has to lift the override as well, or the card draws nothing.
func show_question_board_as_card() -> void:
	var board: PanelContainer = get_node_or_null("PanelContainer") as PanelContainer
	if board:
		board.remove_theme_stylebox_override("panel")


func on_enter() -> void:
	form_binder.read(data)
	question_label.text = question
	
	if infos:
		info_label.text = infos
	else:
		info_label.hide()


func _on_back() -> bool:
	return true


func _on_next() -> bool:
	return true


# Display error messages
func _on_form_validator_control_validated(control: Control, passed: bool, messages: PackedStringArray) -> void:
	var label: Label = find_child(control.name as String + "Error", true, false) as Label
	if not label:
		return
	
	if passed:
		label.hide()
	else:
		label.text = ". ".join(messages)
		label.show()


func _on_back_button_pressed() -> void:
	if _on_back():
		back.emit(self)


func _on_validate_button_pressed() -> void:
	# Validate the fields
	if not form_validator.validate():
		Log.warn("BaseStep: Validation failed (" + str(self) + ")")
		return
	
	# Writes data in object
	if not form_binder.write():
		Log.warn("BaseStep: Impossible to write data in object (" + str(self) + ")")
		return
	
	if _on_next():
		next.emit(self)
