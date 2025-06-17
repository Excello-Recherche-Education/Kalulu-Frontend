extends Node
class_name UserDatabaseSynchronizer


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


func start_sync() -> void:
	synchronizing = true
	if loading_popup != null:
		loading_popup.set_finished(false)
		set_loading_bar_text("SYNCHRONIZATION_INITIALISATION")
		await set_loading_bar_progression(0.0)
		loading_popup.show()


func stop_sync(success: bool = false) -> void:
	synchronizing = false
	if success:
		await set_loading_bar_progression(100.0, 1.0)
		set_loading_bar_text("SYNCHRONIZATION_SUCCESS")
	if loading_popup != null:
		loading_popup.set_finished(true)


func _check_internet() -> bool:
	await set_loading_bar_progression(1.0)
	set_loading_bar_text("SYNCHRONIZATION_CHECK_INTERNET_ACCESS")
	if await (ServerManager as ServerManagerClass).check_internet_access():
		return true
	set_loading_bar_text("SYNCHRONIZATION_ERROR_NO_INTERNET")
	stop_sync()
	return false


func _pull_timestamps() -> Dictionary:
	set_loading_bar_text("SYNCHRONIZATION_ASK_SERVER_TIMESTAMP")
	var res: Dictionary = await (ServerManager as ServerManagerClass).pull_timestamps()
	if not res.success:
		Logger.trace("UserDatabaseSynchronizer: Cannot get all timestamps from server. Canceling synchronization.")
		set_loading_bar_text("SYNCHRONIZATION_ERROR_NO_SERVER")
		stop_sync()
		return {}
	await set_loading_bar_progression(20.0)
	return res.body


func _determine_user_update(response_body: Dictionary) -> UpdateNeeded:
	set_loading_bar_text("SYNCHRONIZATION_COMPARE_SERVER_TIMESTAMP")
	if not response_body.has("user"):
		Logger.trace("UserDatabaseSynchronizer: Cannot get user from body. Canceling synchronization.")
		set_loading_bar_text("SYNCHRONIZATION_ERROR_NO_BODY_FROM_SERVER")
		stop_sync()
		return UpdateNeeded.Nothing
	var user: Dictionary = response_body.user
	if not user.has("last_modified"):
		Logger.trace("UserDatabaseSynchronizer: Cannot get last_modified from user. Canceling synchronization.")
		set_loading_bar_text("SYNCHRONIZATION_ERROR")
		stop_sync()
		return UpdateNeeded.Nothing
	var server_unix_time_user: int = Time.get_unix_time_from_datetime_string(user.last_modified as String)
	var local_user_string_time: String = UserDataManager.teacher_settings.last_modified
	var local_unix_time_user: int = 0
	if local_user_string_time != "":
		local_unix_time_user = Time.get_unix_time_from_datetime_string(local_user_string_time)
	var need_update_user: UpdateNeeded = UpdateNeeded.Nothing
	if local_unix_time_user == server_unix_time_user:
		Logger.trace("UserDatabaseSynchronizer: User data timestamp is the same in local and on server. No synchronization necessary")
	elif local_unix_time_user > server_unix_time_user:
		need_update_user = UpdateNeeded.FromLocal
	else:
		need_update_user = UpdateNeeded.FromServer
	return need_update_user


