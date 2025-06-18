extends OptionButton

var items: Array[String] = []

func _ready() -> void:
	# Adds the supported locales to the field
	var idx: int = 0
	for language_locale: String in DeviceSettings.SUPPORTED_LOCALES:
		if not language_locale:
			continue
		
		var language_locale_name: String = TranslationServer.get_locale_name(language_locale)
		
		if not language_locale_name:
			continue
		
		add_item(language_locale_name, idx)
		items.append(language_locale)
		if language_locale == UserDataManager.get_device_settings().language:
			select(idx)
		idx+=1


func get_selected_language() -> String:
	var id: int = get_selected_id()
	return items[id]


func _on_item_selected(index: int) -> void:
	UserDataManager.set_language(items[index])
