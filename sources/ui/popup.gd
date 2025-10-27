@tool
class_name ConfirmPopup
extends CanvasLayer

signal accepted()
signal refused()

@export_multiline var content_text: String = "": set = _set_content_text
@export var confirm_text_override: String = ""
@export var cancel_text_override: String = ""

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


func _on_confirm_button_pressed() -> void:
	accepted.emit()
	hide()


func _on_cancel_button_pressed() -> void:
	refused.emit()
	hide()
