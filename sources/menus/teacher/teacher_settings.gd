extends Control

const main_menu_path := "res://sources/menus/main/main_menu.tscn"
const login_menu_path := "res://sources/menus/login/login.tscn"


func _on_back_button_pressed():
	get_tree().change_scene_to_file(login_menu_path)


func _on_button_pressed():
	if UserDataManager.teacher_settings:
		print(UserDataManager.teacher_settings.students)


func _on_logout_button_pressed():
	UserDataManager.logout()
	get_tree().change_scene_to_file(main_menu_path)
