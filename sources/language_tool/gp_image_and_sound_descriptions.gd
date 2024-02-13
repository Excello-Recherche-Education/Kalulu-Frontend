extends Control

@onready var description_container: = %DescriptionsContainer

const description_line_class: = preload("res://sources/language_tool/image_and_sound_gp_description.tscn")


func _ready() -> void:
	var _description_line: = description_line_class.instantiate()
	DirAccess.make_dir_recursive_absolute(Database.base_path + Database.language + Database.look_and_learn_images)
	DirAccess.make_dir_recursive_absolute(Database.base_path + Database.language + Database.look_and_learn_sounds)
	_description_line.queue_free()
	
	Database.db.query("Select * FROM GPs")
	for res in Database.db.query_result:
		var description_line: = description_line_class.instantiate()
		description_container.add_child(description_line)
		description_line.set_gp(res)
	
	Database.db.query("SELECT * FROM Syllables")
	for res in Database.db.query_result:
		var description_line: = description_line_class.instantiate()
		description_container.add_child(description_line)
		res.Grapheme = res.Syllable
		res.Phoneme = ""
		description_line.set_gp(res)
		description_line.image_preview.hide()
		description_line.image_upload_button.hide()


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/prof_tool_menu.tscn")
