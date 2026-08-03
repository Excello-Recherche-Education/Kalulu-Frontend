@tool
class_name OptionButtonValidator
extends Validator
## Reads the chosen index out of an OptionButton, for the wizard's pickers.
##
## An OptionButton is a Button underneath, so ButtonValidator would match it by
## type and report whether it is held down. What a picker is worth validating on
## is whether anything has been chosen at all, which is what -1 means.


func get_value(control: Control) -> Variant:
	var picker: OptionButton = control as OptionButton
	if not picker:
		return null

	# Null rather than -1: RequiredRule only counts null as missing, and index 0
	# is a perfectly good answer.
	if picker.selected < 0:
		return null
	return picker.selected


func is_type(node: Node) -> bool:
	return node is OptionButton
