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


func _on_next() -> bool:
	var register_data: TeacherSettings = data as TeacherSettings
	if not register_data:
		Log.warn("Register/StudentsCountStep: cannot continue because TeacherSettings data is missing")
		return false

	# The students already entered are kept, and only the difference is made up.
	# A code is drawn at random and cannot be recovered once replaced, so coming
	# back through this step must not silently reissue them -- the teacher may have
	# printed them already.
	var students: Array[StudentData] = []
	if register_data.students.has(device_id):
		students = register_data.students[device_id] as Array[StudentData]
	else:
		register_data.students[device_id] = students
	var requested: int = int(students_count_field.value)
	Log.trace("Register/StudentsCountStep: device %d wants %d students, has %d"
		% [device_id, requested, students.size()])

	# Trimmed before anything is drawn, so the codes of the students being dropped
	# are back in the pool and can be reused by whoever needs them next.
	while students.size() > requested:
		students.remove_at(students.size() - 1)

	codes_ran_out = false
	while students.size() < requested:
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
