extends Control

const MAIN_MENU_SCENE_PATH: String = "res://sources/menus/main/main_menu.tscn"


func _go_to_main_menu() -> void:
	Log.info("SplashScreen: Changing scene to main menu")
	var err: Error = get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
	if err != 0:
		Log.error("SplashScreen: Error while going to main menu: " + str(err))


func _on_timer_timeout() -> void:
	_go_to_main_menu()


func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		_go_to_main_menu()


func _on_timer_ready() -> void:
	Log.info("SplashScreen: Starting timer")
