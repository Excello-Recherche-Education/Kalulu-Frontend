extends OptionButton
## Picks the app's language and applies it straight away.
##
## Connects its own item_selected rather than leaving that to whichever screen
## uses it. The welcome screen carried this field over from the old main menu
## without the connection, so changing the language did nothing: the field showed
## the language that had been chosen and the app stayed in the previous one.

var items: Array[String] = []


func _ready() -> void:
	# Guarded because main_menu.tscn still makes this connection in the scene, and
	# Godot errors on connecting the same callable twice.
	if not item_selected.is_connected(_on_item_selected):
		item_selected.connect(_on_item_selected)

	# Adds the supported locales to the field
	var idx: int = 0
	for language_locale: String in Utils.SUPPORTED_LOCALES.keys():
		if not language_locale:
			continue
		var language_locale_name: String = Utils.SUPPORTED_LOCALES[language_locale]
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
