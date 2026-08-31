@tool
class_name SegmentedToggle
extends PanelContainer
## Pill switch that picks one of several options, as used for Login | Sign Up.
##
## Segments share the width equally rather than hugging their labels. The
## mockups size the highlight to the label, but the options are translated and a
## content-hugging highlight would change width every time the selection moves,
## which reads as a glitch. Equal segments stay still.
##
## `options` holds translation keys, not display text.

signal selection_changed(index: int)

const ANIMATION_DURATION: float = 0.15

@export var options: PackedStringArray = ["LOG_IN", "SIGN_UP"]:
	set(value):
		options = value
		_rebuild()
@export var selected: int = 0:
	set(value):
		var new_value: int = clampi(value, 0, maxi(0, options.size() - 1))
		if new_value == selected:
			return
		# Assigning the property inside its own setter is a plain store, so this
		# does not recurse.
		selected = new_value
		# A silent change is a state restore rather than a user action, so it
		# snaps into place instead of sliding.
		_apply_selection(notify_selection)
		if notify_selection:
			selection_changed.emit(selected)
## Locks the switch: the segments stop answering, without changing which is chosen.
##
## For a screen that has started something the switch must not interrupt. The colours
## stay as they are: the lock lasts as long as a request does, and greying both labels
## for that long reads as a glitch rather than as an answer.
@export var disabled: bool = false:
	set = _set_disabled

var buttons: Array[Button] = []
var highlight_tween: Tween
var notify_selection: bool = true

@onready var content: Control = %Content
@onready var highlight: Panel = %Highlight
@onready var segments: HBoxContainer = %Segments


func _ready() -> void:
	add_theme_stylebox_override("panel", _pill_stylebox())
	# Content is a plain Control so the highlight can be positioned freely
	# inside it; being a Control it ignores its children when reporting a
	# minimum size, so the pill's height has to be set from the tokens here.
	content.custom_minimum_size.y = Design.TOGGLE_HEIGHT - 2 * Design.TOGGLE_INSET
	# The capsule's appearance must not wait for a layout pass. Before the first
	# one the segment row has no width, so _move_highlight bails out and the
	# highlight would sit there showing the engine's default square grey panel
	# until something moved it.
	highlight.add_theme_stylebox_override("panel", highlight_stylebox())
	resized.connect(_on_resized)
	# The row is laid out after this node is, so its own resize is the first
	# moment the highlight can be placed correctly.
	segments.resized.connect(_on_resized)
	_rebuild()


## Selects an option without emitting selection_changed, for restoring state.
func _set_disabled(p_disabled: bool) -> void:
	disabled = p_disabled
	for button: Button in buttons:
		button.disabled = disabled


func set_selected_silently(index: int) -> void:
	notify_selection = false
	selected = index
	notify_selection = true


## The purple capsule behind the selected segment.
##
## Sized from the tokens rather than the measured row, so it is correct before
## any layout has happened.
func highlight_stylebox(height: int = 0) -> StyleBoxFlat:
	var capsule: int = height
	if capsule <= 0:
		capsule = Design.TOGGLE_HEIGHT - 2 * Design.TOGGLE_INSET
	return MenuTheme.flat_stylebox(Design.PURPLE, floori(float(capsule) / 2))


func _pill_stylebox() -> StyleBoxFlat:
	var box: StyleBoxFlat = MenuTheme.flat_stylebox(Color.WHITE, floori(float(Design.TOGGLE_HEIGHT) / 2))
	box.content_margin_left = Design.TOGGLE_INSET
	box.content_margin_right = Design.TOGGLE_INSET
	box.content_margin_top = Design.TOGGLE_INSET
	box.content_margin_bottom = Design.TOGGLE_INSET
	return box


func _rebuild() -> void:
	if not is_node_ready():
		return

	for button: Button in buttons:
		button.queue_free()
	buttons.clear()

	var group: ButtonGroup = ButtonGroup.new()
	for index: int in options.size():
		var button: Button = Button.new()
		button.text = options[index]
		button.toggle_mode = true
		button.button_group = group
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		# The highlight panel draws the capsule, so the buttons stay invisible
		# and only provide the label and the hit area.
		for state: String in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.add_theme_font_size_override("font_size", Design.FONT_SIZE_INPUT)
		button.add_theme_color_override("font_color", Design.PURPLE)
		button.add_theme_color_override("font_hover_color", Design.PURPLE)
		button.add_theme_color_override("font_pressed_color", Color.WHITE)
		button.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
		button.add_theme_color_override("font_disabled_color",
			Color.WHITE if index == selected else Design.PURPLE)
		# The lock survives a rebuild, which is what happens when the options change.
		button.disabled = disabled
		button.pressed.connect(_on_segment_pressed.bind(index))
		segments.add_child(button)
		buttons.append(button)

	# Shrinking the option list can invalidate the selection, but that is not a
	# user action either, so it must not emit.
	set_selected_silently(selected)
	_apply_selection(false)


func _apply_selection(animate: bool) -> void:
	if buttons.is_empty():
		return
	for index: int in buttons.size():
		buttons[index].set_pressed_no_signal(index == selected)
	_move_highlight(animate)


func _move_highlight(animate: bool) -> void:
	if buttons.is_empty() or segments.size.x <= 0.0:
		return

	var segment_size: Vector2 = Vector2(segments.size.x / buttons.size(), segments.size.y)
	var target: Vector2 = segments.position + Vector2(segment_size.x * selected, 0.0)

	highlight.size = segment_size
	highlight.add_theme_stylebox_override("panel", highlight_stylebox(int(segment_size.y)))

	if highlight_tween and highlight_tween.is_valid():
		highlight_tween.kill()
	if not animate:
		highlight.position = target
		return
	highlight_tween = create_tween()
	highlight_tween.tween_property(highlight, "position", target, ANIMATION_DURATION)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _on_segment_pressed(index: int) -> void:
	selected = index


func _on_resized() -> void:
	_move_highlight(false)
