extends MarginContainer

signal add_pressed()
signal save_pressed()
signal back_pressed()
signal new_search(new_text: String)





func _on_plus_button_pressed() -> void:
	add_pressed.emit()


func _on_save_button_pressed() -> void:
	save_pressed.emit()


func _on_back_button_pressed() -> void:
	back_pressed.emit()


func _on_line_edit_text_changed(new_text: String) -> void:
	new_search.emit(new_text)
