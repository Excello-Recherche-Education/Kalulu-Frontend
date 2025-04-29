extends Step
class_name RecapStep

const device_recap_scene : PackedScene = preload("res://sources/menus/register/steps/device_recap.tscn")

@onready var recap_container : VBoxContainer = %RecapContainer
@onready var email : Label = %Email
@onready var account_type : Label = %AccountType
@onready var education_method : Label = %EducationMethod
@onready var devices_count : Label = %DevicesCount
@onready var students_count : Label = %StudentsCount

func on_enter() -> void:
	super.on_enter()
	
	var teacher_settings: TeacherSettings = data as TeacherSettings
	if not teacher_settings:
		return
	
	email.text = tr("SUMMARY_EMAIL").format({"mail" : teacher_settings.email})
	account_type.text = tr("SUMMARY_TYPE").format({"type" : tr((TeacherSettings.AccountType.keys()[teacher_settings.account_type] as String).to_upper())})
	
	if teacher_settings.account_type == TeacherSettings.AccountType.Teacher:
		education_method.text = tr("SUMMARY_METHOD").format({"method" : tr((TeacherSettings.EducationMethod.keys()[teacher_settings.education_method] as String).to_upper())})
		education_method.show()
		
		devices_count.text = tr("SUMMARY_NUMBER_OF_DEVICES").format({"number" : teacher_settings.students.size()})
		devices_count.show()
		
		students_count.text = tr("SUMMARY_NUMBER_OF_STUDENTS").format({"number" : teacher_settings.get_students_count()})
		students_count.show()
	else:
		education_method.hide()
		devices_count.hide()
		students_count.hide()
	
	for child: Node in recap_container.get_children(false):
		child.queue_free()
	
	for device: int in teacher_settings.students.keys():
		var device_recap : DeviceRecap = device_recap_scene.instantiate()
		
		if teacher_settings.account_type == TeacherSettings.AccountType.Teacher:
			device_recap.title = tr("DEVICE_NUMBER").format({"number" : device})
		else:
			device_recap.title = tr("PLAYERS")
		device_recap.students = teacher_settings.students[device]
		
		recap_container.add_child(device_recap)
