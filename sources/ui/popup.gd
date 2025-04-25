@tool
extends CanvasLayer
class_name ConfirmPopup

signal accepted
signal refused

@export_multiline var content_text: String = "": set = _set_content_text

@onready var content_label: Label = %ContentLabel
@onready var confirm_button: Button = %ConfirmButton
@onready var cancel_button: Button = %CancelButton

func _ready() -> void:
	_set_content_text(content_text)


func _set_content_text(p_content_text: String) -> void:
	content_text = p_content_text
	if content_label:
		content_label.text = content_text


func _on_confirm_button_pressed() -> void:
	accepted.emit()
	hide()


func _on_cancel_button_pressed() -> void:
	refused.emit()
	hide()
