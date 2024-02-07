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
	elif control is ItemList:
		var selected_indexes = control.get_selected_items()
		if not selected_indexes or selected_indexes.size() == 0:
			return null
		if control.select_mode == ItemList.SELECT_SINGLE:
			return selected_indexes[0]
		return selected_indexes
			
	return null


func set_value(value):
	if not control:
		return
		
	if control is Range:
		if value is float:
			control.value = value
		elif value is int:
			control.value = float(value)
	elif control is LineEdit or control is TextEdit:
		control.text = str(value)
	elif control is ItemList:
		if value is int:
			control.select(value, true)
