class_name LessonButton
extends TextureButton

const LOCKED_COLOR: Color = Color("cccccc")
const LOCKED_LABEL_COLOR: Color = Color("999999")
const UNLOCKED_FILL_COLOR: Color = Color("176d78")
const UNLOCKED_LABEL_COLOR: Color = Color("9be3ea")
const UNLOCKED_BORDER_COLOR: Color = Color("fbb03b")
const COMPLETED_FILL_COLOR: Color = Color("9be3ea")
const COMPLETED_LABEL_COLOR: Color = Color("0a555b")

@export_color_no_alpha var base_color: Color:
	set = _set_base_color
@export_color_no_alpha var completed_color: Color:
	set = _set_completed_color
@export var text: String:
	set = _set_text
@export var completed: bool = false:
	set = _set_completed

@onready var center: TextureRect = %Center
@onready var border: TextureRect = %Border
@onready var label: Label = %Label
@onready var placeholder: TextureRect = %Placeholder
@onready var right_fx: RightFX = %RightFX


func _ready() -> void:
	_set_base_color(base_color)
	_set_completed_color(completed_color)
	_set_text(text)
	_update_visual_state()


func show_placeholder(is_shown: bool) -> void:
	placeholder.set_visible(is_shown)
	label.set_visible(!is_shown)


func right() -> void:
	right_fx.play()
	await right_fx.finished


func _update_visual_state() -> void:
	if not center or not border or not label:
		return
	if disabled:
		# Locked state
		center.modulate = LOCKED_COLOR
		border.visible = false
		label.add_theme_color_override("font_color", LOCKED_LABEL_COLOR)
	elif completed:
		# Completed state
		center.modulate = COMPLETED_FILL_COLOR
		border.visible = false
		label.add_theme_color_override("font_color", COMPLETED_LABEL_COLOR)
	else:
		# Unlocked state
		center.modulate = UNLOCKED_FILL_COLOR
		border.visible = true
		border.modulate = UNLOCKED_BORDER_COLOR
		label.add_theme_color_override("font_color", UNLOCKED_LABEL_COLOR)


func _set_base_color(color: Color) -> void:
	base_color = color


func _set_completed_color(color: Color) -> void:
	completed_color = color


func _set_text(value: String) -> void:
	text = value
	if label:
		label.text = text


func _set_completed(value: bool) -> void:
	completed = value
	_update_visual_state()


func set_button_disabled(value: bool) -> void:
	disabled = value
	_update_visual_state()
