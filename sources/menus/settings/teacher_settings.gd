extends Control

const main_menu_path := "res://sources/menus/main/main_menu.tscn"
const login_menu_path := "res://sources/menus/login/login.tscn"

const device_tab_scene : PackedScene = preload("res://sources/menus/settings/device_tab.tscn")

@onready var devices_tab_container : TabContainer = %DevicesTabContainer

func _ready():
	_refresh_devices_tabs()


func _refresh_devices_tabs() -> void:
	for child in devices_tab_container.get_children(false):
		child.queue_free()
	
	if not UserDataManager.teacher_settings:
		push_error("Teacher settings not found")
		return
	
	for device in UserDataManager.teacher_settings.students.keys():
		var device_tab := device_tab_scene.instantiate()
		device_tab.name = "Device " + str(device)
		device_tab.device_id = device
		device_tab.students = UserDataManager.teacher_settings.students[device]
		devices_tab_container.add_child(device_tab)


func _on_back_button_pressed():
	get_tree().change_scene_to_file(login_menu_path)


func _on_logout_button_pressed():
	UserDataManager.logout()
	get_tree().change_scene_to_file(main_menu_path)


func _on_add_student_button_pressed():
	var current_tab = devices_tab_container.get_current_tab_control() as DeviceTab
	if not current_tab:
		return
	
	# TODO If parent -> show a creation popup
	# TODO If teacher -> create a default student
	
	if UserDataManager.add_default_student(current_tab.device_id):
		current_tab.students = UserDataManager.teacher_settings.students[current_tab.device_id]
		current_tab.refresh()


func _on_add_device_button_pressed():
	if UserDataManager.add_device():
		_refresh_devices_tabs()
