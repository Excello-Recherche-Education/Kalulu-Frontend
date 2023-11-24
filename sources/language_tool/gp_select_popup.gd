extends MarginContainer

signal GP_selected(grapheme_ind: int, gp_id: int, text: String)
signal focus_changed(has_focus: bool)
signal new_GP_asked()

@onready var container: = $VBoxContainer
@onready var button: = $Button


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
			GP_selected.emit(grapheme_ind, children[0].get_meta("gp_id"), children[0].text)
	for child in children:
		child.queue_free()
	ind_selected = -1
	grapheme_ind = new_grapheme_ind


func add_item(gp_id: int, text: String, selected: bool) -> void:
	var add_button: = CheckBox.new()
	add_button.text = text
	add_button.set("theme_override_font_sizes/font_size", 100)
	container.add_child(add_button)
	if selected:
		ind_selected = add_button.get_index()
	add_button.toggled.connect(_on_button_toggled.bind(add_button))
	add_button.focus_entered.connect(_on_button_focus_entered)
	add_button.focus_exited.connect(_on_button_focus_exited)
	add_button.set_meta("gp_id", gp_id)


func _on_button_toggled(pressed: bool, add_button: CheckBox) -> void:
	var ind: = add_button.get_index()
	if ind_selected != ind:
		ind_selected = ind
	if not pressed:
		add_button.set_pressed_no_signal(not pressed)
	GP_selected.emit(grapheme_ind, add_button.get_meta("gp_id"), add_button.text)


func _on_button_focus_entered() -> void:
	focus_changed.emit(true)


func _on_button_focus_exited() -> void:
	focus_changed.emit(false)


func no_gp_mode() -> void:
	button.show()
	container.hide()
	size.y = 0


func gp_mode() -> void:
	button.hide()
	container.show()
	size.y = 0


func _on_button_pressed() -> void:
	new_GP_asked.emit()
