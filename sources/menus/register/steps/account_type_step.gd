@tool
extends Step

@onready var type: OptionButton = %TypeSelect


func _ready() -> void:
	type.clear()
	type.add_item("TEACHER")
	type.add_item("PARENT")
	# add_item selects the first entry it adds, which would replace the
	# placeholder with an answer the user has not given. on_enter picks the
	# saved one straight after, so nothing is lost by clearing it here.
	type.selected = -1
	type.text = "ACCOUNT_TYPE"
	Log.trace("Register/AccountTypeStep: options initialized")


func _on_next() -> bool:
	var register_data: TeacherSettings = data as TeacherSettings
	if register_data:
		if register_data.account_type == TeacherSettings.AccountType.PARENT:
			register_data.education_method = TeacherSettings.EducationMethod.APP_ONLY
		Log.info("Register/AccountTypeStep: selected account type = %s" % TeacherSettings.AccountType.keys()[register_data.account_type])
	else:
		Log.warn("Register/AccountTypeStep: cannot continue because TeacherSettings data is missing")
		return false
	return true
