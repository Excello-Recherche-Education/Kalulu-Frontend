@tool
class_name ConfirmPopup
extends CanvasLayer

signal accepted()
signal refused()

## Label on the only button of an acknowledge-only dialog.
const ACKNOWLEDGE_TEXT: String = "OK"

## Short heading above the message. Hidden when empty, so a dialog that reads
## fine as a single sentence stays a single sentence.
@export var title_text: String = "": set = _set_title_text
@export_multiline var content_text: String = "": set = _set_content_text
@export var confirm_text_override: String = ""
@export var cancel_text_override: String = ""
@export var close_on_action: bool = true
## A message with nothing to decide: one button, which only dismisses.
##
## Offering Cancel next to Confirm on a dialog that just reports something makes
## the reader look for the difference between them. `accepted` still fires, so a
## notice can be reacted to.
@export var acknowledge_only: bool = false: set = _set_acknowledge_only

@onready var content_label: Label = %ContentLabel
@onready var confirm_button: Button = %ConfirmButton
@onready var cancel_button: Button = %CancelButton
# Optional: several screens build their dialog inline with this script attached
# rather than instancing popup.tscn, and those copies predate the heading and the
# close cross. Looked up leniently so this script keeps working on all of them.
@onready var title_label: Label = get_node_or_null("%TitleLabel") as Label
@onready var close_button: TextureButton = get_node_or_null("%CloseButton") as TextureButton


func _ready() -> void:
	if close_button:
		# The cross is drawn from a white icon so it can be tinted per surface;
		# on the dialog's white card it takes the brand navy.
		close_button.self_modulate = Design.NAVY
	_set_title_text(title_text)
	_set_content_text(content_text)
	if confirm_text_override != "":
		_set_confirm_text(confirm_text_override)
	if cancel_text_override != "":
		_set_cancel_text(cancel_text_override)
	# After the overrides, so an explicit label still wins over the default one.
	_set_acknowledge_only(acknowledge_only)


func _set_title_text(p_title_text: String) -> void:
	title_text = p_title_text
	if title_label:
		title_label.text = title_text
		title_label.visible = not title_text.is_empty()


func _set_content_text(p_content_text: String) -> void:
	content_text = p_content_text
	if content_label:
		content_label.text = content_text


func _set_acknowledge_only(p_acknowledge_only: bool) -> void:
	acknowledge_only = p_acknowledge_only
	if not cancel_button:
		return
	cancel_button.visible = not acknowledge_only
	if acknowledge_only and confirm_text_override.is_empty():
		_set_confirm_text(ACKNOWLEDGE_TEXT)


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
