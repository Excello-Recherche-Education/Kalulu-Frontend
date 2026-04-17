class_name LessonButton
extends TextureButton

const LOCKED_COLOR: Color = Color("cccccc")
const LOCKED_LABEL_COLOR: Color = Color("999999")
const DEFAULT_UNLOCKED_FILL_COLOR: Color = Color("176d78")
const DEFAULT_UNLOCKED_LABEL_COLOR: Color = Color("9be3ea")
const UNLOCKED_BORDER_COLOR: Color = Color("fbb03b")
const DEFAULT_COMPLETED_FILL_COLOR: Color = Color("9be3ea")
const DEFAULT_COMPLETED_LABEL_COLOR: Color = Color("0a555b")

@export var text: String:
	set = _set_text
@export var completed: bool = false:
	set = _set_completed

var unlocked_fill_color: Color = DEFAULT_UNLOCKED_FILL_COLOR
var unlocked_label_color: Color = DEFAULT_UNLOCKED_LABEL_COLOR
var completed_fill_color: Color = DEFAULT_COMPLETED_FILL_COLOR
var completed_label_color: Color = DEFAULT_COMPLETED_LABEL_COLOR

@onready var center: TextureRect = %Center
@onready var border: TextureRect = %Border
@onready var label: Label = %Label
@onready var placeholder: TextureRect = %Placeholder
@onready var right_fx: RightFX = %RightFX


func _ready() -> void:
	_set_text(text)
	_update_visual_state()


func show_placeholder(is_shown: bool) -> void:
	placeholder.set_visible(is_shown)
	label.set_visible(!is_shown)


func right() -> void:
	right_fx.play()
	await right_fx.finished


func set_button_disabled(value: bool) -> void:
	disabled = value
	_update_visual_state()


func set_garden_colors(p_unlocked: Color, p_unlocked_text: Color, p_completed: Color, p_completed_text: Color) -> void:
	unlocked_fill_color = p_unlocked
	unlocked_label_color = p_unlocked_text
	completed_fill_color = p_completed
	completed_label_color = p_completed_text
	_update_visual_state()


func _update_visual_state() -> void:
	if not center or not border or not label:
		return
	if disabled:
		center.modulate = LOCKED_COLOR
		border.visible = false
		label.add_theme_color_override("font_color", LOCKED_LABEL_COLOR)
	elif completed:
		center.modulate = completed_fill_color
		border.visible = false
		label.add_theme_color_override("font_color", completed_label_color)
	else:
		center.modulate = unlocked_fill_color
		border.visible = true
		border.modulate = UNLOCKED_BORDER_COLOR
		label.add_theme_color_override("font_color", unlocked_label_color)


func _set_text(value: String) -> void:
	text = value
	if label:
		label.text = text


func _set_completed(value: bool) -> void:
	completed = value
	_update_visual_state()
