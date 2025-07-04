extends TextureButton

class_name Word

signal answer(stimulus: String, expected_stimulus: String)
signal no_answer()

@onready var area: Area2D = $Area2D
@onready var label: Label = %Label
@onready var right_fx: RightFX = $RightFX
@onready var wrong_fx: WrongFX = $WrongFX

var stimulus: String:
	set = _set_stimulus
var follow_mouse: bool = false
var current_anchor: CanvasItem


func right() -> void:
	right_fx.play()
	await right_fx.finished


func wrong() -> void:
	wrong_fx.play()
	await wrong_fx.finished


func _process(_delta: float) -> void:
	if follow_mouse:
		global_position = get_global_mouse_position() - size / 2.0
	else:
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
