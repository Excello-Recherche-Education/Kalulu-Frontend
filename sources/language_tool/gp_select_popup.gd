extends Control

signal GP_selected(grapheme_ind: int, text: String)
signal focus_changed(has_focus: bool)

@onready var container: = $VBoxContainer


var grapheme_ind: = -1
var ind_selected: = -1:
	set = set_ind_selected


func _ready() -> void:
	top_level = true


func set_ind_selected(p_ind_selected: int) -> void:
	ind_selected = p_ind_selected
	for child in container.get_children():
		child.set_pressed_no_signal(ind_selected == child.get_index())


func clear(new_grapheme_ind: int) -> void:
	var children: = container.get_children()
	if not children.is_empty():
		if ind_selected == -1:
			ind_selected = 0
			GP_selected.emit(grapheme_ind, children[0].text)
	for child in children:
		child.queue_free()
	ind_selected = -1
	grapheme_ind = new_grapheme_ind


func add_item(text: String, selected: bool) -> void:
	var button: = CheckBox.new()
	button.text = text
	button.set("theme_override_font_sizes/font_size", 100)
	container.add_child(button)
	if selected:
		ind_selected = button.get_index()
	button.toggled.connect(_on_button_toggled.bind(button))
	button.focus_entered.connect(_on_button_focus_entered)
	button.focus_exited.connect(_on_button_focus_exited)


func _on_button_toggled(pressed: bool, button: CheckBox) -> void:
	var ind: = button.get_index()
	if ind_selected != ind:
		ind_selected = ind
	if not pressed:
		button.set_pressed_no_signal(not pressed)
	GP_selected.emit(grapheme_ind, button.text)


func _on_button_focus_entered() -> void:
	focus_changed.emit(true)


func _on_button_focus_exited() -> void:
	focus_changed.emit(false)
