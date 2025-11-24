@tool
extends ValidatorRule
class_name AlphaRule


func _init() -> void:
	fail_message = "Value must contain only alpha characters."


func apply(control: Control, value: Variant) -> RuleResult:
	var result: RuleResult = RuleResult.new()
	if value is String:
		result.passed = ValidatorFunctions.empty(value) or ValidatorFunctions.alpha(value)
	if not result.passed:
		result.message = fail_message
	return result
