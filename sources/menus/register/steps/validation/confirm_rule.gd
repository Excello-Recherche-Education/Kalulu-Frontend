@tool
class_name ConfirmRule
extends ValidatorRule

@export_node_path("Control") var confirm_control_path: NodePath


func _init() -> void:
	fail_message = "Value must be the same in both fields."


func apply(control: Control, value: Variant) -> RuleResult:
	var result: RuleResult = RuleResult.new()
	if confirm_control_path and value is String:
		var confirm_control: Control = control.get_child(0).get_node(confirm_control_path)
		result.passed = confirm_control and Validation.find_validator(control).get_value(confirm_control) == value
	if not result.passed:
		result.message = fail_message
	return result
