extends Control


func _on_button_pressed():
	print(UserDataManager.teacher_settings.students)


func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://sources/menus/login/login.tscn")
