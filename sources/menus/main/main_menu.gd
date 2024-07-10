extends Control

const adult_check_scene_path := "res://sources/menus/adult_check/adult_check.tscn"
const next_scene_path := "res://sources/menus/login/login.tscn"

@onready var version_label : Label = $Informations/BuildVersionValue
@onready var teacher_label : Label = $Informations/TeacherValue
@onready var device_id_label : Label = $Informations/DeviceIDValue

@onready var kalulu : Control = $Kalulu
@onready var user_selection : Control = $UserSelection
@onready var login_form : Control = %LoginForm
@onready var interface_left : MarginContainer = %InterfaceLeft


func _ready():
	version_label.text = ProjectSettings.get_setting("application/config/version")
	teacher_label.text = UserDataManager.get_device_settings().teacher
	device_id_label.text = str(UserDataManager.get_device_settings().device_id)
	OpeningCurtain.open()


func _on_main_button_pressed():
	if UserDataManager.get_device_settings().teacher:
		_on_login_in()
	else:
		kalulu.hide()
		kalulu.stop_speech()
		user_selection.show()
		interface_left.show()


func _on_back_button_pressed():
	login_form.hide()
	user_selection.hide()
	kalulu.show()
	interface_left.hide()


func _on_sign_in_teacher_pressed():
	user_selection.hide()
	kalulu.hide()
	login_form.show_form(true)


func _on_sign_in_parent_pressed():
	user_selection.hide()
	kalulu.hide()
	login_form.show_form(false)


func _on_register_pressed():
	await OpeningCurtain.close()
	get_tree().change_scene_to_file(adult_check_scene_path)


func _on_login_in():
	get_tree().change_scene_to_file(next_scene_path)
