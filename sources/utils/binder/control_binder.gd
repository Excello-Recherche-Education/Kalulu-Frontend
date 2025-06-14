@tool
extends Control
class_name ControlBinder

@export var property_name : String

var control: Control

func _ready() -> void:
	control = get_parent()


func get_value() -> Variant:
	if not control:
		return null
	
	if control is Range:
		return (control as Range).value
	elif control is LineEdit:
		return (control as LineEdit).text
	elif control is TextEdit:
		return (control as TextEdit).text
	elif control is ItemList:
		var selected_indexes: PackedInt32Array = (control as ItemList).get_selected_items()
		if not selected_indexes or selected_indexes.size() == 0:
			return null
		if (control as ItemList).select_mode == ItemList.SELECT_SINGLE:
			return selected_indexes[0]
		return selected_indexes
			
	return null


func set_value(value: Variant) -> void:
	if not control:
		return
		
	if control is Range:
		if value is float:
			(control as Range).value = value
		elif value is int:
			(control as Range).value = float(value as int)
	elif control is LineEdit:
		(control as LineEdit).text = str(value)
	elif control is TextEdit:
		(control as TextEdit).text = str(value)
	elif control is ItemList:
		if value is int:
			(control as ItemList).select(value as int, true)
