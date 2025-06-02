extends Node
class_name UserDataBaseSynchronizer


var synchronizing: bool = false

var account_type_option_button: OptionButton
var education_method_option_button: OptionButton

var loading_popup: LoadingPopup

enum UpdateNeeded {
	Nothing,
	FromLocal,
	FromServer,
	DeleteLocal,
	DeleteServer
}


func startSync() -> void:
	synchronizing = true
	loading_popup.set_finished(false)
	loading_popup.set_text("SYNCHRONIZATION_INITIALISATION")
	await setLoadingProgression(0.0)
	loading_popup.show()


func stopSync(success: bool = false) -> void:
	synchronizing = false
	if success:
		await setLoadingProgression(100.0, 1.0)
		loading_popup.set_text("SYNCHRONIZATION_SUCCESS")
	loading_popup.set_finished(true)


func on_synchronize_button_pressed() -> void:
	Logger.trace("UserDataBaseSynchronizer: Start synchronizing user data.")
	if synchronizing:
		Logger.trace("UserDataBaseSynchronizer: User synchronization already started, cancel double-call.")
		return
	await startSync()
	
	await setLoadingProgression(1.0)
	loading_popup.set_text("SYNCHRONIZATION_CHECK_INTERNET_ACCESS")
	if not await (ServerManager as ServerManagerClass).check_internet_access():
		loading_popup.set_text("SYNCHRONIZATION_ERROR_NO_INTERNET")
		stopSync()
	
	loading_popup.set_text("SYNCHRONIZATION_ASK_SERVER_TIMESTAMP")
	var response_ge_all_timestamps: Dictionary = await (ServerManager as ServerManagerClass).pull_timestamps()
	if not response_ge_all_timestamps.success:
		Logger.trace("UserDataBaseSynchronizer: Cannot get all timestamps from server. Canceling synchronization.")
		loading_popup.set_text("SYNCHRONIZATION_ERROR_NO_SERVER")
		stopSync()
		return
	
	await setLoadingProgression(20.0)
	loading_popup.set_text("SYNCHRONIZATION_COMPARE_SERVER_TIMESTAMP")
	var response_body: Dictionary = response_ge_all_timestamps.body
	if not response_body.has("user"):
		Logger.trace("UserDataBaseSynchronizer: Cannot get user from body. Canceling synchronization.")
		loading_popup.set_text("SYNCHRONIZATION_ERROR_NO_BODY_FROM_SERVER")
		stopSync()
		return
	var user: Dictionary = response_body.user
	if not user.has("last_modified"):
		Logger.trace("UserDataBaseSynchronizer: Cannot get last_modified from user. Canceling synchronization.")
		loading_popup.set_text("SYNCHRONIZATION_ERROR")
		stopSync()
		return
	var serverUnixTimeUser: int = Time.get_unix_time_from_datetime_string(user.last_modified as String)
	var localUserStringTime: String = UserDataManager.teacher_settings.last_modified
	var localUnixTimeUser: int = 0
	if localUserStringTime != "":
		localUnixTimeUser = Time.get_unix_time_from_datetime_string(localUserStringTime)
	var need_update_user: UpdateNeeded = UpdateNeeded.Nothing
	if localUnixTimeUser == serverUnixTimeUser:
		Logger.trace("UserDataBaseSynchronizer: User data timestamp is the same in local and on server. No synchronization necessary")
	elif localUnixTimeUser > serverUnixTimeUser:
		need_update_user = UpdateNeeded.FromLocal
	else: # localUnixTimeUser < serverUnixTimeUser
		need_update_user = UpdateNeeded.FromServer
	
	await setLoadingProgression(40.0)
	loading_popup.set_text("SYNCHRONIZATION_COMPILE_SERVER_INSTRUCTIONS")
	var need_update_students: Dictionary[int, UpdateNeeded] # student_code, status
	if not response_body.has("students"):
		Logger.trace("UserDataBaseSynchronizer: Cannot get last_modified from user. Canceling synchronization.")
		loading_popup.set_text("SYNCHRONIZATION_ERROR")
		stopSync()
		return
	var students_timestamps: Array[Dictionary] = []
	for item: Dictionary in response_body.students:
		students_timestamps.append(item)
	for studentDic: Dictionary in students_timestamps:
		if not studentDic.has("code"):
			continue
		var code_to_check: int = studentDic.code
		var serverStudentUnixTime: int = -1
		if studentDic.has("updated_at"):
			serverStudentUnixTime = Time.get_unix_time_from_datetime_string(studentDic.updated_at as String)
		else:
			Logger.warn("UserDataBaseSynchronizer: Student %d received from server has no timestamp" % code_to_check)
		var found: bool = false
		for device: int in UserDataManager.teacher_settings.students.keys():
			var students_in_device: Array[StudentData] = UserDataManager.teacher_settings.students[device]
			for student_data: StudentData in students_in_device:
				if student_data.code == code_to_check:
					var localStudentUnixTime: int = Time.get_unix_time_from_datetime_string(student_data.last_modified)
					if localStudentUnixTime == serverStudentUnixTime:
						Logger.trace("UserDataBaseSynchronizer: Student %d data timestamp is the same in local and on server. No synchronization necessary" % code_to_check)
						need_update_students[code_to_check] = UpdateNeeded.Nothing
					elif localStudentUnixTime > serverStudentUnixTime:
						need_update_students[code_to_check] = UpdateNeeded.FromLocal
					else: # localStudentUnixTime < serverStudentUnixTime
						need_update_students[code_to_check] = UpdateNeeded.FromServer
					found = true
					break
			if found:
				break
		if not found:
			if need_update_user == UpdateNeeded.FromServer:
				# If the student does not exists in local and if the user on server is more recent, we need the data to create the student
				need_update_students[code_to_check] = UpdateNeeded.FromServer
			elif need_update_user == UpdateNeeded.FromLocal:
				# If the student does not exists in local and if the user on local is more recent, we need to delete the student on the server
				need_update_students[code_to_check] = UpdateNeeded.DeleteServer
			else:
				Logger.warn("UserDataBaseSynchronizer: Student %d not found in local, but user doesn't need to be updated...this is theoretically not possible" % code_to_check)
	
	for device: int in UserDataManager.teacher_settings.students.keys():
			var students_in_device: Array[StudentData] = UserDataManager.teacher_settings.students[device]
			for student_data: StudentData in students_in_device:
				if not need_update_students.has(student_data.code):
					if need_update_user == UpdateNeeded.FromServer:
						need_update_students[student_data.code] = UpdateNeeded.DeleteLocal
					elif need_update_user == UpdateNeeded.FromLocal:
						need_update_students[student_data.code] = UpdateNeeded.FromLocal
					else:
						Logger.warn("UserDataBaseSynchronizer: Student %d not found in server, but user doesn't need to be updated...this is theoretically not possible" % student_data.code)
	var message_to_server: Dictionary
	if need_update_user == UpdateNeeded.Nothing:
		pass
	elif need_update_user == UpdateNeeded.FromLocal:
		message_to_server["user"] =	{
										"account_type": UserDataManager.teacher_settings.account_type,
										"education_method": UserDataManager.teacher_settings.education_method,
										"last_modified": UserDataManager.teacher_settings.last_modified
									}
	elif need_update_user == UpdateNeeded.FromServer:
		message_to_server["user"] = {"need_update": true}
	message_to_server["students"] = {}
	for student_code_to_update: int in need_update_students.keys():
		if need_update_students[student_code_to_update] == UpdateNeeded.Nothing:
			continue
		elif need_update_students[student_code_to_update] == UpdateNeeded.FromLocal:
			var student_device:int = UserDataManager.teacher_settings.get_student_device(student_code_to_update)
			if student_device == -1:
				Logger.error("UserDataBaseSynchronizer: Student code %s has no device ID" % student_code_to_update)
				continue
			var student_data: StudentData = UserDataManager.teacher_settings.get_student_with_code(student_code_to_update)
			if not student_data:
				Logger.warn("UserDataBaseSynchronizer: Cannot find student with code %d" % student_code_to_update)
				continue
			message_to_server["students"][student_code_to_update] =	{
																		"device_id": student_device,
																		"name": student_data.name,
																		"age": student_data.age,
																		"updated_at": student_data.last_modified,
																	}
		elif need_update_students[student_code_to_update] == UpdateNeeded.FromServer:
			message_to_server["students"][student_code_to_update] = {"need_update": true}
		elif need_update_students[student_code_to_update] == UpdateNeeded.DeleteLocal:
			UserDataManager.delete_student(student_code_to_update)
		elif need_update_students[student_code_to_update] == UpdateNeeded.DeleteServer:
			message_to_server["students"][student_code_to_update] = {"delete": true}
		else:
			Logger.warn("UserDataBaseSynchronizer: Update needed enum not recognized: %s" % str(need_update_students[student_code_to_update]))
	if (message_to_server["students"] as Dictionary).keys().size() == 0:
		message_to_server.erase("students")
	
	await setLoadingProgression(60.0)
	loading_popup.set_text("SYNCHRONIZATION_SEND_SERVER_INSTRUCTIONS")
	if message_to_server.keys().size() == 0:
		Logger.trace("UserDataBaseSynchronizer: No instruction to send to server")
	else:
		var res_get_server_instructions: Dictionary = await (ServerManager as ServerManagerClass).send_server_synchronization_instructions(message_to_server)
		if not res_get_server_instructions.success:
			Logger.trace("UserDataBaseSynchronizer: Cannot send instructions to server. Canceling synchronization.")
			loading_popup.set_text("SYNCHRONIZATION_ERROR_NO_SERVER")
			stopSync()
			return
	
		await setLoadingProgression(80.0)
		loading_popup.set_text("SYNCHRONIZATION_APPLY_LOCAL_INSTRUCTIONS")
		response_body = res_get_server_instructions.body
		if response_body.has("user"):
			var response_user: Dictionary = response_body.user
			Logger.trace("UserDataBaseSynchronizer: Updating user")
			if not response_user.has("account_type"):
				Logger.warn("UserDataBaseSynchronizer: While updating user, no account_type found")
			else:
				UserDataManager.teacher_settings.account_type = response_user.account_type
			if not response_user.has("education_method"):
				Logger.warn("UserDataBaseSynchronizer: While updating user, no education_method found")
			else:
				UserDataManager.teacher_settings.education_method = response_user.education_method
			if not response_user.has("last_modified"):
				Logger.warn("UserDataBaseSynchronizer: While updating user, no last_modified found")
			else:
				UserDataManager.teacher_settings.last_modified = response_user.last_modified
		if response_body.has("students"):
			Logger.trace("UserDataBaseSynchronizer: Updating students")
			var response_students: Dictionary = response_body.students
			for response_student_code: String in response_students.keys():
				var response_student_data: Dictionary = response_students[response_student_code]
				UserDataManager.teacher_settings.set_data_student_with_code(int(response_student_code), int(response_student_data.device_id as float), response_student_data.name as String, int(response_student_data.age as float), response_student_data.updated_at as String)
	
	await setLoadingProgression(99.0)
	UserDataManager.save_all()
	stopSync(true)


func setLoadingProgression(value_percent: float, wait_time: float = 0.2) -> void:
	loading_popup.set_progress(value_percent)
	await loading_popup.get_tree().create_timer(wait_time).timeout
