#Autoload for prof_tool
extends Node

var main_menu_selected_tab: int = 0

func _ready() -> void:
	var scene_path = get_tree().current_scene.get_scene_file_path()
	if scene_path != "res://sources/language_tool/prof_tool_menu.tscn":
		queue_free() # If we are not in the editor, this autoload is not needed since it is only useful for the prof_tool
