extends Control

@onready var description_container: VBoxContainer = %DescriptionsContainer

const description_line_scene: PackedScene  = preload("res://sources/language_tool/image_and_sound_gp_description.tscn")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(Database.base_path + Database.language + Database.look_and_learn_images)
	DirAccess.make_dir_recursive_absolute(Database.base_path + Database.language + Database.look_and_learn_sounds)
	
	Database.db.query("SELECT * FROM GPs WHERE GPs.Exception=0")
	for res in Database.db.query_result:
		var description_line: GPImageAndSoundDescription = description_line_scene.instantiate()
		description_container.add_child(description_line)
		description_line.set_gp(res)


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/prof_tool_menu.tscn")


func _on_line_edit_text_changed(new_text: String) -> void:
	for description_line in description_container.get_children():
		description_line.visible = description_line.gp_menu_button.text.begins_with(new_text)
