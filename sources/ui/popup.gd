@tool
class_name ConfirmPopup
extends CanvasLayer

signal accepted()
signal refused()

## Label on the only button of an acknowledge-only dialog.
const ACKNOWLEDGE_TEXT: String = "OK"
## Labels on the offer to copy, before and just after it is taken.
const COPY_TEXT: String = "COPY_ERROR_MESSAGE"
const COPIED_TEXT: String = "ERROR_MESSAGE_COPIED"
## How long "copied" stays up before the offer comes back.
const COPIED_FEEDBACK_SECONDS: float = 2.5

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
## What pressing "copy" puts on the clipboard. Empty means no offer at all.
##
## A notice a reader has to forward -- one naming hostnames for whoever runs the
## network -- is otherwise retyped off a screen. Set by the screen rather than built
## here, so this stays a dialog and does not have to know what a support report is.
@export_multiline var copy_text: String = "": set = _set_copy_text
## Widens the message, for one that must not be broken up. 0 keeps the scene's width.
##
## The card is sized for a sentence or two. A notice carrying hostnames is a different
## shape: it has lines that mean nothing once split, and the default width breaks the
## longest of them mid-name. Opt in, rather than widening every dialog in the app --
## most of them read better narrow.
@export var content_min_width: float = 0.0: set = _set_content_min_width

## The button labels the scene set, to fall back to when an override is cleared.
## Captured at _ready, before any override is applied.
var default_confirm_text: String = ""
var default_cancel_text: String = ""
## The width the scene gave the message, to come back to when a wider one is cleared.
var default_content_min_width: float = 0.0

@onready var content_label: Label = %ContentLabel
@onready var confirm_button: Button = %ConfirmButton
@onready var cancel_button: Button = %CancelButton
# Optional: several screens build their dialog inline with this script attached
# rather than instancing popup.tscn, and those copies predate the heading and the
# close cross. Looked up leniently so this script keeps working on all of them.
@onready var title_label: Label = get_node_or_null("%TitleLabel") as Label
@onready var close_button: TextureButton = get_node_or_null("%CloseButton") as TextureButton
@onready var copy_button: Button = get_node_or_null("%CopyButton") as Button


func _ready() -> void:
	if close_button:
		# The cross is drawn from a white icon so it can be tinted per surface;
		# on the dialog's white card it takes the brand navy.
		close_button.self_modulate = Design.NAVY
	default_confirm_text = confirm_button.text
	default_cancel_text = cancel_button.text
	if content_label:
		default_content_min_width = content_label.custom_minimum_size.x
	_set_title_text(title_text)
	_set_content_text(content_text)
	_set_copy_text(copy_text)
	_set_content_min_width(content_min_width)
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


func _set_copy_text(p_copy_text: String) -> void:
	copy_text = p_copy_text
	if not copy_button:
		return
	# Never offered where it would not work: a button that does nothing and then says
	# it copied is worse than no button.
	copy_button.visible = not copy_text.is_empty() \
			and DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD)
	copy_button.text = COPY_TEXT


func _set_content_min_width(p_content_min_width: float) -> void:
	content_min_width = p_content_min_width
	if content_label:
		content_label.custom_minimum_size.x = content_min_width if content_min_width > 0.0 \
				else default_content_min_width


func _on_copy_button_pressed() -> void:
	DisplayServer.clipboard_set(copy_text)
	Log.info("ConfirmPopup: Copied the notice to the clipboard")
	copy_button.text = COPIED_TEXT
	await get_tree().create_timer(COPIED_FEEDBACK_SECONDS).timeout
	# The dialog may have been dismissed, or gone, while the confirmation was up.
	if is_instance_valid(copy_button):
		copy_button.text = COPY_TEXT


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
