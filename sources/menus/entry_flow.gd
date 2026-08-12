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
# Where the child ends up once the pack is in place: the access-code screen, or
# device selection first when this install has not been given a device yet.
const LOGIN_SCENE_PATH: String = "res://sources/menus/login/login.tscn"
const DEVICE_SELECTION_SCENE_PATH: String = "res://sources/menus/device_selection/device_selection.tscn"
const GREETING_SPEECH_CATEGORY: String = "title_screen"
const GREETING_SPEECH_NAME: String = "tuto_welcome_oneshot"


## Whether `settings` describes a signed-in device.
##
## Split out from has_connection_token so it can be exercised without
## substituting UserDataManager's live state. Doing that is not safe: the manager
## clears the device's teacher and saves it whenever it finds no settings, so a
## transient null in a test would log the real device out on disk.
static func is_signed_in(settings: TeacherSettings) -> bool:
	return settings != null and not settings.token.is_empty()


## True when this device holds a teacher's connection token.
static func has_connection_token() -> bool:
	return is_signed_in(UserDataManager.teacher_settings)


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


## Where a device goes once past the greeting, given whether it is signed in.
static func scene_for(signed_in: bool) -> String:
	return SIGNED_IN_SCENE_PATH if signed_in else WELCOME_SCENE_PATH


## The screen to open once the greeting is done, or skipped.
static func scene_after_greeting() -> String:
	return scene_for(has_connection_token())


## The child's own screens: the access-code screen, or device selection when
## this install has not been assigned a device yet.
static func device_scene() -> String:
	var settings: DeviceSettings = UserDataManager.get_device_settings()
	if settings and settings.device_id:
		return LOGIN_SCENE_PATH
	return DEVICE_SELECTION_SCENE_PATH


## Where the app belongs when it cannot reach the server, or "" for nowhere.
##
## Deliberately not the language check, even though that is where a signed-in
## device normally goes: the check is what sends it to the downloader in the first
## place, so returning there after a download failure would loop.
##
## An empty answer means every destination would bounce straight back, and the
## caller has to stay where it is instead.
static func scene_when_offline() -> String:
	return scene_when_offline_for(has_connection_token(), Database.is_open)


## The offline decision, given whether the device has an account and whether a
## language pack is usable.
##
## Split out so all four answers can be checked without substituting the live
## state: setting UserDataManager.teacher_settings to null logs the real device
## out on disk.
static func scene_when_offline_for(signed_in: bool, pack_usable: bool) -> String:
	if not signed_in:
		# The welcome screen needs no pack, so it is always somewhere to go.
		return WELCOME_SCENE_PATH
	if not pack_usable:
		# The child's screens need the pack: the access-code screen sends a device
		# without one straight back to the downloader, which would bounce between
		# the two forever. There is nowhere for it to go.
		return ""
	return device_scene()
