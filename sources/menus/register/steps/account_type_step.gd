@tool
extends Step

@onready var type: ItemList = %TypeSelect

func _ready() -> void:
	type.add_item(tr("TEACHER"))
	type.add_item(tr("PARENT"))


func _on_next() -> bool:
	var register_data: TeacherSettings = data as TeacherSettings
	if register_data:
		if register_data.account_type == TeacherSettings.AccountType.Parent:
			register_data.education_method = TeacherSettings.EducationMethod.AppOnly
	else:
		return false
	return true
