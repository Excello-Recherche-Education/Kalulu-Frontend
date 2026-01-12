class_name Word
extends Button

signal answer(stimulus: String, expected_stimulus: String)
signal no_answer()

const MINIGAMES_LABEL_SETTINGS_ANTS: LabelSettings = preload("res://resources/themes/minigames_label_settings_ants.tres")
const TEXT_BOX_BASE_COLOR: Color = Color("#fef7dd")
const TEXT_BOX_RIGHT_COLOR: Color = Color("#009444")
const TEXT_BOX_WRONG_COLOR: Color = Color("#be1e2d")
const FONT_ANSWER_COLOR: Color = Color("#fef7dd")

var stimulus: String:
	set = _set_stimulus
var follow_mouse: bool = false
var current_anchor: CanvasItem

@onready var area: Area2D = $Area2D
@onready var label: Label = %Label
@onready var right_fx: RightFX = $RightFX
@onready var right_stars: RightStarsFX = $Right_Stars
@onready var wrong_fx: WrongFX = $WrongFX
@onready var text_box: TextureRect = $TextBox


func right() -> void:
	label.label_settings = label.label_settings.duplicate()
	label.label_settings.font_color = FONT_ANSWER_COLOR
	text_box.self_modulate = TEXT_BOX_RIGHT_COLOR
	right_fx.play()
	right_stars.play()
	await right_fx.finished
	text_box.self_modulate = TEXT_BOX_BASE_COLOR
	label.label_settings = MINIGAMES_LABEL_SETTINGS_ANTS


func wrong() -> void:
	label.label_settings = label.label_settings.duplicate()
	label.label_settings.font_color = FONT_ANSWER_COLOR
	text_box.self_modulate = TEXT_BOX_WRONG_COLOR
	wrong_fx.play()
	await wrong_fx.finished
	text_box.self_modulate = TEXT_BOX_BASE_COLOR
	label.label_settings = MINIGAMES_LABEL_SETTINGS_ANTS


func _process(_delta: float) -> void:
	if follow_mouse:
		global_position = get_global_mouse_position() - size / 2.0
	else:
		if current_anchor == null or not is_instance_valid(current_anchor):
			return
		if current_anchor is Ant:
			global_position = (current_anchor as Ant).anchor.global_position
		else:
			@warning_ignore("UNSAFE_PROPERTY_ACCESS")
			global_position = current_anchor.global_position


func _set_stimulus(value: String) -> void:
	stimulus = value
	label.text = stimulus


func _on_button_down() -> void:
	follow_mouse = true


func _on_button_up() -> void:
	follow_mouse = false
	
	var destination: CanvasItem = current_anchor
	@warning_ignore("UNSAFE_PROPERTY_ACCESS")
	var min_distance: float = ((current_anchor.global_position - global_position) as Vector2).length()
	for other_area: Area2D in area.get_overlapping_areas():
		var other: CanvasItem = other_area
		if not other_area is Ant:
			other = other_area.owner
		@warning_ignore("UNSAFE_PROPERTY_ACCESS")
		var dist: float = ((other.global_position - global_position ) as Vector2).length()
		if dist < min_distance:
			destination = other
			min_distance = dist
	
	@warning_ignore("UNSAFE_METHOD_ACCESS")
	current_anchor.set_monitorable(true)
	current_anchor = destination
	if destination is Ant:
		@warning_ignore("UNSAFE_METHOD_ACCESS")
		destination.set_monitorable(false)
		no_answer.emit()
	else:
		@warning_ignore("UNSAFE_METHOD_ACCESS")
		destination.set_monitorable(false)
		@warning_ignore("UNSAFE_PROPERTY_ACCESS")
		answer.emit(stimulus, destination.stimulus)