func _determine_students_update(response_body: Dictionary, need_update_user: UpdateNeeded) -> Dictionary:
	var need_update_students: Dictionary[int, Dictionary] = {}
	if not response_body.has("students"):
		Logger.trace("UserDatabaseSynchronizer: Cannot get last_modified from user. Canceling synchronization.")
		set_loading_bar_text("SYNCHRONIZATION_ERROR")
		stop_sync()
		return {}
	var students_timestamps: Array[Dictionary] = []
	for item: Dictionary in response_body.students:
		students_timestamps.append(item)
	for student_dic: Dictionary in students_timestamps:
		if not student_dic.has("code"):
			continue
		var code_to_check: int = student_dic.code
		var server_student_unix_time: int = -1
		if student_dic.has("updated_at"):
			server_student_unix_time = Time.get_unix_time_from_datetime_string(student_dic.updated_at as String)
		else:
			Logger.warn("UserDatabaseSynchronizer: Student %d received from server has no timestamp" % code_to_check)
		var server_student_remediation_unix_time: int = -1
		if student_dic.has("gp_remediation_last_modified"):
			if student_dic.gp_remediation_last_modified != null && student_dic.gp_remediation_last_modified is String:
				server_student_remediation_unix_time = Time.get_unix_time_from_datetime_string(student_dic.gp_remediation_last_modified as String)
			else:
				server_student_remediation_unix_time = 0
		var found: bool = false
		for device: int in UserDataManager.teacher_settings.students.keys():
			var students_in_device: Array[StudentData] = UserDataManager.teacher_settings.students[device]
			for student_data: StudentData in students_in_device:
				if student_data.code == code_to_check:
					found = true
					
					# Synchronize student data
					var local_student_unix_time: int = Time.get_unix_time_from_datetime_string(student_data.last_modified)
					if local_student_unix_time == server_student_unix_time:
						Logger.trace("UserDatabaseSynchronizer: Student %d data timestamp is the same in local and on server. No synchronization necessary" % code_to_check)
						need_update_students[code_to_check] = {"data": UpdateNeeded.Nothing}
					elif local_student_unix_time > server_student_unix_time:
						need_update_students[code_to_check] = {"data": UpdateNeeded.FromLocal}
					else:
						need_update_students[code_to_check] = {"data": UpdateNeeded.FromServer}
					
					# Synchronize student gp remediation
					var student_gp_remediation: UserRemediation = UserDataManager.get_student_remediation_data(code_to_check)
					if student_gp_remediation != null:
						var local_student_gp_remediation_unix_time: int = Time.get_unix_time_from_datetime_string(student_gp_remediation.last_modified)
						#server_student_remediation_unix_time
						if local_student_gp_remediation_unix_time == server_student_remediation_unix_time:
							Logger.trace("UserDatabaseSynchronizer: Student %d GP remediation data timestamp is the same in local and on server. No synchronization necessary" % code_to_check)
							need_update_students[code_to_check] = {"remediation_gp": UpdateNeeded.Nothing}
						elif local_student_gp_remediation_unix_time > server_student_remediation_unix_time:
							need_update_students[code_to_check] = {"remediation_gp": UpdateNeeded.FromLocal}
						else:
							need_update_students[code_to_check] = {"remediation_gp": UpdateNeeded.FromServer}
					break
			if found:
				break
		if not found:
			if need_update_user == UpdateNeeded.FromServer:
				need_update_students[code_to_check] = {}
				need_update_students[code_to_check]["data"] = UpdateNeeded.FromServer
			elif need_update_user == UpdateNeeded.FromLocal:
				need_update_students[code_to_check] = {}
				need_update_students[code_to_check]["data"] = UpdateNeeded.DeleteServer
			else:
				Logger.warn("UserDatabaseSynchronizer: Student %d not found in local, but user doesn't need to be updated...this is theoretically not possible" % code_to_check)

	for device: int in UserDataManager.teacher_settings.students.keys():
			var students_in_device: Array[StudentData] = UserDataManager.teacher_settings.students[device]
			for student_data: StudentData in students_in_device:
				if not need_update_students.has(student_data.code):
					if need_update_user == UpdateNeeded.FromServer:
						need_update_students[student_data.code] = {}
						need_update_students[student_data.code]["data"] = UpdateNeeded.DeleteLocal
					elif need_update_user == UpdateNeeded.FromLocal:
						need_update_students[student_data.code] = {}
						need_update_students[student_data.code]["data"] = UpdateNeeded.FromLocal
					else:
						Logger.warn("UserDatabaseSynchronizer: Student %d not found in server, but user doesn't need to be updated...this is theoretically not possible" % student_data.code)
	return need_update_students


