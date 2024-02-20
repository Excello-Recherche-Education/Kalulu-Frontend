extends Step

const device_recap_scene : PackedScene = preload("res://sources/menus/register/steps/device_recap.tscn")

@onready var recap_container : VBoxContainer = %RecapContainer
@onready var email : Label = %Email
@onready var account_type : Label = %AccountType
@onready var education_method : Label = %EducationMethod
@onready var devices_count : Label = %DevicesCount
@onready var students_count : Label = %StudentsCount

func on_enter():
	var teacher_settings = data as TeacherSettings
	if not teacher_settings:
		return
	
	email.text = "Email address : %s" % teacher_settings.email
	account_type.text = "Account type : %s" % TeacherSettings.AccountType.keys()[teacher_settings.account_type]
	
	if teacher_settings.account_type == TeacherSettings.AccountType.Teacher:
		education_method.text = "Education method : %s" % TeacherSettings.EducationMethod.keys()[teacher_settings.education_method]
		education_method.show()
	else:
		education_method.hide()
	
	devices_count.text = "Number of devices : %d" % teacher_settings.students.size()
	
	students_count.text = "Number of students : %d" % teacher_settings.get_students_count()
	
	for child in recap_container.get_children(false):
		child.queue_free()
	
	for device in teacher_settings.students.keys():
		var device_recap : DeviceRecap = device_recap_scene.instantiate()
		
		if teacher_settings.account_type == TeacherSettings.AccountType.Teacher:
			device_recap.title = "Device %d" % device
		else:
			device_recap.title = "Players"
		device_recap.students = teacher_settings.students[device]
		
		recap_container.add_child(device_recap)
