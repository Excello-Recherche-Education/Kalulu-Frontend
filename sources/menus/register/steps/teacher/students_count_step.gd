@tool
class_name StudentsCountStep
extends Step

@export var device_id: int

## True when the codes ran out before this device had every student asked for.
##
## The wizard reads it to explain what happened and to drop the devices after
## this one, which have nothing left to give their students either.
var codes_ran_out: bool = false

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
	if not register_data:
		Log.warn("Register/StudentsCountStep: cannot continue because TeacherSettings data is missing")
		return false

	var students: Array[StudentData] = []
	register_data.students[device_id] = students
	var requested: int = int(students_count_field.value)
	Log.trace("Register/StudentsCountStep: creating %d students for device %d" % [requested, device_id])

	codes_ran_out = false
	for _student: int in requested:
		var code: int = register_data.get_new_code()
		if code == TeacherSettings.NO_CODE_AVAILABLE:
			# Keep the students that did get a code rather than failing the step.
			# The codes are one fixed set for the whole account, so refusing to
			# move on would only strand the teacher here: trying again runs out in
			# exactly the same place.
			codes_ran_out = true
			break
		var student_data: StudentData = StudentData.new()
		student_data.code = code
		students.append(student_data)

	if codes_ran_out:
		Log.warn("Register/StudentsCountStep: ran out of student codes on device %d, created %d of %d"
			% [device_id, students.size(), requested])
	Log.info("Register/StudentsCountStep: generated %d students for device %d" % [students.size(), device_id])
	return true 
