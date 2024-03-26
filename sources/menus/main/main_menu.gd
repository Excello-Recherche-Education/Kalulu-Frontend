extends Control

const adult_check_scene_path := "res://sources/menus/adult_check/adult_check.tscn"
const next_scene_path := "res://sources/menus/login/login.tscn"
const register_scene_path := "res://sources/menus/register/register.tscn"

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
	
	var adult_check_scene : AdultCheck = load(adult_check_scene_path).instantiate()
	adult_check_scene.last_scene = get_tree().current_scene.scene_file_path
	adult_check_scene.next_scene = register_scene_path
	
	get_tree().get_root().get_child(get_tree().get_root().get_child_count() -1).queue_free()
	get_tree().get_root().add_child(adult_check_scene)


func _on_login_in():
	get_tree().change_scene_to_file(next_scene_path)
