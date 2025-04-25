@tool
extends Validator
class_name ItemListValidator


func get_value(control: Control) -> void:
	var item_list = control as ItemList
	if not item_list:
		return null
		
	var selected_indexes = item_list.get_selected_items()
	
	if not selected_indexes or selected_indexes.size() == 0:
		return null
	
	if item_list.select_mode == ItemList.SELECT_SINGLE:
		return selected_indexes[0]
	return selected_indexes


func is_type(node) -> bool:
	return node is ItemList
