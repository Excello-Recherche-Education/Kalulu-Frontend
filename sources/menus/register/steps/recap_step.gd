extends Step

const device_recap_scene : PackedScene = preload("res://sources/menus/register/steps/device_recap.tscn")

@onready var recap_container = %RecapContainer
@onready var email : Label = %Email
@onready var account_type : Label = %AccountType
@onready var education_method : Label = %EducationMethod
@onready var devices_count : Label = %DevicesCount
@onready var students_count : Label = %StudentsCount


func _ready():
	super._ready()
	
	var register_data = data as TeacherSettings
	if not register_data:
		return
	
	email.text = email.text % register_data.email
	account_type.text = account_type.text % register_data.account_type
	
	if register_data.account_type == TeacherSettings.AccountType.Teacher:
		education_method.text = education_method.text % register_data.education_method
		education_method.show()
	else:
		education_method.hide()
	
	devices_count.text = devices_count.text % register_data.students.size()
	
	students_count.text = students_count.text % register_data.get_students_count()
	
	for device in register_data.students.keys():
		var device_recap : DeviceRecap = device_recap_scene.instantiate()
		
		if register_data.account_type == TeacherSettings.AccountType.Teacher:
			device_recap.title = "Device %d" % device
		else:
			device_recap.title = "Players"
		device_recap.students = register_data.students[device]
		
		
		
		recap_container.add_child(device_recap)
	
