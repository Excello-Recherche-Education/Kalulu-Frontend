@tool
class_name Step
extends Control

signal back(step: Step)
signal next(step: Step)

@export var step_name: String
@export_multiline var question: String
@export_multiline var infos: String
@export var data: Resource

@onready var question_label: Label = %QuestionLabel
@onready var info_label: Label = %InfoLabel
@onready var form_validator: FormValidator = %FormValidator
@onready var form_binder: FormBinder = %FormBinder
@onready var form_container: Control = %FormContainer


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
