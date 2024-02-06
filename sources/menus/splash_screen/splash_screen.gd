extends Control

const next_scene_path: = "res://sources/menus/main/main_menu.tscn"

func _on_timer_timeout():
	get_tree().change_scene_to_file(next_scene_path)
