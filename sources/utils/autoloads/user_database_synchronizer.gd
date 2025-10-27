class_name UserDatabaseSynchronizer
extends Node

enum UpdateNeeded {
	Nothing,
	FromLocal,
	FromServer,
	DeleteLocal,
	DeleteServer
}

var synchronizing: bool = false
var account_type_option_button: OptionButton
var education_method_option_button: OptionButton
var loading_popup: LoadingPopup


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
		Log.trace("UserDatabaseSynchronizer: Cannot get all timestamps from server. Canceling synchronization.")
		set_loading_bar_text("SYNCHRONIZATION_ERROR_NO_SERVER")
		stop_sync()
		return {}
	await set_loading_bar_progression(20.0)
	return res.body


func _determine_user_update(response_body: Dictionary) -> UpdateNeeded:
	set_loading_bar_text("SYNCHRONIZATION_COMPARE_SERVER_TIMESTAMP")
	if not response_body.has("user"):
		Log.trace("UserDatabaseSynchronizer: Cannot get user from body. Canceling synchronization.")
		set_loading_bar_text("SYNCHRONIZATION_ERROR_NO_BODY_FROM_SERVER")
		stop_sync()
		return UpdateNeeded.Nothing
	var user: Dictionary = response_body.user
	if not user.has("last_modified"):
		Log.trace("UserDatabaseSynchronizer: Cannot get last_modified from user. Canceling synchronization.")
		set_loading_bar_text("SYNCHRONIZATION_ERROR")
		stop_sync()
		return UpdateNeeded.Nothing
	var server_unix_time_user: int = Time.get_unix_time_from_datetime_string(user.last_modified as String)
	var local_user_string_time: String = UserDataManager.teacher_settings.last_modified
	var local_unix_time_user: int = 0
	if local_user_string_time != "":
		local_unix_time_user = Time.get_unix_time_from_datetime_string(local_user_string_time)
	return _compute_update_needed(local_unix_time_user, server_unix_time_user)


func _compute_update_needed(local_unix_time: int, server_unix_time: int) -> UpdateNeeded:
	if local_unix_time == server_unix_time:
		return UpdateNeeded.Nothing
	if local_unix_time > server_unix_time:
		return UpdateNeeded.FromLocal
	return UpdateNeeded.FromServer


