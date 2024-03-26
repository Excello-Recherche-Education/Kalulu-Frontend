extends OptionButton

var items : Array

func _ready():
	# Check the language_resources directory to fetch supported languages
	var dir = DirAccess.open("res://language_resources")
	var idx : int = 0
	for language_locale in dir.get_directories():
		if not language_locale:
			continue
		
		var language_locale_name : String = TranslationServer.get_locale_name(language_locale)
		
		if not language_locale_name:
			continue
		
		add_item(language_locale_name, idx)
		items.append(language_locale)
		if language_locale == UserDataManager.get_device_settings().language:
			select(idx)
		idx+=1


func get_selected_language() -> String:
	var id = get_selected_id()
	return items[id]


func _on_item_selected(index):
	UserDataManager.set_language(items[index])
