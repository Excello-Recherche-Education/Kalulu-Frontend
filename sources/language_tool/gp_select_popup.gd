extends Control

@onready var container: = $VBoxContainer

func _ready() -> void:
	top_level = true


var ind_selected: = -1:
	set = set_ind_selected


func set_ind_selected(p_ind_selected: int) -> void:
	ind_selected = p_ind_selected
	for child in container.get_children():
		child.set_pressed_no_signal(ind_selected == child.get_index())


func clear() -> void:
	for child in container.get_children():
		child.queue_free()
	ind_selected = -1


func add_item(text: String, selected: bool) -> void:
	var button: = CheckBox.new()
	button.text = text
	button.set("theme_override_font_sizes/font_size", 100)
	container.add_child(button)
	if selected:
		ind_selected = button.get_index()