func _build_message_to_server(need_update_user: UpdateNeeded, need_update_students: Dictionary[int, Dictionary]) -> Dictionary:
	var message_to_server: Dictionary = {}

	# Gérer l'utilisateur
	if need_update_user == UpdateNeeded.FromLocal:
		message_to_server["user"] = {
			"account_type": UserDataManager.teacher_settings.account_type,
			"education_method": UserDataManager.teacher_settings.education_method,
			"last_modified": UserDataManager.teacher_settings.last_modified
		}
	elif need_update_user == UpdateNeeded.FromServer:
		message_to_server["user"] = {"need_update": true}

	message_to_server["students"] = {}

	for student_code: int in need_update_students.keys():
		var student_entry: Dictionary = need_update_students[student_code]
		var student_block: Dictionary = {}

		# Traitement de l'étudiant lui-même
		if student_entry.has("data"):
			var student_update: UpdateNeeded = student_entry["data"]

			if student_update == UpdateNeeded.DeleteLocal:
				UserDataManager.delete_student(student_code)
				continue

			elif student_update == UpdateNeeded.DeleteServer:
				student_block["delete"] = true

			elif student_update == UpdateNeeded.FromLocal:
				var device_id: int = UserDataManager.teacher_settings.get_student_device(student_code)
				if device_id == -1:
					Logger.error("UserDatabaseSynchronizer: Student code %s has no device ID" % student_code)
					continue
				var student_data: StudentData = UserDataManager.teacher_settings.get_student_with_code(student_code)
				if not student_data:
					Logger.warn("UserDatabaseSynchronizer: Cannot find student with code %d" % student_code)
					continue
				student_block.merge({
					"device_id": device_id,
					"name": student_data.name,
					"age": student_data.age,
					"updated_at": student_data.last_modified
				})

			elif student_update == UpdateNeeded.FromServer:
				student_block["need_update"] = true

		# Traitement de "remediation_gp"
		if student_entry.has("remediation_gp"):
			var gp_remediation_block: Dictionary = {}
			if student_entry.remediation_gp == UpdateNeeded.FromLocal:
				var student_remediation: UserRemediation = UserDataManager.get_student_remediation_data(student_code)
				var tuple_list: Array = []
				for key: int in student_remediation.gps_scores.keys():
					tuple_list.append([key, student_remediation.gps_scores[key]])
				gp_remediation_block = {"score_remediation": tuple_list, "updated_at": student_remediation.last_modified}
			elif student_entry.remediation_gp == UpdateNeeded.FromServer:
				gp_remediation_block = {"need_update": true}
			elif student_entry.remediation_gp == UpdateNeeded.DeleteServer:
				gp_remediation_block = {"delete": true}

			if gp_remediation_block.size() > 0:
				student_block["remediation_gp"] = gp_remediation_block

		if student_block.size() > 0:
			message_to_server["students"][student_code] = student_block

	if (message_to_server["students"] as Dictionary).is_empty():
		message_to_server.erase("students")

	return message_to_server


func _send_instructions(message_to_server: Dictionary) -> Dictionary:
	await set_loading_bar_progression(60.0)
	set_loading_bar_text("SYNCHRONIZATION_SEND_SERVER_INSTRUCTIONS")
	if message_to_server.keys().size() == 0:
		Logger.trace("UserDatabaseSynchronizer: No instruction to send to server")
		return {}
	var res_get_server_instructions: Dictionary = await (ServerManager as ServerManagerClass).send_server_synchronization_instructions(message_to_server)
	if not res_get_server_instructions.success:
		Logger.trace("UserDatabaseSynchronizer: Cannot send instructions to server. Canceling synchronization.")
		set_loading_bar_text("SYNCHRONIZATION_ERROR_NO_SERVER")
		stop_sync()
		return {}
	await set_loading_bar_progression(80.0)
	set_loading_bar_text("SYNCHRONIZATION_APPLY_LOCAL_INSTRUCTIONS")
	return res_get_server_instructions.body


