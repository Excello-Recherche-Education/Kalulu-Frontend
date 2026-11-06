extends GutTest
## The guest account: playing without an account, and registering it later.
##
## The lifecycle tests drive the real UserDataManager, because the guest's whole point
## is where its files end up. They put this device's own sign-in back afterwards, and
## stand aside on a machine that already holds a guest -- creating one deletes it.

## An address no account can have, so the folder the registration moves the guest to
## is this test's alone.
const REGISTERED_EMAIL: String = "guest-account-test@example.invalid"

var saved_teacher: String
var saved_device_id: int
var saved_settings: TeacherSettings
## True once a test has gone ahead and may have written guest files. Only then are
## they cleaned up: a test that stood aside for a real guest must not delete it.
var touched_storage: bool = false


func before_each() -> void:
	var device: DeviceSettings = UserDataManager.get_device_settings()
	saved_teacher = device.teacher
	saved_device_id = device.device_id
	saved_settings = UserDataManager.teacher_settings
	touched_storage = false


func after_each() -> void:
	if not touched_storage:
		return
	for folder: String in [UserDataManagerClass.GUEST_FOLDER, REGISTERED_EMAIL]:
		var path: String = "user://".path_join(folder)
		if DirAccess.dir_exists_absolute(path):
			Utils.delete_directory_recursive(path)
	var device: DeviceSettings = UserDataManager.get_device_settings()
	device.teacher = saved_teacher
	device.device_id = saved_device_id
	UserDataManager._save_device_settings()
	UserDataManager.teacher_settings = saved_settings


func _guest_settings(student_count: int) -> TeacherSettings:
	var settings: TeacherSettings = TeacherSettings.new()
	settings._language = UserDataManager.get_device_settings().language
	for index: int in student_count:
		settings.add_local_student(1)
	return settings


func _skip_if_this_machine_has_a_guest() -> bool:
	if saved_teacher == UserDataManagerClass.GUEST_FOLDER or UserDataManager.guest_exists():
		pending("this machine holds a real guest account, which these tests would delete")
		return true
	touched_storage = true
	return false


# --- Settings ----------------------------------------------------------------

func test_local_students_get_distinct_codes() -> void:
	var settings: TeacherSettings = _guest_settings(30)
	var codes: Dictionary = {}
	for student: StudentData in settings.get_all_students_data():
		assert_true(student.code in TeacherSettings.AVAILABLE_CODES, "a real code")
		codes[student.code] = true
	assert_eq(codes.size(), 30, "no two students share a code")


func test_local_students_stop_when_the_codes_run_out() -> void:
	var settings: TeacherSettings = _guest_settings(TeacherSettings.AVAILABLE_CODES.size())
	assert_null(settings.add_local_student(1), "the pool is empty")
	assert_eq(settings.get_number_of_students(), TeacherSettings.AVAILABLE_CODES.size())


func test_a_local_student_can_open_a_new_device() -> void:
	var settings: TeacherSettings = _guest_settings(1)
	settings.add_local_student(2)
	assert_eq(settings.students.keys().size(), 2)


func test_a_detached_copy_shares_no_student() -> void:
	# The registration wizard edits a copy; backing out must leave the guest as it was.
	var settings: TeacherSettings = _guest_settings(2)
	settings.is_guest = true
	var copy: TeacherSettings = settings.detached_copy()

	copy.get_all_students_data()[0].name = "Changed"
	copy.account_type = TeacherSettings.AccountType.PARENT
	copy.add_local_student(1)

	assert_eq(settings.get_all_students_data()[0].name, "")
	assert_eq(settings.account_type, TeacherSettings.AccountType.TEACHER)
	assert_eq(settings.get_number_of_students(), 2)
	assert_true(copy.is_guest, "the copy keeps what it was copied from")
	assert_eq(copy.get_all_students_data()[1].code, settings.get_all_students_data()[1].code)


# --- Entry flow and pack -----------------------------------------------------

func test_a_guest_is_signed_in_without_a_token() -> void:
	var settings: TeacherSettings = TeacherSettings.new()
	settings.is_guest = true
	assert_true(EntryFlow.is_signed_in(settings), "a guest opens straight onto its account")


func test_a_guest_pack_refusal_does_not_sign_it_out() -> void:
	assert_eq(PackageDownloader.outcome_for_pack_url(401, true),
			PackageDownloader.PackUrlOutcome.FAILED,
			"a guest sends no token, so a 401 cannot be about its account")
	assert_eq(PackageDownloader.outcome_for_pack_url(401, false),
			PackageDownloader.PackUrlOutcome.SIGN_OUT,
			"an account's 401 still signs it out")
	assert_eq(PackageDownloader.outcome_for_pack_url(200, true),
			PackageDownloader.PackUrlOutcome.USE)


# --- Lifecycle ---------------------------------------------------------------

func test_creating_a_guest_signs_it_in_on_its_only_device() -> void:
	if _skip_if_this_machine_has_a_guest():
		return
	assert_true(UserDataManager.create_guest(_guest_settings(3)))

	assert_true(UserDataManager.is_guest())
	assert_true(UserDataManager.guest_exists())
	assert_true(EntryFlow.has_connection_token(), "the device opens onto the guest")
	assert_false(EntryFlow.has_server_session(), "no server has heard of it")
	assert_eq(UserDataManager.get_device_settings().teacher, UserDataManagerClass.GUEST_FOLDER)
	assert_eq(UserDataManager.get_device_settings().device_id, 1,
			"one device, so no device selection")
	assert_true(UserDataManager.teacher_settings.token.is_empty())


