@tool
class_name DeviceSettings
extends Resource

@export var language: String:
	set(value):
		Log.trace("DeviceSettings: set language from %s to %s" % [language, value])
		language = value
		if Database != null:
			Database.language = value # Database language should be set by TeacherSettings, but this is useful when game starts to know which "welcome" audio speech to play.
		else:
			Log.warn("DeviceSettings: Database is null")
		TranslationServer.set_locale(value)
@export var teacher: String
@export var device_id: int
@export var language_versions: Dictionary = {} # locale: datetime
@export var game_version: String = "0.0.1"
@export var master_volume: float = 0.0:
	set(volume):
		Log.trace("DeviceSettings: set master_volume from %.2f to %.2f" % [master_volume, volume])
		master_volume = volume
		var ind: int = AudioServer.get_bus_index("Master")
		AudioServer.set_bus_volume_db(ind, volume)
@export var music_volume: float = 0.0:
	set(volume):
		Log.trace("DeviceSettings: set music_volume from %.2f to %.2f" % [music_volume, volume])
		music_volume = volume
		var ind: int = AudioServer.get_bus_index("Music")
		AudioServer.set_bus_volume_db(ind, volume)
@export var voice_volume: float = 0.0:
	set(volume):
		Log.trace("DeviceSettings: set voice_volume from %.2f to %.2f" % [voice_volume, volume])
		voice_volume = volume
		var ind: int = AudioServer.get_bus_index("Voice")
		AudioServer.set_bus_volume_db(ind, volume)
@export var effects_volume: float = 0.0:
	set(volume):
		Log.trace("DeviceSettings: set effects_volume from %.2f to %.2f" % [effects_volume, volume])
		effects_volume = volume
		var ind: int = AudioServer.get_bus_index("Effects")
		AudioServer.set_bus_volume_db(ind, volume)
@export var log_level: Log.LogLevel = Log.LogLevel.INFO


func _init() -> void:
	Log.trace("DeviceSettings: Initialization")


func init_os_language() -> void:
	# Gets the OS language and checks if it is supported
	var os_language: String = OS.get_locale();
	Log.trace("DeviceSettings: detected OS locale %s" % os_language)
	if os_language and os_language in Utils.SUPPORTED_LOCALES.keys():
		language = os_language
		Log.trace("DeviceSettings: using OS locale %s" % language)

	if not language:
		language = Utils.SUPPORTED_LOCALES.keys()[0]
		Log.warn("DeviceSettings: OS locale unsupported, fallback to %s" % language)


func get_folder_path() -> String:
	var file_path: String = "user://".path_join(teacher).path_join(str(device_id)).path_join(language)
	Log.trace("DeviceSettings: resolved folder path %s" % file_path)
	return file_path


func validate() -> bool:
	if language not in Utils.SUPPORTED_LOCALES.keys():
		Log.warn("DeviceSettings: language %s is not supported, reinitializing" % language)
		init_os_language()
		return false
	Log.trace("DeviceSettings: language %s validated" % language)
	return true
