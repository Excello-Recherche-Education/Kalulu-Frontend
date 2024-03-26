extends Step

func _on_next() -> bool:
	var register_data = data as TeacherSettings
	if register_data:
		if register_data.account_type == TeacherSettings.AccountType.Parent:
			register_data.education_method = TeacherSettings.EducationMethod.AppOnly
	else:
		return false
	return true
