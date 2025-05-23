extends Control
class_name SettingsTeacherSettings

const main_menu_path: String = "res://sources/menus/main/main_menu.tscn"
const login_menu_path: String = "res://sources/menus/login/login.tscn"
const device_selection_scene_path: String = "res://sources/menus/device_selection/device_selection.tscn"

const device_tab_scene: PackedScene = preload("res://sources/menus/settings/device_tab.tscn")

@onready var devices_tab_container : TabContainer = %DevicesTabContainer
@onready var lesson_unlocks: LessonUnlocks = $LessonUnlocks
@onready var delete_popup: ConfirmPopup = %DeletePopup
@onready var sync_choice_popup: ConfirmPopup = %SyncChoicePopup
@onready var loading_popup: LoadingPopup = %LoadingPopup


@onready var account_type_option_button: OptionButton = %AccountTypeOptionButton
@onready var education_method_option_button: OptionButton = %EducationMethodOptionButton

@onready var add_device_button: Button = %AddDeviceButton
@onready var add_student_button: Button = %AddStudentButton

@onready var add_device_popup: CanvasLayer = %AddDevicePopup
@onready var add_student_popup: CanvasLayer = %AddStudentPopup
@onready var delete_student_popup: CanvasLayer = %DeleteStudentPopup

var last_device_id: int = -1

var synchronizing: bool = false

var localStringTime: String= ""

func _ready() -> void:
	refresh_devices_tabs()
	
	if await ServerManager.check_internet_access():
		add_device_button.show()
		add_student_button.show()
	else:
		add_device_button.hide()
		add_student_button.hide()
	
	OpeningCurtain.open()
	lesson_unlocks.teacher_settings = self
	
	account_type_option_button.select(UserDataManager.teacher_settings.account_type)
	education_method_option_button.select(UserDataManager.teacher_settings.education_method)

func _on_account_type_option_button_item_selected(index: int) -> void:
	if TeacherSettings.AccountType.values().has(index):
		UserDataManager.teacher_settings.account_type = index as TeacherSettings.AccountType
		UserDataManager.teacher_settings.last_modified = Time.get_datetime_string_from_system(true)
		UserDataManager.save_teacher_settings()
	else:
		Logger.warn("SettingsTeacherSettings: Cannot assign index %d to AccountType" % index)


func _on_education_method_option_button_item_selected(index: int) -> void:
	if TeacherSettings.EducationMethod.values().has(index):
		UserDataManager.teacher_settings.education_method = index as TeacherSettings.EducationMethod
		UserDataManager.teacher_settings.last_modified = Time.get_datetime_string_from_system(true)
		UserDataManager.save_teacher_settings()
	else:
		Logger.warn("SettingsTeacherSettings: Cannot assign index %d to EducationMethod" % index)


func refresh_devices_tabs() -> void:
	for child: Node in devices_tab_container.get_children(false):
		child.queue_free()
	
	if not UserDataManager.teacher_settings:
		Logger.error("SettingsTeacherSettings: Teacher settings not found")
		return
	
	for device: int in UserDataManager.teacher_settings.students.keys():
		var device_tab: DeviceTab
		device_tab = device_tab_scene.instantiate()
		devices_tab_container.add_child(device_tab)
		await get_tree().process_frame # Not optional or an auto-rename bug will occur on the tabs (especiallly if there are a lot of them)
		device_tab.device_id = device
		device_tab.students = UserDataManager.teacher_settings.students[device]
		device_tab.name = tr("DEVICE_NUMBER").format({"number" : device})
		device_tab.student_pressed.connect(_on_student_pressed)
		device_tab.refresh()
		
		last_device_id = device


func _on_back_button_pressed() -> void:
	await OpeningCurtain.close()
	if not UserDataManager.get_device_settings().device_id:
		get_tree().change_scene_to_file(device_selection_scene_path)
	else:
		get_tree().change_scene_to_file(login_menu_path)


func _on_delete_button_pressed() -> void:
	delete_popup.show()


func startSync() -> void:
	synchronizing = true
	loading_popup.set_finished(false)
	loading_popup.set_progress(0.0)
	loading_popup.show()


func stopSync(success: bool = false) -> void:
	synchronizing = false
	if success:
		loading_popup.set_progress(100.0)
		await get_tree().create_timer(1).timeout
	loading_popup.set_finished(true)


func _on_synchronize_button_pressed() -> void:
	#synchronizing = false
	#await ServerManager.update_user_data(UserDataManager.teacher_settings, "2025-05-23T09:39:47", true)
	#return
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
			stopSync()
			return
	var localUnixTime: int = Time.get_unix_time_from_datetime_string(localStringTime)
	
	if localUnixTime == unixTimeServer:
		Logger.trace("SettingsTeacherSettings: User data timestamp is the same in local and on server. No synchronization necessary")
	elif localUnixTime > unixTimeServer:
		_on_sync_choice_local()
		return
	else:
		Logger.trace("SettingsTeacherSettings: Local user data timestamp is obsolete, we need to choose a priority")
		sync_choice_popup.show()
		return
	stopSync(true)


