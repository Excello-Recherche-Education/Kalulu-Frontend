extends Control

const KALULU := preload("res://sources/menus/main/kalulu.gd")
const ADULT_CHECK_SCENE_PATH: PackedScene = preload("res://sources/menus/adult_check/adult_check.tscn")
const LANGUAGE_CHECK_SCENE_PATH: PackedScene = preload("res://sources/menus/language_selection/language_check.tscn")

@onready var version_label: Label = $Informations/BuildVersionValue
@onready var teacher_label: Label = $Informations/TeacherValue
@onready var device_id_label: Label = $Informations/DeviceIDValue
@onready var kalulu: KALULU = $Kalulu
@onready var play_button: Button = %PlayButton
@onready var interface_left: MarginContainer = %InterfaceLeft
@onready var keyboard_spacer: KeyboardSpacer = %KeyboardSpacer
@onready var no_internet_popup: ConfirmPopup = $NoInternetPopup


func _ready() -> void:
	Log.info("MainMenu loaded successfulyy")
	version_label.text = ProjectSettings.get_setting("application/config/version")
	teacher_label.text = UserDataManager.get_device_settings().teacher
	device_id_label.text = str(UserDataManager.get_device_settings().device_id)
	OpeningCurtain.open()


func _on_main_button_pressed() -> void:
	Log.info("MainMenu: Main button pressed")
	play_button.set_disabled(true)
	if UserDataManager.get_device_settings().teacher:
		Log.info("MainMenu: Device settings has teacher info, so start auto login-in")
		_on_login_in()
	else:
		Log.info("MainMenu: Device settings has no teacher info, so we need to check internet to log-in and start")
		if await ServerManager.check_internet_access():
			Log.info("MainMenu: Internet available, we can let user register or login")
			kalulu.hide()
			kalulu.stop_speech()
			keyboard_spacer.show()
			interface_left.show()
		else:
			Log.info("MainMenu: Internet not available, user cannot register nor login")
			no_internet_popup.show()
	play_button.set_disabled(false)


func _on_back_button_pressed() -> void:
	keyboard_spacer.hide()
	kalulu.show()
	interface_left.hide()


func _on_register_pressed() -> void:
	await OpeningCurtain.close()
	var error: Error = get_tree().change_scene_to_packed(ADULT_CHECK_SCENE_PATH)
	if error != OK:
		Log.error(error_string(error))


func _on_login_in() -> void:
	Log.trace("MainMenu: Login-in, going to Language Check Scene")
	var error: Error = get_tree().change_scene_to_packed(LANGUAGE_CHECK_SCENE_PATH)
	if error != OK:
		Log.error(error_string(error))
