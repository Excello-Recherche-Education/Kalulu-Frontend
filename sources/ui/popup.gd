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
## Label for the confirm button, when "Validate" is not what it does.
##
## A setter like the ones above, so a screen that reuses one dialog for more than
## one message can relabel the button between shows -- setting it did nothing
## before, because it was only read once at _ready.
@export var confirm_text_override: String = "": set = _set_confirm_text_override
@export var cancel_text_override: String = "": set = _set_cancel_text_override
@export var close_on_action: bool = true
## A message with nothing to decide: one button, which only dismisses.
##
## Offering Cancel next to Confirm on a dialog that just reports something makes
## the reader look for the difference between them. `accepted` still fires, so a
## notice can be reacted to.
@export var acknowledge_only: bool = false: set = _set_acknowledge_only

## The button labels the scene set, to fall back to when an override is cleared.
## Captured at _ready, before any override is applied.
var default_confirm_text: String = ""
var default_cancel_text: String = ""

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
	default_confirm_text = confirm_button.text
	default_cancel_text = cancel_button.text
	_set_title_text(title_text)
	_set_content_text(content_text)
	# Through the setter, not _refresh_button_texts: a scene that asked for an
	# acknowledge-only dialog also needs Cancel hidden, and only this hides it.
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


func _set_confirm_text_override(p_confirm_text_override: String) -> void:
	confirm_text_override = p_confirm_text_override
	_refresh_button_texts()


func _set_cancel_text_override(p_cancel_text_override: String) -> void:
	cancel_text_override = p_cancel_text_override
	_refresh_button_texts()


func _set_acknowledge_only(p_acknowledge_only: bool) -> void:
	acknowledge_only = p_acknowledge_only
	if cancel_button:
		cancel_button.visible = not acknowledge_only
	_refresh_button_texts()


## Puts the right label on each button.
##
## One place for all of it, because the three cases have to undo each other: a
## screen that reuses one dialog for several messages sets an override for one and
## clears it for the next, and clearing it has to bring back the label the scene
## started with rather than leaving the previous message's.
func _refresh_button_texts() -> void:
	if not confirm_button or not cancel_button:
		return
	if confirm_text_override != "":
		_set_confirm_text(confirm_text_override)
	elif acknowledge_only:
		_set_confirm_text(ACKNOWLEDGE_TEXT)
	else:
		_set_confirm_text(default_confirm_text)
	_set_cancel_text(cancel_text_override if cancel_text_override != ""
		else default_cancel_text)


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
