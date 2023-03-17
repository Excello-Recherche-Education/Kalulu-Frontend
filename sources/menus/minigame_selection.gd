extends Control



func _on_monkeys_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/minigames/monkeys/monkeys_minigame.tscn")


func _on_crabs_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/minigames/crabs/crabs_minigame.tscn")


func _on_parakeets_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/minigames/parakeets/parakeets_minigame.gd")
