extends Control
class_name SettingsTeacherSettings

const MAIN_MENU_PATH: String = "res://sources/menus/main/main_menu.tscn"
const LOGIN_MENU_PATH: String = "res://sources/menus/login/login.tscn"
const DEVICE_SELECTION_SCENE_PATH: String = "res://sources/menus/device_selection/device_selection.tscn"

const DEVICE_TAB_SCENE: PackedScene = preload("res://sources/menus/settings/device_tab.tscn")

@onready var devices_tab_container: TabContainer = %DevicesTabContainer
@onready var lesson_unlocks: LessonUnlocks = $LessonUnlocks
@onready var delete_popup: ConfirmPopup = %DeletePopup
@onready var loading_popup: LoadingPopup = %LoadingPopup


@onready var account_type_option_button: OptionButton = %AccountTypeOptionButton
@onready var education_method_option_button: OptionButton = %EducationMethodOptionButton

@onready var add_device_button: Button = %AddDeviceButton
@onready var add_student_button: Button = %AddStudentButton
@onready var label_internet_mandatory: Label = %LabelInternetMandatory

@onready var add_device_popup: CanvasLayer = %AddDevicePopup
@onready var add_student_popup: CanvasLayer = %AddStudentPopup
@onready var delete_student_popup: CanvasLayer = %DeleteStudentPopup

var last_device_id: int = -1


func _ready() -> void:
	refresh_devices_tabs()
	
	# Internet mandatory to add student because only the server can ensure the student code is not a duplicate
	if await ServerManager.check_internet_access():
		add_device_button.show()
		add_student_button.show()
		label_internet_mandatory.hide()
	else:
		add_device_button.hide()
		add_student_button.hide()
		label_internet_mandatory.show()
	
	OpeningCurtain.open()
	lesson_unlocks.teacher_settings = self
	
	account_type_option_button.select(UserDataManager.teacher_settings.account_type)
	education_method_option_button.select(UserDataManager.teacher_settings.education_method)
	
	UserDataManager.user_database_synchronizer.loading_popup = loading_popup
	UserDataManager.user_database_synchronizer.account_type_option_button = account_type_option_button
	UserDataManager.user_database_synchronizer.education_method_option_button = education_method_option_button


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
		device_tab = DEVICE_TAB_SCENE.instantiate()
		devices_tab_container.add_child(device_tab)
		await get_tree().process_frame # Not optional or an auto-rename bug will occur on the tabs (especiallly if there are a lot of them)
		device_tab.device_id = device
		device_tab.students = UserDataManager.teacher_settings.students[device]
		device_tab.name = tr("DEVICE_NUMBER").format({"number": device})
		device_tab.student_pressed.connect(_on_student_pressed)
		device_tab.refresh()
		
		last_device_id = device


func _on_back_button_pressed() -> void:
	await OpeningCurtain.close()
	if not UserDataManager.get_device_settings().device_id:
		get_tree().change_scene_to_file(DEVICE_SELECTION_SCENE_PATH)
	else:
		get_tree().change_scene_to_file(LOGIN_MENU_PATH)


func _on_delete_button_pressed() -> void:
	delete_popup.show()


func _on_delete_popup_accepted() -> void:
	var res: Dictionary = await ServerManager.delete_account()
	if res.code == 200:
		UserDataManager.delete_teacher_data()
		UserDataManager.logout()
		get_tree().change_scene_to_file(MAIN_MENU_PATH)


func _on_logout_button_pressed() -> void:
	await OpeningCurtain.close()
	UserDataManager.logout()
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


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
	var res: Dictionary = await ServerManager.add_student({"device":  current_tab.device_id})
	if res.code == 200:
		UserDataManager.update_configuration(res.body as Dictionary)
		current_tab.students = UserDataManager.teacher_settings.students[current_tab.device_id]
		current_tab.refresh()
	else:
		Logger.error("SettingsTeacherSettings: Request to add student failed. Error code " + str(res.code))


func _on_add_device_button_pressed() -> void:
	add_device_popup.show()


func _on_add_device_popup_accepted() -> void:
	var res: Dictionary = await ServerManager.add_student({"device": last_device_id + 1})
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

#region Synchronization

func _on_synchronize_button_pressed() -> void:
	UserDataManager.user_database_synchronizer.synchronize()


func _on_loading_popup_ok() -> void:
	loading_popup.hide()


func _on_loading_popup_cancel() -> void:
	Logger.warn("SettingsTeacherSettings: User wanted to cancel synchronization but it is impossible to interrupt.")

#endregion
