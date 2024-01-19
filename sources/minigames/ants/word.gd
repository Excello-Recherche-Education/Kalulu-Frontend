extends TextureButton

signal answer(good: bool)
signal no_answer()

@onready var area: = $Area2D
@onready var label: = %Label

var stimulus: String:
	set = _set_stimulus
var follow_mouse: = false
var current_anchor: CanvasItem


func _process(_delta: float) -> void:
	if follow_mouse:
		global_position = get_global_mouse_position() - size / 2.0
	else:
		if current_anchor is Area2D:
			global_position = current_anchor.anchor.global_position
		else:
			global_position = current_anchor.global_position


func _set_stimulus(value: String) -> void:
	stimulus = value
	
	label.text = stimulus


func _on_button_down() -> void:
	follow_mouse = true


func _on_button_up() -> void:
	follow_mouse = false
	
	var destination: = current_anchor
	var min_distance: float = (current_anchor.global_position - global_position).length()
	for other_area in area.get_overlapping_areas():
		var other: CanvasItem = other_area
		if other_area.owner:
			other = other_area.owner
		var dist: float = (other.global_position - global_position).length()
		if dist < min_distance:
			destination = other
			min_distance = dist
	
	current_anchor = destination
	if destination is Area2D:
		no_answer.emit()
	else:
		answer.emit(stimulus == destination.stimulus)