func _apply_server_response(response_body: Dictionary) -> void:
	if response_body.has("user"):
		var response_user: Dictionary = response_body.user
		Logger.trace("UserDatabaseSynchronizer: Updating user")
		if not response_user.has("account_type"):
			Logger.warn("UserDatabaseSynchronizer: While updating user, no account_type found")
		else:
			UserDataManager.teacher_settings.account_type = response_user.account_type
		if not response_user.has("education_method"):
			Logger.warn("UserDatabaseSynchronizer: While updating user, no education_method found")
		else:
			UserDataManager.teacher_settings.education_method = response_user.education_method
		if not response_user.has("last_modified"):
			Logger.warn("UserDatabaseSynchronizer: While updating user, no last_modified found")
		else:
			UserDataManager.teacher_settings.last_modified = response_user.last_modified
	if response_body.has("students"):
		Logger.trace("UserDatabaseSynchronizer: Updating students")
		var response_students: Dictionary = response_body.students
		for response_student_code: String in response_students.keys():
			var response_student_data: Dictionary = response_students[response_student_code]
			if response_student_data.has("device_id") && response_student_data.has("name") && response_student_data.has("age") && response_student_data.has("updated_at"):
				UserDataManager.teacher_settings.set_data_student_with_code(int(response_student_code), int(response_student_data.device_id as float), response_student_data.name as String, int(response_student_data.age as float), response_student_data.updated_at as String)
			if response_student_data.has("remediation_gp") && (response_student_data.remediation_gp as Dictionary).has("score_remediation") && (response_student_data.remediation_gp  as Dictionary).has("updated_at"):
				# TODO ADD SECURITY
				var new_array: Array = JSON.parse_string(response_student_data.remediation_gp.score_remediation as String) as Array
				var new_scores: Dictionary[int, int] = {}
				for index: int in new_array.size():
					# TODO ADD SECURITY
					new_scores[int(new_array[index][0])] = int(new_array[index][1])
				UserDataManager.set_student_remediation_data(int(response_student_code), new_scores, response_student_data.remediation_gp.updated_at as String)


func synchronize() -> void:
	Logger.trace("UserDatabaseSynchronizer: Start synchronizing user data.")
	if synchronizing:
		Logger.trace("UserDatabaseSynchronizer: User synchronization already started, cancel double-call.")
		return
	await start_sync()

	if not await _check_internet():
		return

	var response_body: Dictionary = await _pull_timestamps()
	if response_body.is_empty():
		return

	var need_update_user: UpdateNeeded = _determine_user_update(response_body)
	if not synchronizing:
		return
	var need_update_students: Dictionary[int, Dictionary] = _determine_students_update(response_body, need_update_user)
	if not synchronizing:
		return
	await set_loading_bar_progression(40.0)
	set_loading_bar_text("SYNCHRONIZATION_COMPILE_SERVER_INSTRUCTIONS")

	var message_to_server: Dictionary = _build_message_to_server(need_update_user, need_update_students)
	var server_response: Dictionary = await _send_instructions(message_to_server)
	if not synchronizing:
		return
	if server_response.size() > 0:
		_apply_server_response(server_response)

	await set_loading_bar_progression(99.0)
	UserDataManager.save_all()
	stop_sync(true)


func set_loading_bar_progression(value_percent: float, wait_time: float = 0.2) -> void:
	if loading_popup != null:
		loading_popup.set_progress(value_percent)
		await loading_popup.get_tree().create_timer(wait_time).timeout


func set_loading_bar_text(message: String) -> void:
	if loading_popup != null:
		loading_popup.set_text(message)
