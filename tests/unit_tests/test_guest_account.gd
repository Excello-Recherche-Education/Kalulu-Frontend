extends GutTest
## The guest account: playing without an account, and registering it later.
##
## The lifecycle tests drive the real UserDataManager, because the guest's whole point
## is where its files end up. They put this device's own sign-in back afterwards, and
## stand aside on a machine that already holds a guest -- creating one deletes it.
##
## A run killed half-way would skip that restore, leaving the developer's install
## signed into a test guest -- and every later run standing aside for it as if it
## were real. So a test that writes first leaves a note of what it found, and the
## next run that sees the note puts it back before doing anything else.

## An address no account can have, so the folder the registration moves the guest to
## is this test's alone.
const REGISTERED_EMAIL: String = "guest-account-test@example.invalid"
## Written before a test touches storage, removed once it has put things back.
const RUN_NOTE: String = "user://gut_guest_account_test.cfg"

var saved_teacher: String
var saved_device_id: int
var saved_settings: TeacherSettings
## The set-aside guests already on this machine, so only a test's own are cleaned up.
var existing_aside: PackedStringArray = []
## True once a test has gone ahead and may have written guest files. Only then are
## they cleaned up: a test that stood aside for a real guest must not delete it.
var touched_storage: bool = false


func before_each() -> void:
	_recover_from_an_interrupted_run()
	var device: DeviceSettings = UserDataManager.get_device_settings()
	saved_teacher = device.teacher
	saved_device_id = device.device_id
	saved_settings = UserDataManager.teacher_settings
	existing_aside = _aside_folders()
	touched_storage = false


func after_each() -> void:
	if not touched_storage:
		return
	_restore(saved_teacher, saved_device_id)
	UserDataManager.teacher_settings = saved_settings


## Deletes the test's folders and points the device back at what it had.
func _restore(teacher: String, device_id: int) -> void:
	for folder: String in [UserDataManagerClass.GUEST_FOLDER, REGISTERED_EMAIL]:
		var path: String = "user://".path_join(folder)
		if DirAccess.dir_exists_absolute(path):
			Utils.delete_directory_recursive(path)
	for aside: String in _aside_folders():
		if not aside in existing_aside:
			Utils.delete_directory_recursive("user://".path_join(aside))
	var device: DeviceSettings = UserDataManager.get_device_settings()
	device.teacher = teacher
	device.device_id = device_id
	device.pending_account = ""
	UserDataManager._save_device_settings()
	DirAccess.remove_absolute(RUN_NOTE)


## The folders set aside on this machine: unreadable guests, and account folders that
## were in a registered guest's way.
func _aside_folders() -> PackedStringArray:
	var found: PackedStringArray = []
	for folder: String in DirAccess.get_directories_at("user://"):
		if folder.begins_with(UserDataManagerClass.GUEST_FOLDER + "_unreadable_") \
				or folder.begins_with(REGISTERED_EMAIL + "_previous_"):
			found.append(folder)
	return found


## Puts back what a run killed half-way left behind, if the note says one was.
func _recover_from_an_interrupted_run() -> void:
	if not FileAccess.file_exists(RUN_NOTE):
		# No note, but the device pointing at this test's own address is debris all the
		# same -- it ends in .invalid, so no real account can have it. A run whose
		# setup failed before it could write the note leaves exactly this.
		if UserDataManager.get_device_settings().teacher == REGISTERED_EMAIL:
			gut.p("This device was left on the test account; signing it out")
			_restore("", 0)
			UserDataManager.teacher_settings = null
		return
	var note: ConfigFile = ConfigFile.new()
	note.load(RUN_NOTE)
	var teacher: String = str(note.get_value("device", "teacher", ""))
	var device_id: int = int(note.get_value("device", "device_id", 0))
	gut.p("A previous run of these tests was interrupted; restoring this device")
	_restore(teacher, device_id)
	UserDataManager.teacher_settings = null
	if not teacher.is_empty():
		UserDataManager._load_teacher_settings()


## Records what this device had, before a test changes it.
func _write_run_note() -> void:
	var note: ConfigFile = ConfigFile.new()
	note.set_value("device", "teacher", saved_teacher)
	note.set_value("device", "device_id", saved_device_id)
	note.save(RUN_NOTE)


