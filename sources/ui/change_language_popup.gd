@tool
class_name ChangeLanguagePopup
extends CanvasLayer

signal accepted(language: String)
signal refused()

@export_multiline var content_text: String = "CHANGE_LANGUAGE_POPUP": set = _set_content_text
@export var close_on_action: bool = true

var _locales: Array[String] = []

@onready var content_label: Label = %ChangeLanguageContentLabel
@onready var language_field: OptionButton = %ChangeLanguageLanguageField
@onready var confirm_button: Button = %ChangeLanguageConfirmButton
@onready var cancel_button: Button = %ChangeLanguageCancelButton


func _ready() -> void:
	_set_content_text(content_text)
	if not Engine.is_editor_hint():
		_populate_language_field()


func show_for_current_language(current_language: String) -> void:
	_populate_language_field(current_language)
	show()


func get_selected_language() -> String:
	if not language_field:
		return ""
	var selected_id: int = language_field.get_selected_id()
	if selected_id < 0 or selected_id >= _locales.size():
		return ""
	return _locales[selected_id]


func _populate_language_field(preselected_locale: String = "") -> void:
	if not language_field:
		return
	_locales.clear()
	language_field.clear()
	var index: int = 0
	for locale: String in Utils.SUPPORTED_LOCALES.keys():
		if not locale:
			continue
		var locale_name: String = Utils.SUPPORTED_LOCALES[locale]
		if not locale_name:
			continue
		language_field.add_item(locale_name, index)
		_locales.append(locale)
		if locale == preselected_locale:
			language_field.select(index)
		index += 1
	if language_field.get_selected_id() == -1 and _locales.size() > 0:
		language_field.select(0)


func _set_content_text(p_content_text: String) -> void:
	content_text = p_content_text
	if content_label:
		content_label.text = content_text


func _on_confirm_button_pressed() -> void:
	var selected_language: String = get_selected_language()
	accepted.emit(selected_language)
	if close_on_action:
		hide()


func _on_cancel_button_pressed() -> void:
	refused.emit()
	if close_on_action:
		hide()
