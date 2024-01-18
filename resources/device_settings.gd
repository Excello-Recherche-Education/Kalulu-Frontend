extends Resource
class_name DeviceSettings

@export var language : String :
	set(value):
		language = value
		Database.language = value
		TranslationServer.set_locale(value)

@export var teacher : String
@export var device_id : String

# List of current known logins for teachers
const possible_logins: = {
	"kalulu" : "kalulu",
}

func _init():
	
	# Gets the OS language and Checks if it is supported
	var osLanguage = OS.get_locale_language();
	if osLanguage and osLanguage in DirAccess.open("res://language_resources").get_directories():
		language = osLanguage
	
	if not language:
		language = "fr"
		
	teacher = ""
	device_id = ""
