@tool
extends Control
class_name Step

signal completed

const checked_properties := [
	"value",
	"text"
]

@onready var question_label : Label = %QuestionLabel
@onready var form_validator : FormValidator = %FormValidator
@onready var form_container : Control = %FormContainer

@export var question_txt : String
@export var object : Resource

func _ready():
	if question_txt:
		question_label.text = question_txt
	
	_fill_form()


func _fill_form():
	if not object:
		return
	
	for node in form_container.get_children(false):
		if node.name in object:
			for property_name in checked_properties:
				if property_name in node:
					node.set(property_name, object.get(node.name))
		else:
			push_warning("Property not found in object for node: " + node.name + ". All nodes inside FormContainer must reflects a property from the resource.")


func _write_object() -> bool:
	if not object:
		return false
	
	for node in form_container.get_children(false):
		var value
		if node.name in object:
			for property_name in checked_properties:
				if property_name in node:
					value = node.get(property_name)
			
			if value:
				object.set(node.name, value)
			else:
				return false
			
	return true


func _on_validate_button_pressed():
	
	print(form_validator.validate())
	
	# Writes data in object
	if _write_object():
		# Emit completed signal
		emit_signal("completed")
	else:
		# TODO Show error message
		print("Please fill all the fields")
