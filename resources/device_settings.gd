extends Resource
class_name DeviceSettings


const supported_locales: Array[String] = [
	"fr_FR",	
]

@export var language : String :
	set(value):
		language = value
		Database.language = value
		TranslationServer.set_locale(value)
@export var teacher : String
@export var device_id : int


func init_OS_language() -> void:
	# Gets the OS language and checks if it is supported
	var osLanguage: = OS.get_locale();
	if osLanguage and osLanguage in supported_locales:
		language = osLanguage
	
	if not language:
		language = supported_locales[0]
	
	print("------- DEFAULT LANGUAGE SET TO " + str(language))


func get_folder_path() -> String:
	var file_path := "user://".path_join(teacher).path_join(str(device_id)).path_join(language)
	return file_path


func validate() -> bool:
	if language not in supported_locales:
		init_OS_language()
		return false
	return true
