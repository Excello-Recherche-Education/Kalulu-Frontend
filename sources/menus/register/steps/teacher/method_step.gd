@tool
extends Step

@onready var method: OptionButton = %MethodSelect


func _ready() -> void:
	method.clear()
	method.add_item("METHOD_APP_ONLY")
	method.add_item("METHOD_COMPLETE")
	# add_item selects the first entry it adds; the placeholder has to survive
	# until on_enter reads the saved answer back.
	method.selected = -1
	method.text = "EDUCATION_METHOD"


func _on_next() -> bool:
	var register_data: TeacherSettings = data as TeacherSettings
	if register_data:
		if register_data.account_type == TeacherSettings.AccountType.PARENT:
			register_data.education_method = TeacherSettings.EducationMethod.APP_ONLY
	else:
		return false
	return true
