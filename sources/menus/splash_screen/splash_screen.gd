extends Control

const next_scene_path: = "res://sources/menus/main/main_menu.tscn"
const error_scene_path: = "res://sources/menus/splash_screen/error_screen.tscn"

func _on_timer_timeout():
	if Database.is_open:
		get_tree().change_scene_to_file(next_scene_path)
	else:
		get_tree().change_scene_to_file(error_scene_path)
