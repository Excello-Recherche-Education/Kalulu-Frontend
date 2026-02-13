extends Control

const TEACHER_PASSWORD: String = "42"
const BACK_SCENE_PATH: String = "res://sources/menus/main/main_menu.tscn"
const NEXT_SCENE_PATH: String = "res://sources/menus/brain/brain.tscn"
const TEACHER_SCENE_PATH: String = "res://sources/menus/settings/teacher_settings.tscn"
const DEVELOPER_SCENE_PATH: String = "res://sources/menus/settings/developer_settings.tscn"
const PACKAGE_LOADER_SCENE_PATH: String = "res://sources/menus/language_selection/package_downloader.tscn"
const KALULU: GDScript = preload("res://sources/minigames/base/kalulu_ingame.gd")
const DEV_CLICK_THRESHOLD: int = 10 # Number of clicks needed to open Developer Settings
const DEV_CLICK_MAX_DELAY: float = 0.6 # Delay between each clicks (in seconds)

var help_speech: AudioStream
var wrong_password_speech: AudioStream
var right_password_speech: AudioStream
var dev_click_count: int = 0
var dev_last_click_time: float = 0.0

@onready var kalulu: KALULU = $Kalulu
@onready var music_player: AudioStreamPlayer = $MusicStreamPlayer
@onready var device_number_label: Label = $DeviceNumber
@onready var keyboard: CodeKeyboard = $CodeKeyboard
@onready var teacher_timer: Timer = %TeacherTimer
@onready var teacher_help_label: Label = %TeacherHelpLabel
@onready var kalulu_button: CanvasItem = %KaluluButton
@onready var version_label: Label = %BuildVersionValue


func _ready() -> void:
	UserDataManager.stop_synchronization_timer()
	
	# Check if the database is connected, if not go to loader
	if not Database.is_open:
		Log.warn("LoginScreen: Database closed, redirecting to package loader")
		await get_tree().process_frame
		get_tree().change_scene_to_file(PACKAGE_LOADER_SCENE_PATH)
	
	help_speech = Database.load_external_sound(Database.get_kalulu_speech_path("login_screen", "help_code"))
	wrong_password_speech = Database.load_external_sound(Database.get_kalulu_speech_path("login_screen", "feedback_wrong_password"))
	right_password_speech = Database.load_external_sound(Database.get_kalulu_speech_path("login_screen", "feedback_right_password"))
	
	device_number_label.show()
	device_number_label.text = tr("DEVICE_NUMBER").format({"number": UserDataManager.get_device_settings().device_id})
	
	version_label.text = ProjectSettings.get_setting("application/config/version")
	version_label.gui_input.connect(_on_version_label_gui_input)
	Log.info("LoginScreen: Ready (device_id=%s, version=%s)" % [UserDataManager.get_device_settings().device_id, version_label.text])
	
	await OpeningCurtain.open()
	
	kalulu_button.hide()
	await kalulu.play_kalulu_speech(help_speech)
	kalulu_button.show()
	
	music_player.play()


func _on_code_keyboard_password_entered(password: String) -> void:
	Log.info("LoginScreen: Student code entered (length=%d)" % password.length())
	if UserDataManager.student_exists(password):
		Log.info("LoginScreen: Student code %s found locally, synchronizing before login" % password)
		await UserDataManager.user_database_synchronizer.synchronize()
		var login_success: bool = UserDataManager.login_student(password)
		Log.info("LoginScreen: Login attempt for student code %s returned %s" % [password, str(login_success)])
		kalulu_button.hide()
		await kalulu.play_kalulu_speech(right_password_speech)
		await OpeningCurtain.close()
		get_tree().change_scene_to_file(NEXT_SCENE_PATH)
	else:
		Log.warn("LoginScreen: Unknown student code entered (length=%d)" % password.length())
		kalulu_button.hide()
		await kalulu.play_kalulu_speech(wrong_password_speech)
		keyboard.reset_password()


func _on_back_button_pressed() -> void:
	Log.trace("LoginScreen: Back button pressed, returning to main menu")
	get_tree().change_scene_to_file(BACK_SCENE_PATH)


func _on_kalulu_button_pressed() -> void:
	Log.trace("LoginScreen: Help speech requested")
	kalulu_button.hide()
	await kalulu.play_kalulu_speech(help_speech)
	kalulu_button.show()


func _on_teacher_button_button_down() -> void:
	if keyboard.get_password_as_string() != TEACHER_PASSWORD:
		Log.warn("LoginScreen: Teacher button pressed with incorrect password")
		return
	Log.info("LoginScreen: Teacher button pressed with correct password, starting timer")
	teacher_timer.start()


func _on_teacher_button_button_up() -> void:
	Log.trace("LoginScreen: Teacher button released, showing help label")
	teacher_help_label.show()
	teacher_timer.stop()


func _on_teacher_timer_timeout() -> void:
	Log.info("LoginScreen: Teacher timer elapsed, opening teacher settings")
	teacher_help_label.hide()
	await OpeningCurtain.close()
	get_tree().change_scene_to_file(TEACHER_SCENE_PATH)


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
				Log.info("LoginScreen: Developer click threshold reached, opening Developer Settings")
				dev_click_count = 0
				await OpeningCurtain.close()
				DeveloperSettings.return_path = get_tree().current_scene.scene_file_path
				get_tree().change_scene_to_file(DEVELOPER_SCENE_PATH)
