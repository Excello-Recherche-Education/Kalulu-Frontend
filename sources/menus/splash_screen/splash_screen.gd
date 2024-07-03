extends Control

const downloader_scene_path: = "res://sources/menus/language_selection/local_package_downloader.tscn"

func _on_timer_timeout():
	get_tree().change_scene_to_file(downloader_scene_path)
