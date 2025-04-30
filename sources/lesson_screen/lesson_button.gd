extends TextureButton

@export_color_no_alpha var base_color: Color:
	set = _set_base_color
@export_color_no_alpha var completed_color: Color:
	set = _set_completed_color
@export var text: String:
	set = _set_text
@export var completed: bool = false:
	set = _set_completed

@onready var center: TextureRect = %Center
@onready var label: Label = %Label
@onready var placeholder: TextureRect = %Placeholder
@onready var right_fx: RightFX = %RightFX

func _ready() -> void:
	_set_base_color(base_color)
	_set_completed_color(completed_color)
	_set_text(text)


func show_placeholder(is_shown: bool) -> void:
	placeholder.visible = is_shown
	label.visible = !is_shown


func right() ->  void:
	right_fx.play()
	await right_fx.finished

func _set_base_color(color: Color) -> void:
	base_color = color
	if center and not completed:
		center.modulate = color


func _set_completed_color(color: Color) -> void:
	completed_color = color
	if center and completed:
		center.modulate = color


func _set_text(value: String) -> void:
	text = value
	if label:
		label.text = text


func _set_completed(value: bool) -> void:
	completed = value
	if completed:
		center.modulate = completed_color
	else:
		center.modulate = base_color
