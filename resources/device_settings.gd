extends Resource
class_name DeviceSettings

@export var language : String :
	set(value):
		language = value
		Database.language = value
		TranslationServer.set_locale(value)
@export var teacher : String
@export var device_id : int


func init_OS_language() -> void:
	# Gets the OS language and checks if it is supported
	var osLanguage = OS.get_locale_language();
	if osLanguage and osLanguage in DirAccess.open("res://language_resources").get_directories():
		language = osLanguage
	
	if not language:
		language = "fr"


func get_folder_path() -> String:
	var file_path := "user://".path_join(teacher).path_join(str(device_id)).path_join(language)
	return file_path
