@tool
class_name AlphanumericRule
extends ValidatorRule


func _init() -> void:
	fail_message = "Value must contain only alphanumeric characters."


func apply(control: Control, value) -> RuleResult:
	var result = RuleResult.new()
	if value is String:
		result.passed = ValidatorFunctions.empty(value) or ValidatorFunctions.alphanumeric(value)
	if not result.passed:
		result.message = fail_message
	return result
