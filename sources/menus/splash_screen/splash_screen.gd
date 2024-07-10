extends Control

const main_menu_scene_path: = "res://sources/menus/main/main_menu.tscn"


func _go_to_main_menu() -> void:
	get_tree().change_scene_to_file(main_menu_scene_path)


func _on_timer_timeout():
	_go_to_main_menu()


func _on_gui_input(event):
	if event.is_action_pressed("left_click"):
		_go_to_main_menu()
