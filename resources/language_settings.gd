extends Resource
class_name LanguageSettings

@export var language : String :
	set(value):
		language = value
		Database.language = value

func _init():
	var osLanguage = OS.get_locale_language();
	if osLanguage:
		language = osLanguage
	else:
		language = "fr"
