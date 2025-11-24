@tool
class_name NotBlankRule
extends ValidatorRule


func _init() -> void:
	fail_message = "Value must not be blank."


func apply(control: Control, value: Variant) -> RuleResult:
	var result: RuleResult = RuleResult.new()
	if value is String:
		result.passed = ValidatorFunctions.not_blank(value)
	if not result.passed:
		result.message = fail_message
	return result
