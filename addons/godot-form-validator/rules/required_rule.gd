@tool
extends ValidatorRule
class_name RequiredRule


func _init() -> void:
	fail_message = tr("VALUE_REQUIRED")


func apply(control: Control, value: Variant) -> RuleResult:
	var result: RuleResult = RuleResult.new()
	if value is String:
		result.passed = ValidatorFunctions.not_blank(value)
	else:
		result.passed = value != null
	if not result.passed:
		result.message = fail_message
	return result
