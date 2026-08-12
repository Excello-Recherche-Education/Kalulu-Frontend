extends Control

const BACK_SCENE_PATH: String = EntryFlow.DEVICE_SELECTION_SCENE_PATH
const NEXT_SCENE_PATH: String = "res://sources/gardens/gardens.tscn"
const TEACHER_SCENE_PATH: String = "res://sources/menus/settings/teacher_settings.tscn"
const PACKAGE_LOADER_SCENE_PATH: String = "res://sources/menus/language_selection/package_downloader.tscn"
const KALULU: GDScript = preload("res://sources/minigames/base/kalulu_ingame.gd")

var help_speech: AudioStream
var wrong_password_speech: AudioStream
var right_password_speech: AudioStream

@onready var kalulu: KALULU = %Kalulu
@onready var music_player: AudioStreamPlayer = $MusicStreamPlayer
@onready var device_number_label: Label = %DeviceNumber
@onready var keypad: CodeKeypad = %CodeKeypad
@onready var adult_check: AdultCheckPopup = %AdultCheck
@onready var kalulu_button: CanvasItem = %KaluluButton


func _ready() -> void:
	UserDataManager.stop_synchronization_timer()
	
	# Check if the database is connected, if not go to loader
	if not Database.is_open:
		Log.warn("LoginScreen: Database closed, redirecting to package loader")
		await get_tree().process_frame
		get_tree().change_scene_to_file(PACKAGE_LOADER_SCENE_PATH)
	
	# The synchronization asked for at teacher login is postponed until the
	# language pack is installed. This screen is the first one reached with the
	# database open, so catch up here: without it the students stay blank until
	# someone presses Synchronize by hand.
	if UserDataManager.user_database_synchronizer.postponed:
		Log.info("LoginScreen: Running the synchronization postponed during login")
		await UserDataManager.user_database_synchronizer.synchronize()

	help_speech = Database.load_external_sound(Database.get_kalulu_speech_path("login_screen", "help_code"))
	wrong_password_speech = Database.load_external_sound(Database.get_kalulu_speech_path("login_screen", "feedback_wrong_password"))
	right_password_speech = Database.load_external_sound(Database.get_kalulu_speech_path("login_screen", "feedback_right_password"))
	
	device_number_label.text = tr("LOG_IN_TO_DEVICE").format({"number": UserDataManager.get_device_settings().device_id})
	
	Log.info("LoginScreen: Ready (device_id=%s)" % UserDataManager.get_device_settings().device_id)
	
	await OpeningCurtain.open()
	
	kalulu_button.hide()
	await kalulu.play_kalulu_speech(help_speech)
	kalulu_button.show()
	
	music_player.play()


func _on_code_keypad_code_entered(password: String) -> void:
	Log.info("LoginScreen: Student code entered (length=%d)" % password.length())
	if UserDataManager.student_exists(password):
		Log.info("LoginScreen: Student code %s found locally, synchronizing before login" % password)
		await UserDataManager.user_database_synchronizer.synchronize()
		var login_success: bool = UserDataManager.login_student(password)
		Log.info("LoginScreen: Login attempt for student code %s returned %s" % [password, str(login_success)])
		kalulu_button.hide()
		if not login_success:
			# The synchronization above may have deleted or moved the student
			Log.warn("LoginScreen: Login failed for student code %s after synchronization" % password)
			await kalulu.play_kalulu_speech(wrong_password_speech)
			keypad.clear()
			kalulu_button.show()
			return
		await kalulu.play_kalulu_speech(right_password_speech)
		await OpeningCurtain.close()
		Log.trace("LoginScreen: Start loading next scene")
		SceneLoader.change_scene(NEXT_SCENE_PATH)
	else:
		Log.warn("LoginScreen: Unknown student code entered (length=%d)" % password.length())
		kalulu_button.hide()
		await kalulu.play_kalulu_speech(wrong_password_speech)
		keypad.clear()


func _on_back_button_pressed() -> void:
	Log.trace("LoginScreen: Back button pressed, returning to device selection")
	get_tree().change_scene_to_file(BACK_SCENE_PATH)


func _on_kalulu_button_pressed() -> void:
	Log.trace("LoginScreen: Help speech requested")
	kalulu_button.hide()
	await kalulu.play_kalulu_speech(help_speech)
	kalulu_button.show()


func _on_teacher_button_pressed() -> void:
	# The settings used to be behind a two-symbol code and a five-second hold on
	# this button, spelled out in the help text next to it. The adult check asks
	# the same question -- can you read this? -- in one step, and it is the same
	# check the sign-up tab and the boss minigame already use.
	Log.info("LoginScreen: Asking the adult check before opening the teacher settings")
	adult_check.open()


func _on_adult_check_passed() -> void:
	Log.info("LoginScreen: Adult check passed, opening teacher settings")
	await OpeningCurtain.close()
	get_tree().change_scene_to_file(TEACHER_SCENE_PATH)
