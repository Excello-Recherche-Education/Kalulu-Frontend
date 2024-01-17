extends Control

@onready var description_container: = %DescriptionsContainer

const description_line_class: = preload("res://sources/language_tool/image_and_sound_gp_description.tscn")


func _ready() -> void:
	var _description_line: = description_line_class.instantiate()
	DirAccess.make_dir_recursive_absolute(_description_line.resource_folder + _description_line.language_folder + _description_line.image_folder)
	DirAccess.make_dir_recursive_absolute(_description_line.resource_folder + _description_line.language_folder + _description_line.sound_folder)
	_description_line.queue_free()
	
	Database.db.query("Select * FROM GPs")
	for res in Database.db.query_result:
		var description_line: = description_line_class.instantiate()
		description_container.add_child(description_line)
		description_line.set_gp(res["Grapheme"] + "-" + res["Phoneme"])


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/prof_tool_menu.tscn")
