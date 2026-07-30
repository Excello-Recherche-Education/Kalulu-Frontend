class_name EntryFlow
extends Object
## Decides which screen the app opens on.
##
## The entry sequence is: the Kalulu splash, always; then Kalulu's spoken
## greeting, but only when the language pack is installed and the speech can
## actually be played; then either the welcome screen or, for a device that is
## already signed in, the child's access-code screen.
##
## The routing lives here rather than in the scenes because two of them need the
## same answer -- the splash when the greeting is skipped, and the greeting when
## it finishes -- and because it is worth being able to test the decision without
## standing up any scene.

const SPLASH_SCENE_PATH: String = "res://sources/menus/splash_screen/splash_screen.tscn"
const GREETING_SCENE_PATH: String = "res://sources/menus/welcome/kalulu_greeting.tscn"
const WELCOME_SCENE_PATH: String = "res://sources/menus/welcome/welcome.tscn"
# A signed-in device goes through the language check, which revalidates the
# language with the server and installs any pack update before the package
# downloader hands over to the device or access-code screen.
const SIGNED_IN_SCENE_PATH: String = "res://sources/menus/language_selection/language_check.tscn"
const GREETING_SPEECH_CATEGORY: String = "title_screen"
const GREETING_SPEECH_NAME: String = "tuto_welcome_oneshot"


## True when this device holds a teacher's connection token.
static func has_connection_token() -> bool:
	var settings: TeacherSettings = UserDataManager.teacher_settings
	return settings != null and not settings.token.is_empty()


## Where Kalulu's greeting speech would be, for the installed language.
static func greeting_speech_path() -> String:
	return Database.get_kalulu_speech_path(GREETING_SPEECH_CATEGORY, GREETING_SPEECH_NAME)


## True when the greeting can be spoken, so the greeting screen is worth showing.
##
## Deliberately a file-existence check rather than a load: on a fresh install
## the pack is not there and Database.load_external_sound would log an error
## every launch for a situation that is entirely expected.
static func greeting_speech_available() -> bool:
	if not Database.is_open:
		return false
	return FileAccess.file_exists(Utils.get_safe_file_path(greeting_speech_path()))


## The screen to open once the splash has been shown.
static func scene_after_splash() -> String:
	if greeting_speech_available():
		return GREETING_SCENE_PATH
	return scene_after_greeting()


## The screen to open once the greeting is done, or skipped.
static func scene_after_greeting() -> String:
	if has_connection_token():
		return SIGNED_IN_SCENE_PATH
	return WELCOME_SCENE_PATH
