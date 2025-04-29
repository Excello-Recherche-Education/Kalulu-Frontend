extends Step
class_name StudentsCountStep

@export var device_id : int
@onready var students_count_field: SpinBox = %StudentsCountField

func _on_back() -> bool:
	var register_data: TeacherSettings = data as TeacherSettings
	if register_data:
		register_data.students.erase(device_id)
		return true
	return false


func _on_next() -> bool:
	var register_data: TeacherSettings = data as TeacherSettings
	if register_data:
		var students: Array[StudentData] = []
		register_data.students[device_id] = students
		for _student: int in students_count_field.value:
			var student_data: StudentData = StudentData.new()
			student_data.code = int(register_data.get_new_code())
			if student_data.code:
				students.append(student_data)
			else:
				return false
		
		return true
	return false 
