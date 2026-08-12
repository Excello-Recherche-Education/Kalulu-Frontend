extends GutTest
## Handing out student codes.
##
## A student's code is what the child taps to log in, so the codes are a fixed
## set and an account can run out of them. Running out has to be answerable
## rather than fatal.
##
## Works on TeacherSettings resources built here, never on UserDataManager's live
## one: the manager clears and saves the device's teacher whenever it finds none,
## so borrowing it would log the real device out on disk.


func _account_with(codes: Array[int]) -> TeacherSettings:
	var settings: TeacherSettings = TeacherSettings.new()
	var students: Array[StudentData] = []
	for code: int in codes:
		var student: StudentData = StudentData.new()
		student.code = code
		students.append(student)
	settings.students[1] = students
	return settings


func test_a_fresh_account_gets_a_real_code() -> void:
	var settings: TeacherSettings = TeacherSettings.new()

	var code: int = settings.get_new_code()

	assert_has(TeacherSettings.AVAILABLE_CODES, code, "the code should be one of the real ones")
	assert_ne(code, TeacherSettings.NO_CODE_AVAILABLE)


func test_a_code_already_in_use_is_not_handed_out_again() -> void:
	# Two children with the same code could log into each other's progress.
	var taken: Array[int] = TeacherSettings.AVAILABLE_CODES.slice(1)
	var settings: TeacherSettings = _account_with(taken)

	assert_eq(settings.get_new_code(), TeacherSettings.AVAILABLE_CODES[0],
		"the one code left should be the one handed out")


func test_an_account_using_every_code_is_told_there_are_none_left() -> void:
	var settings: TeacherSettings = _account_with(TeacherSettings.AVAILABLE_CODES)

	assert_eq(settings.get_new_code(), TeacherSettings.NO_CODE_AVAILABLE)


func test_running_out_twice_over_still_answers_instead_of_crashing() -> void:
	# The crash this fixes: the guard compared how many students there were with
	# how many codes exist, and the caller stored the -1 it got back on a student.
	# That put the count past the pool's size, so the guard was skipped, the pool
	# was empty, and pick_random returned null -- which cannot come back as an int.
	var taken: Array[int] = TeacherSettings.AVAILABLE_CODES.duplicate()
	taken.append(TeacherSettings.NO_CODE_AVAILABLE)
	var settings: TeacherSettings = _account_with(taken)

	assert_eq(settings.get_new_code(), TeacherSettings.NO_CODE_AVAILABLE,
		"more students than codes should still answer, not crash")


func test_a_repeated_code_does_not_free_up_another_one() -> void:
	# erase() only drops the first match, so counting occurrences and subtracting
	# them from the pool would disagree with the pool itself.
	var taken: Array[int] = TeacherSettings.AVAILABLE_CODES.duplicate()
	taken.append(TeacherSettings.AVAILABLE_CODES[0])
	var settings: TeacherSettings = _account_with(taken)

	assert_eq(settings.get_new_code(), TeacherSettings.NO_CODE_AVAILABLE)


func test_codes_are_counted_across_every_device() -> void:
	var settings: TeacherSettings = TeacherSettings.new()
	for device: int in 3:
		var students: Array[StudentData] = []
		for code: int in TeacherSettings.AVAILABLE_CODES.slice(device * 30, device * 30 + 30):
			var student: StudentData = StudentData.new()
			student.code = code
			students.append(student)
		settings.students[device + 1] = students

	assert_eq(settings.get_number_of_students(), TeacherSettings.AVAILABLE_CODES.size())
	assert_eq(settings.get_new_code(), TeacherSettings.NO_CODE_AVAILABLE,
		"the pool is shared by the whole account, not per device")