func _determine_students_update(response_body: Dictionary, need_update_user: UpdateNeeded) -> Dictionary:
	var need_update_students: Dictionary[int, Dictionary] = {}
	if not response_body.has("students"):
		Log.trace("UserDatabaseSynchronizer: Cannot get last_modified from user. Canceling synchronization.")
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
			Log.warn("UserDatabaseSynchronizer: Student %d received from server has no timestamp" % code_to_check)
		
		var server_student_progression_unix_time: int = -1
		if student_dic.has("progression_last_modified"):
			if student_dic.progression_last_modified != null and student_dic.progression_last_modified is String:
				server_student_progression_unix_time = Time.get_unix_time_from_datetime_string(student_dic.progression_last_modified as String)
			else:
				server_student_progression_unix_time = 0
		
		var server_student_remediation_gp_unix_time: int = -1
		if student_dic.has("gp_remediation_last_modified"):
			if student_dic.gp_remediation_last_modified != null and student_dic.gp_remediation_last_modified is String:
				server_student_remediation_gp_unix_time = Time.get_unix_time_from_datetime_string(student_dic.gp_remediation_last_modified as String)
			else:
				server_student_remediation_gp_unix_time = 0
		var server_student_remediation_syllables_unix_time: int = -1
		if student_dic.has("syllables_remediation_last_modified"):
			if student_dic.syllables_remediation_last_modified != null and student_dic.syllables_remediation_last_modified is String:
				server_student_remediation_syllables_unix_time = Time.get_unix_time_from_datetime_string(student_dic.syllables_remediation_last_modified as String)
			else:
				server_student_remediation_syllables_unix_time = 0
		var server_student_remediation_words_unix_time: int = -1
		if student_dic.has("words_remediation_last_modified"):
			if student_dic.words_remediation_last_modified != null and student_dic.words_remediation_last_modified is String:
				server_student_remediation_words_unix_time = Time.get_unix_time_from_datetime_string(student_dic.words_remediation_last_modified as String)
			else:
				server_student_remediation_words_unix_time = 0
		
		var server_student_confusion_matrix_gp_unix_time: int = -1
		if student_dic.has("confusion_matrix_gp_last_modified"):
			if student_dic.confusion_matrix_gp_last_modified != null and student_dic.confusion_matrix_gp_last_modified is String:
				server_student_confusion_matrix_gp_unix_time = Time.get_unix_time_from_datetime_string(student_dic.confusion_matrix_gp_last_modified as String)
			else:
				server_student_confusion_matrix_gp_unix_time = 0
		
		var found: bool = false
		need_update_students[code_to_check] = {}
		var student_updates: Dictionary = need_update_students[code_to_check]
		for device: int in UserDataManager.teacher_settings.students.keys():
			var students_in_device: Array[StudentData] = UserDataManager.teacher_settings.students[device]
			for student_data: StudentData in students_in_device:
				if student_data.code == code_to_check:
					found = true
					
					# Synchronize student data
					var local_student_unix_time: int = Time.get_unix_time_from_datetime_string(student_data.last_modified)
					student_updates["data"] = _compute_update_needed(local_student_unix_time, server_student_unix_time)
					if student_updates["data"] == UpdateNeeded.Nothing:
						Log.trace("UserDatabaseSynchronizer: Student %d data timestamp is the same in local and on server. No synchronization necessary" % code_to_check)
					
					# Synchronize student progression
					var student_progression: StudentProgression = UserDataManager.get_student_progression_for_code(device, code_to_check)
					if not student_progression:
						Log.error("UserDatabaseSynchronizer: Cannot get student progression. Canceling synchronization.")
						set_loading_bar_text("SYNCHRONIZATION_ERROR")
						stop_sync()
						return {}
					var local_student_progression_unix_time: int = Time.get_unix_time_from_datetime_string(student_progression.last_modified)
					student_updates["progression"] = _compute_update_needed(local_student_progression_unix_time, server_student_progression_unix_time)
					if student_updates["progression"] == UpdateNeeded.Nothing:
						Log.trace("UserDatabaseSynchronizer: Student %d progression data timestamp is the same in local and on server. No synchronization necessary" % code_to_check)
					
					# Synchronize student remediation
					var student_remediation: UserRemediation = UserDataManager.get_student_remediation_data(code_to_check)
					if student_remediation != null:
						var local_student_gp_remediation_unix_time: int = Time.get_unix_time_from_datetime_string(student_remediation.gp_last_modified)
						student_updates["remediation_gp"] = _compute_update_needed(local_student_gp_remediation_unix_time, server_student_remediation_gp_unix_time)
						if student_updates["remediation_gp"] == UpdateNeeded.Nothing:
							Log.trace("UserDatabaseSynchronizer: Student %d GP remediation data timestamp is the same in local and on server. No synchronization necessary" % code_to_check)
						
						var local_student_syllables_remediation_unix_time: int = Time.get_unix_time_from_datetime_string(student_remediation.syllables_last_modified)
						student_updates["remediation_syllables"] = _compute_update_needed(local_student_syllables_remediation_unix_time, server_student_remediation_syllables_unix_time)
						if student_updates["remediation_syllables"] == UpdateNeeded.Nothing:
							Log.trace("UserDatabaseSynchronizer: Student %d syllables remediation data timestamp is the same in local and on server. No synchronization necessary" % code_to_check)
						
						var local_student_words_remediation_unix_time: int = Time.get_unix_time_from_datetime_string(student_remediation.words_last_modified)
						student_updates["remediation_words"] = _compute_update_needed(local_student_words_remediation_unix_time, server_student_remediation_words_unix_time)
						if student_updates["remediation_words"] == UpdateNeeded.Nothing:
							Log.trace("UserDatabaseSynchronizer: Student %d words remediation data timestamp is the same in local and on server. No synchronization necessary" % code_to_check)
					
					# Synchronize student confusion matrix
					var student_confusion_matrix: UserConfusionMatrix = UserDataManager.get_student_confusion_matrix_data(code_to_check)
					if student_confusion_matrix != null:
						var local_student_gp_confusion_matrix_unix_time: int = Time.get_unix_time_from_datetime_string(student_confusion_matrix.gp_last_modified)
						student_updates["confusion_matrix_gp"] = _compute_update_needed(local_student_gp_confusion_matrix_unix_time, server_student_confusion_matrix_gp_unix_time)
						if student_updates["confusion_matrix_gp"] == UpdateNeeded.Nothing:
							Log.trace("UserDatabaseSynchronizer: Student %d GP confusion matrix data timestamp is the same in local and on server. No synchronization necessary" % code_to_check)
					else:
						if server_student_confusion_matrix_gp_unix_time > 0:
							student_updates["confusion_matrix_gp"] = UpdateNeeded.FromServer
					
					break
			if found:
				break
		if not found:
			if need_update_user == UpdateNeeded.FromServer:
				need_update_students[code_to_check]["data"] = UpdateNeeded.FromServer
			elif need_update_user == UpdateNeeded.FromLocal:
				need_update_students[code_to_check]["data"] = UpdateNeeded.DeleteServer
			else:
				Log.warn("UserDatabaseSynchronizer: Student %d not found in local, but user doesn't need to be updated...this is theoretically not possible" % code_to_check)

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
						Log.warn("UserDatabaseSynchronizer: Student %d not found in server, but user doesn't need to be updated...this is theoretically not possible" % student_data.code)
	return need_update_students


