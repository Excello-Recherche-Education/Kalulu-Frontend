@tool
extends Control
class_name Step

signal back(step : Step)
signal next(step : Step)

@onready var question_label : Label = %QuestionLabel
@onready var form_validator : FormValidator = %FormValidator
@onready var form_binder : FormBinder = %FormBinder
@onready var form_container : Control = %FormContainer

@export var step_name : String
@export_multiline var question : String
@export var data : Resource

func _ready():
	form_binder.read(data)
	question_label.text = question


func _on_back() -> bool:
	return true


func _on_next() -> bool:
	return true

# Display error messages
func _on_form_validator_control_validated(control, passed, messages):
	var label = find_child(control.name + "Error", true, false) as Label
	if not label:
		return
	
	if passed:
		label.hide()
	else:
		label.text = ". ".join(messages)
		label.show()


func _on_back_button_pressed():
	if _on_back():
		back.emit(self)


func _on_validate_button_pressed():
	# Validate the fields
	if not form_validator.validate():
		push_warning("Validation failed (" + str(self) + ")")
		return
	
	# Writes data in object
	if not form_binder.write():
		push_warning("Impossible to write data in object (" + str(self) + ")")
		return
	
	if _on_next():
		next.emit(self)
