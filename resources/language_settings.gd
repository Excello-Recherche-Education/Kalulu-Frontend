extends Resource
class_name LanguageSettings

@export var language : String :
	set(value):
		language = value
		Database.language = value

@export var teacher : String
@export var device_id : String

func _init():
	var osLanguage = OS.get_locale_language();
	if osLanguage:
		language = osLanguage
	else:
		language = "fr"
