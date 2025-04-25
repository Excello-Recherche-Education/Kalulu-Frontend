extends Control

const main_menu_scene_path: String = "res://sources/menus/main/main_menu.tscn"


func _go_to_main_menu() -> void:
	var err: Error = get_tree().change_scene_to_file(main_menu_scene_path)
	if err != 0:
		Logger.error("SplashScreen: Error while going to main menu: " + str(err))


func _on_timer_timeout() -> void:
	_go_to_main_menu()


func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		_go_to_main_menu()