func _guest_settings(student_count: int) -> TeacherSettings:
	var settings: TeacherSettings = TeacherSettings.new()
	settings._language = UserDataManager.get_device_settings().language
	for index: int in student_count:
		settings.add_local_student(1)
	return settings


func _skip_if_this_machine_has_a_guest() -> bool:
	if saved_teacher == UserDataManagerClass.GUEST_FOLDER or UserDataManager.guest_exists() \
			or not UserDataManager.get_device_settings().pending_account.is_empty():
		pending("this machine holds a real guest account, which these tests would delete")
		return true
	touched_storage = true
	_write_run_note()
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
	settings.registering_as = "noted@example.invalid"
	assert_eq(settings.detached_copy().registering_as, "noted@example.invalid",
			"a field added later comes along without anyone listing it")
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


func test_a_busy_server_is_told_apart_from_a_broken_one() -> void:
	# The backend answers an anonymous caller over its limit with 429: a wait, not a
	# fault. A 503 stays the server's failure.
	assert_eq(PackageDownloader.outcome_for_pack_url(429, true),
			PackageDownloader.PackUrlOutcome.BUSY)
	for code: int in [500, 503]:
		assert_eq(PackageDownloader.outcome_for_pack_url(code, true),
				PackageDownloader.PackUrlOutcome.FAILED, str(code))
	assert_eq(PackageDownloader.ERROR_MESSAGES.size(), PackageDownloader.DownloadError.size(),
			"every error has its message")


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
		_write(path, "progress")
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


func test_a_guest_plays_in_its_own_language() -> void:
	# The welcome screen's language field changes the device language; a guest
	# resumed afterwards must stay on its own, not switch silently onto blank progress.
	var languages: Array = Utils.SUPPORTED_LOCALES.keys()
	assert_eq(LanguageCheck.language_for_guest(languages[0]), languages[0])
	assert_eq(LanguageCheck.language_for_guest("xx_XX"), "",
			"a language Kalulu does not have leaves it to the device's")


func test_a_guest_keeps_its_last_student() -> void:
	# With none, the tablet has no device to sign in on and the server refuses to
	# register the account.
	if _skip_if_this_machine_has_a_guest():
		return
	UserDataManager.create_guest(_guest_settings(1))
	var only: int = UserDataManager.teacher_settings.get_all_students_data()[0].code

	assert_false(UserDataManager.remove_guest_student(only))
	assert_eq(UserDataManager.get_number_of_students(), 1)


func test_a_guest_request_to_an_account_route_never_leaves() -> void:
	if _skip_if_this_machine_has_a_guest():
		return
	UserDataManager.create_guest(_guest_settings(1))
	var server: ServerManagerClass = ServerManager as ServerManagerClass

	var res: Dictionary = await server.pull_timestamps()

	assert_eq(res.code, ServerManagerClass.GUEST_REFUSED_CODE, "refused here, not a 401 from the server")
	assert_false(server._refused_for_guest("language"), "the pack needs no account")
	assert_false(server._refused_for_guest("register"), "nor does registering")
	assert_false(server._refused_for_guest("checkemail"))
	for tracked_error: GutTrackedError in get_errors():
		tracked_error.handled = true


func test_an_unfinished_copy_is_finished_where_the_rename_is_refused() -> void:
	# The fallback of the registration's move: an unfinished copy of its own is in the
	# way, so the rename is refused and the copy starts again. Everything arrives,
	# nested folders included, and only then does the source go.
	var from: String = "user://gut_copy_test_from"
	var to: String = "user://gut_copy_test_to"
	_fresh_copy_folders(from, to)
	_write(to.path_join(UserDataManagerClass.INCOMPLETE_COPY_MARKER), "")
	_write(to.path_join("half_copied.txt"), "left over")
	assert_ne(DirAccess.rename_absolute(from, to), OK, "the rename is refused, as intended")

	assert_eq(UserDataManagerClass._move_directory(from, to), OK)

	assert_eq(FileAccess.get_file_as_string(to.path_join("1/fr_FR/125/progression.tres")), "progress")
	assert_eq(FileAccess.get_file_as_string(to.path_join("teacher_settings.tres")), "settings")
	assert_false(FileAccess.file_exists(to.path_join(UserDataManagerClass.INCOMPLETE_COPY_MARKER)),
			"the copy is marked finished")
	assert_false(DirAccess.dir_exists_absolute(from), "the source goes once it is all copied")
	Utils.delete_directory_recursive(to)
	for tracked_error: GutTrackedError in get_errors():
		tracked_error.handled = true


