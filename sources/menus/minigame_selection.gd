extends Control

func _ready():
	OpeningCurtain.open()

func _on_monkeys_button_pressed() -> void:
	await OpeningCurtain.close()
	get_tree().change_scene_to_file("res://sources/minigames/monkeys/monkeys_minigame.tscn")


func _on_crabs_button_pressed() -> void:
	await OpeningCurtain.close()
	get_tree().change_scene_to_file("res://sources/minigames/crabs/crabs_minigame.tscn")


func _on_parakeets_button_pressed() -> void:
	await OpeningCurtain.close()
	get_tree().change_scene_to_file("res://sources/minigames/parakeets/parakeets_minigame.tscn")


func _on_frog_button_pressed() -> void:
	await OpeningCurtain.close()
	get_tree().change_scene_to_file("res://sources/minigames/frog/frog_minigame.tscn")


func _on_jellyfish_button_pressed() -> void:
	await OpeningCurtain.close()
	get_tree().change_scene_to_file("res://sources/minigames/jellyfish/jellyfish_minigame.tscn")
