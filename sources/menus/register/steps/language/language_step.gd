@tool
class_name LanguageStep
extends Step

var items: Array[String] = []

@onready var language_field: OptionButton = %LanguageField


func on_enter() -> void:
	super.on_enter()
	items.clear()
	language_field.clear()
	Log.trace("Register/LanguageStep: populating supported locale list")
	var idx: int = 0
	for locale: String in Utils.SUPPORTED_LOCALES.keys():
		if not locale:
			continue
		var locale_name: String = Utils.SUPPORTED_LOCALES[locale]
		if not locale_name:
			continue
		language_field.add_item(locale_name, idx)
		items.append(locale)
		if locale == UserDataManager.get_device_settings().language:
			language_field.select(idx)
			Log.trace("Register/LanguageStep: preselected locale %s" % locale)
		idx += 1
	Log.info("Register/LanguageStep: loaded %d locale options" % items.size())


func get_selected_language() -> String:
	var id: int = language_field.get_selected_id()
	if id >= 0 and id < items.size():
		return items[id]
	return ""


func _on_language_selected(index: int) -> void:
	if index >= 0 and index < items.size():
		Log.info("Register/LanguageStep: user selected locale %s" % items[index])
		UserDataManager.set_language(items[index])


func _on_next() -> bool:
	var lang: String = get_selected_language()
	if lang:
		Log.info("Register/LanguageStep: confirming locale %s" % lang)
		UserDataManager.set_language(lang)
	else:
		Log.warn("Register/LanguageStep: proceeding without selected locale")
	return true
