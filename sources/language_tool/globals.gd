#Autoload for prof_tool
extends Node

var main_menu_selected_tab: int = 0

var device_colors: Array[Color] = [
	Color("9670e0"),
	Color("ffe823"),
	Color("ed9ab5"),
	Color("a84349"),
	Color("3f32a5"),
	Color("9ef9ab"),
	Color("c3c2c4"),
	Color("ffaf57"),
	Color("4efee4"),
	Color("7ad1ff"),
	Color("c3c2c4"),
	Color("ffe823"),
	Color("a84349"),
	Color("ed9ab5"),
	Color("9ef9ab"),
	Color("3f32a5"),
	Color("4efee4"),
	Color("7ad1ff"),
	Color("ffaf57"),
	Color("9670e0"),
]

func _ready() -> void:
	var scene_path: String = get_tree().current_scene.get_scene_file_path()
	if scene_path != "res://sources/language_tool/prof_tool_menu.tscn":
		queue_free() # If we are not in the editor, this autoload is not needed since it is only useful for the prof_tool
