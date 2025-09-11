extends MarginContainer
class_name ListTitle

signal add_pressed()
signal save_pressed()
signal back_pressed()
signal new_search(new_text: String)
signal import_path_selected(path: String, match_to_file: bool)

@onready var title_label: Label = %TitleLabel
@onready var file_dialog: FileDialog = $FileDialog

var my_button: Button

func _ready() -> void:
	my_button = file_dialog.add_button("Match list to file (delete elements not in file)", true, "act")
	file_dialog.ok_button_text = "Add new elements"


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
	
	file_dialog.ok_button_text = "Add new elements"
	
	Utils.disconnect_all(file_dialog.file_selected)
	Utils.disconnect_all(file_dialog.custom_action)
	
	file_dialog.file_selected.connect(_on_filename_selected)
	file_dialog.custom_action.connect(_on_match_to_file_selected)
	
	file_dialog.show()


func _on_filename_selected(path: String) -> void:
	import_path_selected.emit(path, false)


func _on_match_to_file_selected(_custom_action: String) -> void:
	import_path_selected.emit(file_dialog.current_path, true)
	file_dialog.hide()


func _process(_delta: float) -> void:
	if my_button:
		my_button.disabled = file_dialog.get_ok_button().disabled
