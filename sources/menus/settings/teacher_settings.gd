extends Control

const main_menu_path: String = "res://sources/menus/main/main_menu.tscn"
const login_menu_path: String = "res://sources/menus/login/login.tscn"

const device_tab_scene: PackedScene = preload("res://sources/menus/settings/device_tab.tscn")

@onready var devices_tab_container : TabContainer = %DevicesTabContainer
@onready var lesson_unlocks: LessonUnlocks = $LessonUnlocks
@onready var delete_popup: ConfirmPopup = %DeletePopup

@onready var add_device_button: Button = %AddDeviceButton
@onready var add_student_button: Button = %AddStudentButton

@onready var add_device_popup: CanvasLayer = %AddDevicePopup
@onready var add_student_popup: CanvasLayer = %AddStudentPopup
@onready var delete_student_popup: CanvasLayer = %DeleteStudentPopup

var last_device_id: = -1

func _ready() -> void:
	_refresh_devices_tabs()
	
	if await ServerManager.check_internet_access():
		add_device_button.show()
		add_student_button.show()
	else:
		add_device_button.hide()
		add_student_button.hide()
	
	OpeningCurtain.open()


func _refresh_devices_tabs() -> void:
	for child in devices_tab_container.get_children(false):
		child.queue_free()
	
	if not UserDataManager.teacher_settings:
		push_error("Teacher settings not found")
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
	get_tree().change_scene_to_file(login_menu_path)


func _on_delete_button_pressed() -> void:
	delete_popup.show()


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
	var current_tab: = devices_tab_container.get_current_tab_control() as DeviceTab
	if not current_tab:
		push_error("Error: DeviceTab not found in Teacher Settings")
		return
	var res: = await ServerManager.add_student({"device" :  current_tab.device_id})
	if res.code == 200:
		UserDataManager.update_configuration(res.body as Dictionary)
		current_tab.students = UserDataManager.teacher_settings.students[current_tab.device_id]
		current_tab.refresh()
	else:
		push_error("Request to add student failed in Teacher Settings. Error code " + str(res.code))


func _on_add_device_button_pressed() -> void:
	add_device_popup.show()


func _on_add_device_popup_accepted() -> void:
	var res: = await ServerManager.add_student({"device" : last_device_id + 1})
	if res.code == 200:
		UserDataManager.update_configuration(res.body as Dictionary)
		_refresh_devices_tabs()
		devices_tab_container.current_tab = last_device_id


func _on_lesson_unlocks_student_deleted(_code: int) -> void:
	delete_student_popup.show()


func _on_delete_student_popup_accepted() -> void:
	var current_tab: = devices_tab_container.get_current_tab_control() as DeviceTab
	if not current_tab:
		return
	var res: = await ServerManager.remove_student(int(lesson_unlocks.student))
	if res.code == 200:
		lesson_unlocks.hide()
		UserDataManager.update_configuration(res.body as Dictionary)
		current_tab.students = UserDataManager.teacher_settings.students[current_tab.device_id]
		current_tab.refresh()
