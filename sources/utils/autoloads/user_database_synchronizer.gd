extends Node
class_name UserDataBaseSynchronizer


var synchronizing: bool = false
var localStringTime: String= ""

var account_type_option_button: OptionButton
var education_method_option_button: OptionButton

var loading_popup: LoadingPopup


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
	Logger.trace("SettingsTeacherSettings: Start synchronizing user data.")
	if synchronizing:
		Logger.trace("SettingsTeacherSettings: User synchronization already started, cancel double-call.")
		return
	startSync()
	var resGetTeacherTimestamp: Dictionary = await ServerManager.get_user_data_timestamp()
	if resGetTeacherTimestamp.success:
		Logger.trace("SettingsTeacherSettings: Server timestamp for user data = " + str(resGetTeacherTimestamp.body["last_modified"]))
	else:
		Logger.trace("Cannot get server timestamp for user data. Canceling synchronization.")
		loading_popup.set_text("SYNCHRONIZATION_ERROR_NO_SERVER")
		stopSync()
		return
	var unixTimeServer: int = Time.get_unix_time_from_datetime_string(resGetTeacherTimestamp.body["last_modified"] as String)
	
	localStringTime = UserDataManager.teacher_settings.last_modified
	if localStringTime == "":
		var localResult: Dictionary = UserDataManager.get_latest_modification(UserDataManager.get_teacher_folder())
		if localResult.error == OK:
			localStringTime = Time.get_datetime_string_from_datetime_dict(localResult.modification_date as Dictionary, false)
			Logger.trace("SettingsTeacherSettings: Local user file timestamp = " + localStringTime)
		else:
			Logger.warn("SettingsTeacherSettings: Cannot find modification date for local user data: " + error_string(localResult.error as int))
			loading_popup.set_text("SYNCHRONIZATION_ERROR_NO_LOCAL_TIMESTAMP")
			stopSync()
			return
	var unixTimeLocal: int = Time.get_unix_time_from_datetime_string(localStringTime)
	
	if unixTimeLocal == unixTimeServer:
		Logger.trace("SettingsTeacherSettings: User data timestamp is the same in local and on server. No synchronization necessary")
		stopSync(true)
	elif unixTimeLocal > unixTimeServer:
		on_sync_from_local()
		return
	else: # unixTimeLocal < unixTimeServer
		on_sync_from_server()
		return


func on_sync_from_server() -> void:
	Logger.trace("SettingsTeacherSettings: Synchronization priority defined to server")
	await setLoadingProgression(1.0)
	var resGetUserData: Dictionary = await ServerManager.get_user_data()
	if resGetUserData.success:
		if resGetUserData.has("body"):
			var resultBody: Dictionary = resGetUserData.body
			if resultBody.has("account_type"):
				UserDataManager.teacher_settings.account_type = resultBody.account_type
				account_type_option_button.select(UserDataManager.teacher_settings.account_type)
			else:
				Logger.warn("SettingsTeacherSettings: user data received from the server has no account_type")
			if resultBody.has("education_method"):
				UserDataManager.teacher_settings.education_method = resultBody.education_method
				education_method_option_button.select(UserDataManager.teacher_settings.education_method)
			else:
				Logger.warn("SettingsTeacherSettings: user data received from the server has no education_method")
		else:
			Logger.warn("SettingsTeacherSettings: user data received from the server has no body")
			loading_popup.set_text("SYNCHRONIZATION_ERROR_NO_BODY_FROM_SERVER")
			stopSync()
			return
	else:
		if resGetUserData.has("body"):
			Logger.warn("SettingsTeacherSettings: Failed to get user data from the server: %s" % resGetUserData.body)
		else:
			Logger.warn("SettingsTeacherSettings: Failed to get user data from the server")
		loading_popup.set_text("SYNCHRONIZATION_ERROR_SERVER")
		stopSync()
		return
	stopSync(true)


func on_sync_from_local() -> void:
	Logger.trace("SettingsTeacherSettings: Synchronization priority defined to local")
	var numberOfStudents: int = UserDataManager.get_number_of_students()
	var numberOfUpdatesToDo: int = numberOfStudents + 1 # +1 for user data
	var percentOfUpdateForEachStep: float = 100.0/numberOfUpdatesToDo
	var currentUpdateProgression: float = 0.0
	await setLoadingProgression(1.0)
	loading_popup.set_text("SYNCHRONIZING_USER")
	var resSetUserData: Dictionary = await ServerManager.update_user_data(UserDataManager.teacher_settings, localStringTime, true)
	if resSetUserData.success:
		Logger.trace("SettingsTeacherSettings: user data successfully sent to the server")
		currentUpdateProgression += percentOfUpdateForEachStep
		await setLoadingProgression(currentUpdateProgression)
	else:
		Logger.warn("SettingsTeacherSettings: Failed to send update of user data to the server: %s" % resSetUserData.body)
		loading_popup.set_text("SYNCHRONIZATION_ERROR_FAIL_SEND_DATA_USER")
		stopSync()
		return
	
	var student_index: int = 0
	for student_data: StudentData in UserDataManager.teacher_settings.get_all_students_data():
		student_index = student_index + 1
		var gp_remediation_scores: UserRemediation = UserDataManager.get_student_remediation_data(student_data.code)
		var sync_student_text: String = tr("SYNCHRONIZING_STUDENT_%S")
		if student_data.name != "":
			loading_popup.set_text(sync_student_text % student_data.name)
		else:
			loading_popup.set_text(sync_student_text % student_index)
		var resUpdateStudentRemediationScores: Dictionary = await ServerManager.update_student_remediation_data(student_data.code, gp_remediation_scores)
		currentUpdateProgression += percentOfUpdateForEachStep
		await setLoadingProgression(currentUpdateProgression)
		if resUpdateStudentRemediationScores.success:
			continue
		else:
			loading_popup.set_text("SYNCHRONIZATION_ERROR_FAIL_SEND_DATA_STUDENT")
			Logger.warn("SettingsTeacherSettings: Failed to send update of student data to the server: %s" % resUpdateStudentRemediationScores.body)
			stopSync()
			return
	
	stopSync(true)


func setLoadingProgression(value: float, wait_time: float = 0.2) -> void:
	loading_popup.set_progress(value)
	await loading_popup.get_tree().create_timer(wait_time).timeout
