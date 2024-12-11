extends Control

const main_menu_path := "res://sources/menus/main/main_menu.tscn"
const login_menu_path := "res://sources/menus/login/login.tscn"

const DeviceTab: = preload("res://sources/menus/settings/device_tab.gd")
const device_tab_scene : PackedScene = preload("res://sources/menus/settings/device_tab.tscn")
const ConfirmPopup: = preload("res://sources/ui/popup.gd")

@onready var devices_tab_container : TabContainer = %DevicesTabContainer
@onready var lesson_unlocks: LessonUnlocks = $LessonUnlocks
@onready var delete_popup: ConfirmPopup = %DeletePopup

var last_device_id: = -1

func _ready() -> void:
	_refresh_devices_tabs()
	OpeningCurtain.open()


func _refresh_devices_tabs() -> void:
	for child in devices_tab_container.get_children(false):
		child.queue_free()
	
	if not UserDataManager.teacher_settings:
		push_error("Teacher settings not found")
		return
	
	for device: int in UserDataManager.teacher_settings.students.keys():
		var device_tab: DeviceTab = device_tab_scene.instantiate()
		device_tab.name = tr("DEVICE_NUMBER").format({"number" : device})
		device_tab.device_id = device
		device_tab.students = UserDataManager.teacher_settings.students[device]
		devices_tab_container.add_child(device_tab)
		
		device_tab.student_pressed.connect(_on_student_pressed)
		
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


func _on_student_pressed(code: String) -> void:
	lesson_unlocks.student = code
	lesson_unlocks.show()


func _on_add_student_button_pressed() -> void:
	var current_tab: = devices_tab_container.get_current_tab_control() as DeviceTab
	if not current_tab:
		return
	# TODO Show the popup
	# TODO Hides/Disable the button when not online
	var res: = await ServerManager.add_student(current_tab.device_id)
	if res.code == 200:
		UserDataManager.update_configuration(res.body)
		current_tab.students = UserDataManager.teacher_settings.students[current_tab.device_id]
		current_tab.refresh()


func _on_add_device_button_pressed() -> void:
	# TODO Show the popup
	# TODO Hides/Disable the button when not online
	var res: = await ServerManager.add_student(last_device_id + 1)
	if res.code == 200:
		UserDataManager.update_configuration(res.body)
		_refresh_devices_tabs()
		devices_tab_container.current_tab = last_device_id