func _build_message_to_server(need_update_user: UpdateNeeded, need_update_students: Dictionary[int, Dictionary]) -> Dictionary:
	var message_to_server: Dictionary = {}

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
					Log.error("UserDatabaseSynchronizer: Student code %s has no device ID" % student_code)
					continue
				var student_data: StudentData = UserDataManager.teacher_settings.get_student_with_code(student_code)
				if not student_data:
					Log.warn("UserDatabaseSynchronizer: Cannot find student with code %d" % student_code)
					continue
				student_block.merge({
					"device_id": device_id,
					"name": student_data.name,
					"age": student_data.age,
					"updated_at": student_data.last_modified
				})

			elif student_update == UpdateNeeded.FromServer:
				student_block["need_update"] = true
		
		var student_progression: StudentProgression = UserDataManager.get_student_progression_for_code(0, student_code)
		if student_progression == null:
			Log.trace("Cannot find progression data for student %s" % str(student_code))
		elif student_entry.has("progression"):
			var progression_block: Dictionary = {}
			if student_entry.progression == UpdateNeeded.FromLocal:
				progression_block =	{
										"version": student_progression.version,
										"unlocked": student_progression.unlocks,
										"updated_at": student_progression.last_modified
									}
			elif student_entry.progression == UpdateNeeded.FromServer:
				progression_block = {"need_update": true}
			elif student_entry.progression == UpdateNeeded.DeleteServer:
				progression_block = {"delete": true}
			
			if progression_block.size() > 0:
				student_block["progression"] = progression_block
		
		var student_remediation: UserRemediation = UserDataManager.get_student_remediation_data(student_code)
		if student_entry.has("remediation_gp"):
			var gp_remediation_block: Dictionary = {}
			if student_entry.remediation_gp == UpdateNeeded.FromLocal:
				var tuple_list: Array = []
				for key: int in student_remediation.gps_scores.keys():
					tuple_list.append([key, student_remediation.gps_scores[key]])
				gp_remediation_block = {"score_remediation": tuple_list, "updated_at": student_remediation.gp_last_modified}
			elif student_entry.remediation_gp == UpdateNeeded.FromServer:
				gp_remediation_block = {"need_update": true}
			elif student_entry.remediation_gp == UpdateNeeded.DeleteServer:
				gp_remediation_block = {"delete": true}

			if gp_remediation_block.size() > 0:
				student_block["remediation_gp"] = gp_remediation_block
		
		if student_entry.has("remediation_syllables"):
			var syllables_remediation_block: Dictionary = {}
			if student_entry.remediation_syllables == UpdateNeeded.FromLocal:
				var tuple_list: Array = []
				for key: int in student_remediation.syllables_scores.keys():
					tuple_list.append([key, student_remediation.syllables_scores[key]])
				syllables_remediation_block = {"score_remediation": tuple_list, "updated_at": student_remediation.syllables_last_modified}
			elif student_entry.remediation_syllables == UpdateNeeded.FromServer:
				syllables_remediation_block = {"need_update": true}
			elif student_entry.remediation_syllables == UpdateNeeded.DeleteServer:
				syllables_remediation_block = {"delete": true}

			if syllables_remediation_block.size() > 0:
				student_block["remediation_syllables"] = syllables_remediation_block
		
		if student_entry.has("remediation_words"):
			var words_remediation_block: Dictionary = {}
			if student_entry.remediation_words == UpdateNeeded.FromLocal:
				var tuple_list: Array = []
				for key: int in student_remediation.words_scores.keys():
					tuple_list.append([key, student_remediation.words_scores[key]])
				words_remediation_block = {"score_remediation": tuple_list, "updated_at": student_remediation.words_last_modified}
			elif student_entry.remediation_words == UpdateNeeded.FromServer:
				words_remediation_block = {"need_update": true}
			elif student_entry.remediation_words == UpdateNeeded.DeleteServer:
				words_remediation_block = {"delete": true}

			if words_remediation_block.size() > 0:
				student_block["remediation_words"] = words_remediation_block

		var student_confusion_matrix: UserConfusionMatrix = UserDataManager.get_student_confusion_matrix_data(student_code)
		if student_entry.has("confusion_matrix_gp"):
			var gp_confusion_matrix_block: Dictionary = {}
			if student_entry.confusion_matrix_gp == UpdateNeeded.FromLocal:
				var tuple_list: Array = []
				for key: int in student_confusion_matrix.gp_scores.keys():
					tuple_list.append([key, student_confusion_matrix.gp_scores[key]])
				gp_confusion_matrix_block = {"confusion_matrix": tuple_list, "updated_at": student_confusion_matrix.gp_last_modified}
			elif student_entry.confusion_matrix_gp == UpdateNeeded.FromServer:
				gp_confusion_matrix_block = {"need_update": true}
			elif student_entry.confusion_matrix_gp == UpdateNeeded.DeleteServer:
				gp_confusion_matrix_block = {"delete": true}

			if gp_confusion_matrix_block.size() > 0:
				student_block["confusion_matrix_gp"] = gp_confusion_matrix_block

		if student_block.size() > 0:
			message_to_server["students"][student_code] = student_block

	if (message_to_server["students"] as Dictionary).is_empty():
		message_to_server.erase("students")

	return message_to_server


