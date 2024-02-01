@tool
extends Control
class_name ControlBinder

@export var property_name : String

var control : Control

func _ready():
	control = get_parent()


func get_value():
	if not control:
		return null
	
	if control is Range:
		return control.value
	elif control is LineEdit or control is TextEdit:
		return control.text
			
	return null


func set_value(value):
	
	print("Writing " + str(value) + " in " + str(self.owner))
	
	if not control:
		return
		
	if control is Range:
		control.value = float(value)
	elif control is LineEdit or control is TextEdit:
		control.text = str(value)
