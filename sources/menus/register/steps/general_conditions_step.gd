@tool
extends Step
## The terms, on a card, with a box to tick before the wizard will move on.

## Shown inside the box once it is ticked. Loaded rather than preloaded, so the
## icon is not pulled in with the script on every step that inherits base_step.
const TICK_ICON_PATH: String = "res://assets/menus/icons/done.svg"

@onready var card: PanelContainer = $PanelContainer
@onready var conditions_label: RichTextLabel = %ConditionsLabel
@onready var accept: Button = %Accept
@onready var accept_label: Label = %AcceptLabel
@onready var accept_error: Label = %AcceptError


func _ready() -> void:
	# base_step blanks the question board's panel so the question reads straight
	# off the background. This step wants a real card there instead, and a local
	# override beats the type variation, so the override has to go.
	card.remove_theme_stylebox_override("panel")
	# From the token rather than the scene: a colour written into a .tscn is
	# rounded to six decimals, so it stops being the token it was copied from.
	conditions_label.add_theme_color_override("default_color", Design.GREY_DARK)
	_refresh_accept()


func _on_back() -> bool:
	accept.button_pressed = false
	# Assigning button_pressed does not emit pressed, so the box has to be
	# redrawn by hand.
	_refresh_accept()
	return true


func _on_next() -> bool:
	if not accept.button_pressed:
		accept_error.show()
		return false
	return true


func _on_validate_button_pressed() -> void:
	if _on_next():
		next.emit(self)


func _on_accept_pressed() -> void:
	accept_error.hide()
	_refresh_accept()


## Fills the box in and turns the wording purple once the terms are accepted.
##
## The box is a toggling Button rather than a CheckBox: a CheckBox draws its
## state as a themed icon beside its own text, and the mockups want a filled
## square with the wording as a separate, restyled label.
func _refresh_accept() -> void:
	accept.icon = load(TICK_ICON_PATH) as Texture2D if accept.button_pressed else null
	accept_label.add_theme_color_override("font_color",
		Design.PURPLE if accept.button_pressed else Design.GREY_DARK)