func test_nothing_is_copied_into_a_folder_that_is_not_our_own() -> void:
	# A folder in the way that is not an unfinished copy holds somebody's data: the
	# move is refused, and both folders are left exactly as they were.
	var from: String = "user://gut_copy_test_from"
	var to: String = "user://gut_copy_test_to"
	_fresh_copy_folders(from, to)
	_write(to.path_join("someone_else.txt"), "theirs")

	assert_eq(UserDataManagerClass._move_directory(from, to), ERR_ALREADY_EXISTS)

	assert_eq(FileAccess.get_file_as_string(to.path_join("someone_else.txt")), "theirs")
	assert_false(FileAccess.file_exists(to.path_join("teacher_settings.tres")), "nothing mixed in")
	assert_true(FileAccess.file_exists(from.path_join("teacher_settings.tres")), "the source is kept")
	for path: String in [from, to]:
		Utils.delete_directory_recursive(path)
	for tracked_error: GutTrackedError in get_errors():
		tracked_error.handled = true


## A source folder like a guest's, and an empty slate where the copy goes.
func _fresh_copy_folders(from: String, to: String) -> void:
	for path: String in [from, to]:
		if DirAccess.dir_exists_absolute(path):
			Utils.delete_directory_recursive(path)
	DirAccess.make_dir_recursive_absolute(from.path_join("1/fr_FR/125"))
	_write(from.path_join("1/fr_FR/125/progression.tres"), "progress")
	_write(from.path_join("teacher_settings.tres"), "settings")
	DirAccess.make_dir_recursive_absolute(to)


## Writes a file, standing in for a save the code under test only moves or deletes.
##
## Not a real StudentProgression: creating one reads the lesson count, which warns when
## no language pack is installed -- as on CI -- and GUT fails a test on any warning.
func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


## A guest with one student who has played, and what registering it will carry.
func _played_guest() -> Dictionary:
	UserDataManager.create_guest(_guest_settings(1))
	var code: int = UserDataManager.teacher_settings.get_all_students_data()[0].code
	var progression_path: String = UserDataManager.get_student_progression_path(1, code)
	DirAccess.make_dir_recursive_absolute(progression_path.get_base_dir())
	_write(progression_path, "progress")
	var registered: TeacherSettings = UserDataManager.teacher_settings.detached_copy()
	registered.email = REGISTERED_EMAIL
	registered.token = "a-token"
	return {"code": code, "registered": registered}


## Where the student's progression is under the registered account.
func _registered_progression(code: int) -> String:
	return "user://".path_join(REGISTERED_EMAIL).path_join("1") \
			.path_join(UserDataManager.get_device_settings().language).path_join(str(code)) \
			.path_join("progression.tres")


func test_a_registration_stopped_after_the_move_is_finished_next_launch() -> void:
	# The app is killed after the folder moved and before the device followed it.
	if _skip_if_this_machine_has_a_guest():
		return
	var played: Dictionary = _played_guest()
	var registered: TeacherSettings = played["registered"]
	registered.is_guest = false
	ResourceSaver.save(registered, UserDataManager._get_teacher_settings_path(UserDataManagerClass.GUEST_FOLDER))
	UserDataManager.get_device_settings().pending_account = REGISTERED_EMAIL
	UserDataManager._save_device_settings()
	DirAccess.rename_absolute("user://guest", "user://".path_join(REGISTERED_EMAIL))

	UserDataManager._complete_pending_registration()

	assert_eq(UserDataManager.get_device_settings().teacher, REGISTERED_EMAIL)
	assert_eq(UserDataManager.get_device_settings().pending_account, "")
	assert_true(FileAccess.file_exists(_registered_progression(played["code"])), "nothing lost")


