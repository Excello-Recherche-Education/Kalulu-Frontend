@tool
extends Control
class_name Step

signal back(step : Step)
signal next(step : Step)

@onready var question_label : Label = %QuestionLabel
@onready var info_label : Label = %InfoLabel
@onready var form_validator : FormValidator = %FormValidator
@onready var form_binder : FormBinder = %FormBinder
@onready var form_container : Control = %FormContainer

@export var step_name : String
@export_multiline var question : String
@export_multiline var infos : String
@export var data: Resource

func on_enter() -> void:
	form_binder.read(data)
	question_label.text = question
	
	if infos:
		info_label.text = infos
	else:
		info_label.visible = false

func _on_back() -> bool:
	return true


func _on_next() -> bool:
	return true

# Display error messages
func _on_form_validator_control_validated(control: ItemList, passed: bool, messages: PackedStringArray) -> void:
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
		Logger.warn("BaseStep: Validation failed (" + str(self) + ")")
		return
	
	# Writes data in object
	if not form_binder.write():
		Logger.warn("BaseStep: Impossible to write data in object (" + str(self) + ")")
		return
	
	if _on_next():
		next.emit(self)