func _send_instructions(message_to_server: Dictionary) -> Dictionary:
	await set_loading_bar_progression(60.0)
	set_loading_bar_text("SYNCHRONIZATION_SEND_SERVER_INSTRUCTIONS")
	if message_to_server.keys().size() == 0:
		Log.trace("UserDatabaseSynchronizer: No instruction to send to server")
		return {}
	var res_get_server_instructions: Dictionary = await (ServerManager as ServerManagerClass).send_server_synchronization_instructions(message_to_server)
	if not res_get_server_instructions.success:
		Log.trace("UserDatabaseSynchronizer: Cannot send instructions to server. Canceling synchronization.")
		set_loading_bar_text("SYNCHRONIZATION_ERROR_NO_SERVER")
		stop_sync()
		return {}
	await set_loading_bar_progression(80.0)
	set_loading_bar_text("SYNCHRONIZATION_APPLY_LOCAL_INSTRUCTIONS")
	return res_get_server_instructions.body


func _apply_server_response(response_body: Dictionary) -> void:
	if response_body.has("user"):
		var response_user: Dictionary = response_body.user
		Log.trace("UserDatabaseSynchronizer: Updating user")
		if not response_user.has("account_type"):
			Log.warn("UserDatabaseSynchronizer: While updating user, no account_type found")
		else:
			UserDataManager.teacher_settings.account_type = response_user.account_type
		if not response_user.has("education_method"):
			Log.warn("UserDatabaseSynchronizer: While updating user, no education_method found")
		else:
			UserDataManager.teacher_settings.education_method = response_user.education_method
		if not response_user.has("last_modified"):
			Log.warn("UserDatabaseSynchronizer: While updating user, no last_modified found")
		else:
			UserDataManager.teacher_settings.last_modified = response_user.last_modified
	if response_body.has("students"):
		Log.trace("UserDatabaseSynchronizer: Updating students")
		var response_students: Dictionary = response_body.students
		for response_student_code: String in response_students.keys():
			var response_student_data: Dictionary = response_students[response_student_code]
			if validate_student_data(response_student_data):
				UserDataManager.teacher_settings.set_data_student_with_code(int(response_student_code), int(response_student_data.device_id as float), response_student_data.name as String, int(response_student_data.age as float), response_student_data.updated_at as String)
			if response_student_data.has("progression") and (response_student_data.progression as Dictionary).has("version") and (response_student_data.progression as Dictionary).has("unlocked") and (response_student_data.progression as Dictionary).has("updated_at"):
				# Cleaning data because of JSON parsing changing types int / float / string
				var received_unlock_data: Dictionary = response_student_data.progression.unlocked as Dictionary
				var new_unlock_data: Dictionary[int, Dictionary] = {}
				for key_lesson: Variant in received_unlock_data.keys():
					var key_lesson_int: int = int(str(key_lesson)) if str(key_lesson).is_valid_int() else -1
					if key_lesson_int == -1:
						Log.error("UserDatabaseSynchronizer: Received invalid key for lesson: %s" % str(key_lesson))
						continue
					new_unlock_data[key_lesson_int] = {"games": [], "look_and_learn": received_unlock_data[key_lesson]["look_and_learn"] as int}
					for game_result: Variant in received_unlock_data[key_lesson]["games"]:
						(new_unlock_data[key_lesson_int]["games"] as Array).push_back(game_result as int)
					new_unlock_data[key_lesson_int].merge({"last_duration": PackedInt32Array(received_unlock_data[key_lesson]["last_duration"] as Array)})
					new_unlock_data[key_lesson_int].merge({"total_duration": PackedInt32Array(received_unlock_data[key_lesson]["total_duration"] as Array)})
				UserDataManager.set_student_progression_data(int(response_student_code), response_student_data.progression.version as String, new_unlock_data, response_student_data.progression.updated_at as String)
			if response_student_data.has("remediation_gp") and (response_student_data.remediation_gp as Dictionary).has("score_remediation") and (response_student_data.remediation_gp as Dictionary).has("updated_at"):
				var new_array: Array = JSON.parse_string(response_student_data.remediation_gp.score_remediation as String) as Array
				if new_array == null:
					Log.warn("UserDatabaseSynchronizer: Cannot parse to JSON the received GP score remediation: %s" % response_student_data.remediation_gp.score_remediation as String)
				else:
					var new_gp_scores: Dictionary[int, int] = {}
					for index: int in range(new_array.size()):
						# TODO ADD SECURITY
						new_gp_scores[int(new_array[index][0] as float)] = int(new_array[index][1] as float)
					UserDataManager.set_student_remediation_gp_data(int(response_student_code), new_gp_scores, response_student_data.remediation_gp.updated_at as String)
			if response_student_data.has("remediation_syllables") and (response_student_data.remediation_syllables as Dictionary).has("score_remediation") and (response_student_data.remediation_syllables as Dictionary).has("updated_at"):
				var new_array: Array = JSON.parse_string(response_student_data.remediation_syllables.score_remediation as String) as Array
				if new_array == null:
					Log.warn("UserDatabaseSynchronizer: Cannot parse to JSON the received syllables score remediation: %s" % response_student_data.remediation_syllables.score_remediation as String)
				else:
					var new_syllables_scores: Dictionary[int, int] = {}
					for index: int in range(new_array.size()):
						# TODO ADD SECURITY
						new_syllables_scores[int(new_array[index][0] as float)] = int(new_array[index][1] as float)
					UserDataManager.set_student_remediation_syllables_data(int(response_student_code), new_syllables_scores, response_student_data.remediation_syllables.updated_at as String)
			if response_student_data.has("remediation_words") and (response_student_data.remediation_words as Dictionary).has("score_remediation") and (response_student_data.remediation_words as Dictionary).has("updated_at"):
				var new_array: Array = JSON.parse_string(response_student_data.remediation_words.score_remediation as String) as Array
				if new_array == null:
					Log.warn("UserDatabaseSynchronizer: Cannot parse to JSON the received words score remediation: %s" % response_student_data.remediation_words.score_remediation as String)
				else:
					var new_words_scores: Dictionary[int, int] = {}
					for index: int in range(new_array.size()):
						# TODO ADD SECURITY
						new_words_scores[int(new_array[index][0] as float)] = int(new_array[index][1] as float)
					UserDataManager.set_student_remediation_words_data(int(response_student_code), new_words_scores, response_student_data.remediation_words.updated_at as String)
			if response_student_data.has("confusion_matrix_gp") and (response_student_data.confusion_matrix_gp as Dictionary).has("confusion_matrix") and (response_student_data.confusion_matrix_gp as Dictionary).has("updated_at"):
				# TODO ADD SECURITY
				var new_array: Array = response_student_data.confusion_matrix_gp.confusion_matrix
				var new_confusion_matrix_gp: Dictionary[int, PackedInt32Array] = {}
				for index: int in range(new_array.size()):
					# TODO ADD SECURITY
					var sub_array: PackedInt32Array = []
					for subindex: int in range((new_array[index][1] as Array).size()):
						sub_array.append(int(new_array[index][1][subindex] as float))
					new_confusion_matrix_gp.set(int(new_array[index][0] as float), sub_array as PackedInt32Array)
				UserDataManager.set_student_confusion_matrix_gp_data(int(response_student_code), new_confusion_matrix_gp, response_student_data.confusion_matrix_gp.updated_at as String)