func test_retrying_after_the_move_keeps_the_moved_data() -> void:
	# The reviewer's case: the folder already moved, and Confirm is pressed again. The
	# retry must not take the account's folder for an old account's and delete it.
	if _skip_if_this_machine_has_a_guest():
		return
	var played: Dictionary = _played_guest()
	DirAccess.rename_absolute("user://guest", "user://".path_join(REGISTERED_EMAIL))

	assert_true(UserDataManager.register_guest(played["registered"]))

	assert_true(FileAccess.file_exists(_registered_progression(played["code"])),
			"the progress survived the retry")
	assert_eq(UserDataManager.get_device_settings().teacher, REGISTERED_EMAIL)


func test_registering_twice_is_harmless() -> void:
	if _skip_if_this_machine_has_a_guest():
		return
	var played: Dictionary = _played_guest()
	assert_true(UserDataManager.register_guest(played["registered"]))
	assert_true(UserDataManager.register_guest((played["registered"] as TeacherSettings).detached_copy()))
	assert_true(FileAccess.file_exists(_registered_progression(played["code"])))


## Step 1 of a registration, by hand: the account's settings over the guest's.
func _save_over_the_guest(registered: TeacherSettings) -> void:
	registered.is_guest = false
	ResourceSaver.save(registered, UserDataManager._get_teacher_settings_path(UserDataManagerClass.GUEST_FOLDER))


func _note_pending(email: String) -> void:
	UserDataManager.get_device_settings().pending_account = email
	UserDataManager._save_device_settings()


func test_a_note_left_without_step_one_is_dropped() -> void:
	# Killed after noting the address, before the account replaced the guest: there is
	# no account on the device to move, and the guest stays the guest.
	if _skip_if_this_machine_has_a_guest():
		return
	UserDataManager.create_guest(_guest_settings(1))
	_note_pending(REGISTERED_EMAIL)

	UserDataManager._complete_pending_registration()

	assert_eq(UserDataManager.get_device_settings().pending_account, "")
	assert_true(UserDataManager.guest_exists(), "nothing moved")
	assert_false(DirAccess.dir_exists_absolute("user://".path_join(REGISTERED_EMAIL)))


func test_an_account_folder_in_the_way_is_set_aside_not_deleted() -> void:
	# Signed in to the account meanwhile, which made its folder: it may hold play not
	# yet synchronized, so it is renamed, never deleted, and the guest moves in.
	if _skip_if_this_machine_has_a_guest():
		return
	var played: Dictionary = _played_guest()
	_save_over_the_guest(played["registered"])
	_note_pending(REGISTERED_EMAIL)
	var account_folder: String = "user://".path_join(REGISTERED_EMAIL)
	DirAccess.make_dir_recursive_absolute(account_folder)
	_write(account_folder.path_join("played_meanwhile.txt"), "kept")

	UserDataManager._complete_pending_registration()

	assert_true(FileAccess.file_exists(_registered_progression(played["code"])), "the guest moved in")
	var aside: PackedStringArray = []
	for found: String in _aside_folders():
		if not found in existing_aside:
			aside.append(found)
	assert_eq(aside.size(), 1, "the folder in the way is kept")
	assert_eq(FileAccess.get_file_as_string("user://".path_join(aside[0]).path_join("played_meanwhile.txt")), "kept")
	for tracked_error: GutTrackedError in get_errors():
		tracked_error.handled = true


func test_an_unfinished_copy_in_the_way_is_started_again() -> void:
	if _skip_if_this_machine_has_a_guest():
		return
	var played: Dictionary = _played_guest()
	_save_over_the_guest(played["registered"])
	_note_pending(REGISTERED_EMAIL)
	var account_folder: String = "user://".path_join(REGISTERED_EMAIL)
	DirAccess.make_dir_recursive_absolute(account_folder)
	_write(account_folder.path_join(UserDataManagerClass.INCOMPLETE_COPY_MARKER), "")

	UserDataManager._complete_pending_registration()

	assert_true(FileAccess.file_exists(_registered_progression(played["code"])))
	assert_false(FileAccess.file_exists(account_folder.path_join(UserDataManagerClass.INCOMPLETE_COPY_MARKER)))
	assert_eq(UserDataManager.get_device_settings().teacher, REGISTERED_EMAIL)


func test_a_guest_already_copied_to_its_account_is_never_resumed() -> void:
	if _skip_if_this_machine_has_a_guest():
		return
	UserDataManager.create_guest(_guest_settings(1))
	_write("user://".path_join(UserDataManagerClass.GUEST_FOLDER).path_join(UserDataManagerClass.MOVED_MARKER), "")

	assert_false(UserDataManager.guest_exists())


