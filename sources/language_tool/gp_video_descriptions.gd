extends Control

@onready var description_container: VBoxContainer = %DescriptionsContainer

const DESCRIPTION_LINE_SCENE: PackedScene = preload("res://sources/language_tool/video_gp_description.tscn")


func _ready() -> void:
	var _description_line: VideoGPDescription = DESCRIPTION_LINE_SCENE.instantiate()
	DirAccess.make_dir_recursive_absolute(Database.base_path + Database.language + Database.look_and_learn_videos)
	_description_line.queue_free()
	
	Database.db.query("Select * FROM GPs WHERE GPs.Exception=0")
	for gp in Database.db.query_result:
		var description_line: VideoGPDescription = DESCRIPTION_LINE_SCENE.instantiate()
		description_container.add_child(description_line)
		description_line.set_gp(gp)


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/prof_tool_menu.tscn")