func test_a_guest_signed_out_can_be_resumed_as_it_was() -> void:
	if _skip_if_this_machine_has_a_guest():
		return
	UserDataManager.create_guest(_guest_settings(2))
	var codes: Array[int] = []
	for student: StudentData in UserDataManager.teacher_settings.get_all_students_data():
		codes.append(student.code)
	UserDataManager.logout()
	assert_false(UserDataManager.is_guest())

	assert_true(UserDataManager.resume_guest())

	assert_true(UserDataManager.is_guest())
	var resumed: Array[int] = []
	for student: StudentData in UserDataManager.teacher_settings.get_all_students_data():
		resumed.append(student.code)
	assert_eq(resumed, codes, "the same students, with the same codes")
	assert_eq(UserDataManager.get_device_settings().device_id, 1)


func test_a_guest_adds_and_removes_students_on_its_own() -> void:
	if _skip_if_this_machine_has_a_guest():
		return
	UserDataManager.create_guest(_guest_settings(1))
	var added: StudentData = UserDataManager.add_guest_student(1)
	assert_not_null(added)
	assert_eq(UserDataManager.get_number_of_students(), 2)

	UserDataManager.remove_guest_student(added.code)
	assert_eq(UserDataManager.get_number_of_students(), 1)


func test_resetting_a_guest_erases_progress_but_keeps_its_students() -> void:
	# A change of language does to a guest what /reset_language does to an account:
	# the server keeps one progression per student, so a guest cannot keep two.
	if _skip_if_this_machine_has_a_guest():
		return
	UserDataManager.create_guest(_guest_settings(2))
	var codes: Array[int] = []
	for student: StudentData in UserDataManager.teacher_settings.get_all_students_data():
		codes.append(student.code)
	var saves: Array[String] = []
	for language: String in ["fr_FR", "es_AR"]:
		var path: String = "user://".path_join(UserDataManagerClass.GUEST_FOLDER) \
				.path_join("1").path_join(language).path_join(str(codes[0])).path_join("progression.tres")
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		assert_eq(ResourceSaver.save(StudentProgression.new(), path), OK)
		saves.append(path)

	UserDataManager.reset_guest_progress()

	for path: String in saves:
		assert_false(FileAccess.file_exists(path), "%s is erased" % path)
	assert_true(UserDataManager.guest_exists(), "the account itself stays")
	var kept: Array[int] = []
	for student: StudentData in UserDataManager.teacher_settings.get_all_students_data():
		kept.append(student.code)
	assert_eq(kept, codes, "the same students, with the same codes")
	var saved: TeacherSettings = load(UserDataManager.get_teacher_settings_path()) as TeacherSettings
	assert_eq(saved.get_number_of_students(), 2, "and on disk too")
	for tracked_error: GutTrackedError in get_errors():
		tracked_error.handled = true


func test_registering_moves_everything_and_clears_the_guest() -> void:
	if _skip_if_this_machine_has_a_guest():
		return
	UserDataManager.create_guest(_guest_settings(1))
	var code: int = UserDataManager.teacher_settings.get_all_students_data()[0].code
	# Something a child played, so there is progress to carry over.
	var progression_path: String = UserDataManager.get_student_progression_path(1, code)
	DirAccess.make_dir_recursive_absolute(progression_path.get_base_dir())
	assert_eq(ResourceSaver.save(StudentProgression.new(), progression_path), OK)

	var registered: TeacherSettings = UserDataManager.teacher_settings.detached_copy()
	registered.email = REGISTERED_EMAIL
	registered.token = "a-token"
	assert_true(UserDataManager.register_guest(registered))

	assert_false(UserDataManager.is_guest())
	assert_false(UserDataManager.guest_exists(), "Continue as guest starts afresh")
	assert_false(DirAccess.dir_exists_absolute("user://".path_join(UserDataManagerClass.GUEST_FOLDER)))
	assert_eq(UserDataManager.get_device_settings().teacher, REGISTERED_EMAIL)
	assert_true(EntryFlow.has_server_session())
	assert_true(FileAccess.file_exists(UserDataManager.get_student_progression_path(1, code)),
			"the progress is under the account now")
	assert_true(FileAccess.file_exists(UserDataManager.get_teacher_settings_path()))
	var saved: TeacherSettings = load(UserDataManager.get_teacher_settings_path()) as TeacherSettings
	assert_false(saved.is_guest, "the account on disk is no longer a guest")
	assert_eq(saved.token, "a-token")


func test_registering_needs_a_token() -> void:
	if _skip_if_this_machine_has_a_guest():
		return
	UserDataManager.create_guest(_guest_settings(1))
	var registered: TeacherSettings = UserDataManager.teacher_settings.detached_copy()
	registered.email = REGISTERED_EMAIL

	assert_false(UserDataManager.register_guest(registered))
	assert_true(UserDataManager.is_guest(), "nothing moved")
	assert_true(UserDataManager.guest_exists())
	for tracked_error: GutTrackedError in get_errors():
		tracked_error.handled = true
