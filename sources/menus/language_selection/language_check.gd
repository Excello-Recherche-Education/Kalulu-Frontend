extends Node

const ERROR_MESSAGES: Array[String] = [
	"NO_TEACHER_SETTINGS_ON_DEVICE",
	"LANGUAGE_NOT_SUPPORTED",
	"NO_VALID_LANGUAGE_DATA_AVAILABLE"
]
const PACKAGE_LOADER_SCENE_PATH: String = "res://sources/menus/language_selection/package_downloader.tscn"

var device_language: String
var teacher_settings: TeacherSettings

@onready var error_popup: ConfirmPopup = $ErrorPopup


func _ready() -> void:
	# Raised here for the same reason as in the package downloader it hands over
	# to: a teacher who has just logged in arrives with the curtain closed, and
	# the two server calls below take as long as they take. Behind a closed
	# curtain that is a black screen, and an error popup nobody can see -- this
	# one sits under the curtain's layer.
	OpeningCurtain.open()
	
	await get_tree().process_frame
	device_language = UserDataManager.get_device_settings().language
	Log.trace("LanguageCheck: Starting with device language %s" % device_language)
	# Check the teacher settings, if we are logged in (this scene should not be accessible otherwise)
	teacher_settings = UserDataManager.teacher_settings
	if not teacher_settings:
		Log.error("LanguageCheck: TeacherSettings not found")
		UserDataManager.logout()
		_show_error(ERROR_MESSAGES[0])
		return
	Log.trace("LanguageCheck: Re-validating language with server on every login")
	if not await ServerManager.check_internet_access():
		Log.trace("LanguageCheck: No internet access")
		try_with_local_data()
		return
	Log.trace("LanguageCheck: Internet access confirmed. Asking server for user language")
	var res: Dictionary = await ServerManager.get_user_language()
	if not res.has("code") or res.code != 200 or not res.has("body") or not (res.body as Dictionary).has("language"):
		Log.trace("LanguageCheck: Server answer is not usable")
		try_with_local_data()
		return
	var server_language: Variant = (res.body as Dictionary).language
	if server_language is String and server_language in Utils.SUPPORTED_LOCALES.keys():
		Log.trace("LanguageCheck: Language validated by server")
		teacher_settings.language = server_language
		teacher_settings.server_language_validated = true
		UserDataManager.set_language(server_language as String, true)
	else:
		Log.warn("LanguageCheck: Language received from server is invalid or not defined")
		var local_language: String = teacher_settings.language
		if not local_language in Utils.SUPPORTED_LOCALES.keys():
			if not device_language in Utils.SUPPORTED_LOCALES.keys():
				UserDataManager.logout()
				_show_error(ERROR_MESSAGES[2])
				return
			local_language = device_language
		res = await ServerManager.set_user_language(local_language)
		if res.has("code") and res.code == 200:
			UserDataManager.set_language(local_language, true)
		else:
			UserDataManager.set_language(local_language, false)

	UserDataManager.save_all()
	go_to_package_download()


func try_with_local_data() -> void:
	Log.trace("LanguageCheck: Try with local data")
	if device_language in Utils.SUPPORTED_LOCALES.keys():
		teacher_settings.language = device_language
		teacher_settings.server_language_validated = false
		go_to_package_download()
		return
	else:
		Log.error("LanguageCheck: Device language %s is not in supported languages" % device_language)
		_show_error(tr(ERROR_MESSAGES[1]) % device_language)
		return


func _show_error(message: String) -> void:
	error_popup.content_text = message
	error_popup.show()


func go_to_package_download() -> void:
	var error: Error = get_tree().change_scene_to_file(PACKAGE_LOADER_SCENE_PATH)
	if error != OK:
		Log.error(error_string(error))
		_show_error(error_string(error))
		
