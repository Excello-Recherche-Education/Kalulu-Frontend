@tool
extends CanvasLayer
class_name LoadingPopup

signal cancel
signal ok

@export_multiline var content_text: String = "": set = _set_content_text

@onready var content_label: Label = %ContentLabel
@onready var progress_bar: ProgressBar = %ProgressBar

@onready var cancel_button: Button = %CancelButton
@onready var ok_button: Button = %OKButton

@export var cancel_text_override: String = ""


func set_text(text: String) -> void:
	content_label.text = text


func set_progress(percent: float) -> void:
	progress_bar.value = percent
	if percent >= 100.0:
		cancel_button.hide()
		ok_button.show()


func set_finished(finished: bool) -> void:
	if finished:
		cancel_button.hide()
		ok_button.show()
	else:
		ok_button.hide()
		cancel_button.show()


func _ready() -> void:
	_set_content_text(content_text)
	if cancel_text_override != "":
		_set_cancel_text(cancel_text_override)


func _set_content_text(p_content_text: String) -> void:
	content_text = p_content_text
	if content_label:
		content_label.text = content_text


func _set_cancel_text(p_content_text: String) -> void:
	cancel_button.text = p_content_text


func _on_cancel_button_pressed() -> void:
	cancel.emit()
	hide()


func _on_ok_button_pressed() -> void:
	ok.emit()
	hide()