func test_an_account_still_in_the_guest_folder_resumes_as_the_account() -> void:
	# Its move refused, the account lives on in the guest folder: "Continue as guest"
	# signs in to it -- with its token -- and never treats it as a guest again.
	if _skip_if_this_machine_has_a_guest():
		return
	var played: Dictionary = _played_guest()
	_save_over_the_guest(played["registered"])

	assert_true(UserDataManager.resume_guest())
	assert_false(UserDataManager.is_guest())
	assert_eq(UserDataManager.teacher_settings.token, "a-token")


## What the server answers a sign-in to the registered account.
func _sign_in_answer(codes: Array[int]) -> Dictionary:
	var device_students: Array = []
	for code: int in codes:
		device_students.append({"code": code, "name": "", "level": 0, "age": 0})
	return {"email": REGISTERED_EMAIL, "token": "a-token", "account_type": 0,
			"students": {"1": device_students}}


func test_signing_in_claims_the_guest_registered_under_that_address() -> void:
	# The registration reached the server and its answer was lost: signing in to the
	# account brings the guest's progress along instead of leaving it behind.
	if _skip_if_this_machine_has_a_guest():
		return
	var played: Dictionary = _played_guest()
	UserDataManager.note_guest_registration(REGISTERED_EMAIL)
	UserDataManager.logout()

	assert_true(UserDataManager.login(_sign_in_answer([played["code"]])))

	assert_eq(UserDataManager.get_device_settings().teacher, REGISTERED_EMAIL)
	assert_true(FileAccess.file_exists(_registered_progression(played["code"])), "the progress came along")
	assert_false(UserDataManager.guest_exists(), "and the guest is the account now")


func test_signing_in_leaves_a_guest_noted_for_another_address() -> void:
	# A matching set of codes is not enough: on a shared tablet another teacher's
	# account could hold the same ones.
	if _skip_if_this_machine_has_a_guest():
		return
	var played: Dictionary = _played_guest()
	UserDataManager.note_guest_registration("someone-else@example.invalid")
	UserDataManager.logout()

	assert_true(UserDataManager.login(_sign_in_answer([played["code"]])))

	assert_true(UserDataManager.guest_exists(), "the guest is untouched")
	assert_false(FileAccess.file_exists(_registered_progression(played["code"])))


func test_signing_in_leaves_a_guest_whose_codes_differ() -> void:
	if _skip_if_this_machine_has_a_guest():
		return
	var played: Dictionary = _played_guest()
	UserDataManager.note_guest_registration(REGISTERED_EMAIL)
	UserDataManager.logout()
	var other_code: int = TeacherSettings.AVAILABLE_CODES[0] \
			if TeacherSettings.AVAILABLE_CODES[0] != played["code"] else TeacherSettings.AVAILABLE_CODES[1]

	assert_true(UserDataManager.login(_sign_in_answer([other_code])))

	assert_true(UserDataManager.guest_exists(), "a different account does not take the guest")
	for tracked_error: GutTrackedError in get_errors():
		tracked_error.handled = true


func test_an_unreadable_guest_is_set_aside_not_deleted() -> void:
	if _skip_if_this_machine_has_a_guest():
		return
	var folder: String = "user://".path_join(UserDataManagerClass.GUEST_FOLDER)
	DirAccess.make_dir_recursive_absolute(folder.path_join("1/fr_FR/125"))
	_write(folder.path_join("1/fr_FR/125/progression.tres"), "a child's progress")
	_write(folder.path_join("teacher_settings.tres"), "not a resource at all")
	assert_false(UserDataManager.resume_guest(), "it cannot be opened")

	assert_true(UserDataManager.create_guest(_guest_settings(1)))

	var aside: PackedStringArray = []
	for found: String in _aside_folders():
		if not found in existing_aside:
			aside.append(found)
	assert_eq(aside.size(), 1, "the old guest is kept, renamed")
	assert_eq(FileAccess.get_file_as_string("user://".path_join(aside[0]).path_join("1/fr_FR/125/progression.tres")),
			"a child's progress")
	assert_true(UserDataManager.is_guest(), "and a new guest starts")
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
	_write(progression_path, "progress")

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
