extends Resource
class_name LanguageSettings

@export var language : String :
	set(value):
		language = value
		Database.language = value