func _on_delete_popup_accepted() -> void:
	var res: Dictionary = await ServerManager.delete_account()
	if res.code == 200:
		UserDataManager.delete_teacher_data()
		UserDataManager.logout()
		get_tree().change_scene_to_file(main_menu_path)


func _on_logout_button_pressed() -> void:
	await OpeningCurtain.close()
	UserDataManager.logout()
	get_tree().change_scene_to_file(main_menu_path)


func _on_devices_tab_container_tab_changed(tab: int) -> void:
	lesson_unlocks.device = tab + 1


func _on_student_pressed(code: int) -> void:
	lesson_unlocks.student = code
	lesson_unlocks.show()


func _on_add_student_button_pressed() -> void:
	add_student_popup.show()


func _on_add_student_popup_accepted() -> void:
	var current_tab: DeviceTab = devices_tab_container.get_current_tab_control() as DeviceTab
	if not current_tab:
		Logger.error("SettingsTeacherSettings: DeviceTab not found")
		return
	var res: Dictionary = await ServerManager.add_student({"device" :  current_tab.device_id})
	if res.code == 200:
		UserDataManager.update_configuration(res.body as Dictionary)
		current_tab.students = UserDataManager.teacher_settings.students[current_tab.device_id]
		current_tab.refresh()
	else:
		Logger.error("SettingsTeacherSettings: Request to add student failed. Error code " + str(res.code))


func _on_add_device_button_pressed() -> void:
	add_device_popup.show()


func _on_add_device_popup_accepted() -> void:
	var res: Dictionary = await ServerManager.add_student({"device" : last_device_id + 1})
	if res.code == 200:
		UserDataManager.update_configuration(res.body as Dictionary)
		refresh_devices_tabs()
		await get_tree().create_timer(1).timeout
		var count: int = devices_tab_container.get_tab_count()
		devices_tab_container.current_tab = count -1


func _on_lesson_unlocks_student_deleted(_code: int) -> void:
	delete_student_popup.show()


func _on_delete_student_popup_accepted() -> void:
	var current_tab: DeviceTab = devices_tab_container.get_current_tab_control() as DeviceTab
	if not current_tab:
		return
	var res: Dictionary = await ServerManager.remove_student(int(lesson_unlocks.student))
	if res.code == 200:
		lesson_unlocks.hide()
		UserDataManager.update_configuration(res.body as Dictionary)
		await get_tree().create_timer(1).timeout
		if UserDataManager.teacher_settings.students.has(current_tab.device_id):
			current_tab.students = UserDataManager.teacher_settings.students[current_tab.device_id]
			current_tab.refresh()
		else:
			refresh_devices_tabs()


func update_student_name(student_code: int, student_name: String) -> void:
	for device: DeviceTab in devices_tab_container.get_children(false):
		for student_panel: StudentPanel in device.students_container.get_children(false):
			if student_panel.student_data.code == student_code:
				student_panel.name_label.text = student_name
				return
	Logger.warn("SettingsTeacherSettings: update_student_name: student not found with code " + str(student_code))


func _on_sync_choice_server() -> void:
	Logger.trace("SettingsTeacherSettings: Synchronization priority defined to server")
	var resGetUserData: Dictionary = await ServerManager.get_user_data()
	if resGetUserData.success:
		if resGetUserData.has("body"):
			# {"email": "cvbn@yopmail.com", "account_type": 0, "education_method": 0, "created_at": "2025-05-15T12:27:34Z", "last_modified": "2025-05-22T14:05:42Z"}
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
			stopSync()
			return
	else:
		Logger.warn("SettingsTeacherSettings: Failed to get user data from the server")
		stopSync()
		return
	stopSync(true)


func _on_sync_choice_local() -> void:
	Logger.trace("SettingsTeacherSettings: Synchronization priority defined to local")
	var resSetUserTimestamp: Dictionary = await ServerManager.update_user_data(UserDataManager.teacher_settings, localStringTime, true)
	if resSetUserTimestamp.success:
		Logger.trace("SettingsTeacherSettings: user data successfully sent to the server")
		stopSync(true)
	else:
		Logger.warn("SettingsTeacherSettings: Failed to send update of user data to the server")
		stopSync()


func _on_loading_popup_ok() -> void:
	loading_popup.hide()


func _on_loading_popup_cancel() -> void:
	#TODO
	loading_popup.hide()
