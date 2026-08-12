@tool
class_name DeviceButton
extends Button
## A numbered device card, drawn as a small tablet.
##
## Used both by the device selection screen and by the lesson-unlock panel in
## settings. The redesign makes the card white with a navy number; the panel
## still tints its own cards per device, so `background_color` stays and the
## number's colour follows the background's brightness rather than being fixed.

const DOT_SIZE: int = 20
const BAR_SIZE: Vector2i = Vector2i(60, 14)
const INSET: int = 20
const RADIUS: int = 16

@export_range(1, 99) var number: int:
	set(value):
		if value > 99:
			Log.warn("DeviceButton: Number %d should not be higher than 99" % value)
		elif value < 1:
			Log.warn("DeviceButton: Number %d should not be lower than 1" % value)
		number = value
		if label:
			label.text = str(value)
@export var background_color: Color = Color.WHITE:
	set(value):
		background_color = value
		if is_node_ready():
			_apply_colors()

@onready var label: Label = %Number
@onready var dot: Panel = %Dot
@onready var bar: Panel = %Bar


func _ready() -> void:
	custom_minimum_size = Vector2(Design.DEVICE_CARD_SIZE)
	label.text = str(number)
	_apply_colors()


func _apply_colors() -> void:
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var fill: Color = background_color
		if state == "hover":
			fill = background_color.darkened(0.05)
		elif state == "pressed":
			fill = background_color.darkened(0.12)
		elif state == "disabled":
			fill = background_color.lerp(Design.GREY_LIGHT, 0.6)
		add_theme_stylebox_override(state, MenuTheme.flat_stylebox(fill, RADIUS))

	# A white card wants a navy number, a saturated one wants white.
	var ink: Color = Design.NAVY if background_color.get_luminance() > 0.5 else Color.WHITE
	label.add_theme_color_override("font_color", ink)
	dot.add_theme_stylebox_override("panel", MenuTheme.flat_stylebox(ink, floori(float(DOT_SIZE) / 2)))
	bar.add_theme_stylebox_override("panel", MenuTheme.flat_stylebox(ink, floori(float(BAR_SIZE.y) / 2)))
