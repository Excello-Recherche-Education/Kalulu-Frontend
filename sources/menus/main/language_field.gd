extends OptionButton

var items : Array

func _ready():
	# Check the language_resources directory to fetch supported languages
	var dir = DirAccess.open("res://language_resources")
	var idx : int = 0
	for language_locale in dir.get_directories():
		add_item(TranslationServer.get_locale_name(language_locale), idx)
		items.append(language_locale)
		if language_locale == UserDataManager.get_device_settings().language:
			select(idx)
		idx+=1


func get_selected_language() -> String:
	var id = get_selected_id()
	return items[id]