func synchronize() -> void:
	Log.trace("UserDatabaseSynchronizer: Start synchronizing user data.")
	if synchronizing:
		Log.trace("UserDatabaseSynchronizer: User synchronization already started, cancel double-call.")
		return
	await start_sync()

	if not await _check_internet():
		return

	var response_body: Dictionary = await _pull_timestamps()
	if response_body.is_empty():
		return

	var need_update_user: UpdateNeeded = _determine_user_update(response_body)
	if need_update_user == UpdateNeeded.Nothing:
		Log.trace("UserDatabaseSynchronizer: User data timestamp is the same in local and on server. No synchronization necessary")
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
	if message_to_server.keys().size() > 0:
		UserDataManager._save_device_settings()
		UserDataManager.save_teacher_settings()
	stop_sync(true)

#region utils

func validate_student_data(data: Dictionary) -> bool:
	var required_keys: Array[String] = ["device_id", "name", "age", "updated_at"]
	var missing: Array[String] = []
	for key: String in required_keys:
		if not data.has(key):
			missing.append(key)
	
	if missing.is_empty():
		return true

	Log.trace("UserDatabaseSynchronizer: Student data is incomplete. Missing keys: %s" % str(missing))
	return false


func set_loading_bar_progression(value_percent: float, wait_time: float = 0.2) -> void:
	if loading_popup != null:
		loading_popup.set_progress(value_percent)
		await loading_popup.get_tree().create_timer(wait_time).timeout


func set_loading_bar_text(message: String) -> void:
	if loading_popup != null:
		loading_popup.set_text(message)

#endregion
