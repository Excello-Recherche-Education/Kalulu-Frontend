@tool
class_name ConfirmPopup
extends CanvasLayer

signal accepted()
signal refused()

@export_multiline var content_text: String = "": set = _set_content_text
@export var confirm_text_override: String = ""
@export var cancel_text_override: String = ""
@export var close_on_action: bool = true

@onready var content_label: Label = %ContentLabel
@onready var confirm_button: Button = %ConfirmButton
@onready var cancel_button: Button = %CancelButton


func _ready() -> void:
	_set_content_text(content_text)
	if confirm_text_override != "":
		_set_confirm_text(confirm_text_override)
	if cancel_text_override != "":
		_set_cancel_text(cancel_text_override)


func _set_content_text(p_content_text: String) -> void:
	content_text = p_content_text
	if content_label:
		content_label.text = content_text


func _set_confirm_text(p_content_text: String) -> void:
	confirm_button.text = p_content_text


func _set_cancel_text(p_content_text: String) -> void:
	cancel_button.text = p_content_text


func set_buttons_visible(is_button_visible: bool) -> void:
	confirm_button.visible = is_button_visible
	cancel_button.visible = is_button_visible


func set_buttons_enabled(is_enabled: bool) -> void:
	confirm_button.disabled = not is_enabled
	cancel_button.disabled = not is_enabled


func _on_confirm_button_pressed() -> void:
	accepted.emit()
	if close_on_action:
		hide()


func _on_cancel_button_pressed() -> void:
	refused.emit()
	if close_on_action:
		hide()
