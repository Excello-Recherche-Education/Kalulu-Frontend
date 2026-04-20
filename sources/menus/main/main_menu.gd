extends Control

const KALULU: GDScript = preload("res://sources/menus/main/kalulu_main_menu.gd")
const ADULT_CHECK_SCENE_PATH: PackedScene = preload("res://sources/menus/adult_check/adult_check.tscn")
const LANGUAGE_CHECK_SCENE_PATH: PackedScene = preload("res://sources/menus/language_selection/language_check.tscn")
const DEVELOPER_SCENE_PATH: String = "res://sources/menus/settings/developer_settings.tscn"
const DEV_CLICK_THRESHOLD: int = 10 # Number of clicks needed to open Developer Settings
const DEV_CLICK_MAX_DELAY: float = 0.6 # Delay between each clicks (in seconds)

var dev_click_count: int = 0
var dev_last_click_time: float = 0.0

@onready var version_label: Label = $Informations/BuildVersionValue
@onready var version_click_area: Control = $Informations/VersionClickArea
@onready var teacher_label: Label = $Informations/TeacherValue
@onready var device_id_label: Label = $Informations/DeviceIDValue
@onready var kalulu: KALULU = $Kalulu
@onready var play_button: Button = %PlayButton
@onready var interface_left: MarginContainer = %InterfaceLeft
@onready var keyboard_spacer: KeyboardSpacer = %KeyboardSpacer
@onready var no_internet_popup: ConfirmPopup = $NoInternetPopup


func _ready() -> void:
	Log.info("MainMenu: Loaded successfuly")
	version_label.text = Utils.get_application_version_with_code()
	teacher_label.text = UserDataManager.get_device_settings().teacher
	device_id_label.text = str(UserDataManager.get_device_settings().device_id)
	version_click_area.gui_input.connect(_on_version_label_gui_input)
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


func _on_version_label_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var now: float = Time.get_ticks_msec() / 1000.0
			if now - dev_last_click_time <= DEV_CLICK_MAX_DELAY:
				dev_click_count += 1
			else:
				dev_click_count = 1
			dev_last_click_time = now
			if dev_click_count >= DEV_CLICK_THRESHOLD:
				dev_click_count = 0
				await OpeningCurtain.close()
				var current_scene: Node = get_tree().current_scene
				if not current_scene:
					Log.error("MainMenu: Developer Settings returning scene will be main menu because current scene is null")
				DeveloperSettings.return_path = current_scene.scene_file_path if current_scene else ""
				get_tree().change_scene_to_file(DEVELOPER_SCENE_PATH)
