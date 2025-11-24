@tool
extends Validator
class_name ButtonValidator


func get_value(control: Control) -> Variant:
	var button: Button = control as Button
	if not button:
		return null
	return button.button_pressed


func is_type(node: Node) -> bool:
	return node is Button
