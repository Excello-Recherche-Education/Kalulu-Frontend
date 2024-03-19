extends MarginContainer

signal add_pressed()
signal save_pressed()
signal back_pressed()
signal new_search(new_text: String)
signal import_path_selected(path: String)

@onready var title_label: Label = %TitleLabel
@onready var file_dialog: FileDialog = $FileDialog


func _on_plus_button_pressed() -> void:
	add_pressed.emit()


func _on_save_button_pressed() -> void:
	save_pressed.emit()


func _on_back_button_pressed() -> void:
	back_pressed.emit()


func _on_line_edit_text_changed(new_text: String) -> void:
	new_search.emit(new_text)


func set_title(text: String) -> void:
	title_label.text = text


func _on_button_pressed() -> void:
	file_dialog.filters = []
	file_dialog.add_filter("*.csv", "csv")
	
	for connection in file_dialog.file_selected.get_connections():
		connection["signal"].disconnect(connection["callable"])
	
	file_dialog.file_selected.connect(_on_filename_selected)
	
	file_dialog.show()


func _on_filename_selected(path: String) -> void:
	import_path_selected.emit(path)
