@tool
class_name StudentsCountStep
extends Step

@export var device_id: int

@onready var students_count_field: SpinBox = %StudentsCountField


func _on_back() -> bool:
	var register_data: TeacherSettings = data as TeacherSettings
	if register_data:
		Log.trace("Register/StudentsCountStep: removing students for device %d" % device_id)
		register_data.students.erase(device_id)
		return true
	Log.warn("Register/StudentsCountStep: cannot go back because TeacherSettings data is missing")
	return false


func _on_next() -> bool:
	var register_data: TeacherSettings = data as TeacherSettings
	if register_data:
		var students: Array[StudentData] = []
		register_data.students[device_id] = students
		Log.trace("Register/StudentsCountStep: creating %d students for device %d" % [int(students_count_field.value), device_id])
		for _student: int in students_count_field.value:
			var student_data: StudentData = StudentData.new()
			student_data.code = register_data.get_new_code()
			if student_data.code:
				students.append(student_data)
			else:
				Log.error("Register/StudentsCountStep: failed to generate a student code for device %d" % device_id)
				return false
		Log.info("Register/StudentsCountStep: generated %d students for device %d" % [students.size(), device_id])
		return true
	Log.warn("Register/StudentsCountStep: cannot continue because TeacherSettings data is missing")
	return false 
