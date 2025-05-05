extends Control

const KaluluTitle: = preload("res://sources/language_tool/kalulu_speech_title.gd")
const KaluluSpeech: = preload("res://sources/language_tool/kalulu_speech.gd")

const title_scene: PackedScene = preload("res://sources/language_tool/kalulu_speech_title.tscn")
const speech_scene: PackedScene = preload("res://sources/language_tool/kalulu_speech.tscn")

@onready var speech_container: VBoxContainer = %SpeechContainer


func _ready() -> void:
	var speeches: Dictionary[String, Dictionary] = {
		"title_screen": {
			"feedback_welcome": "",
			"tuto_welcome_oneshot": "",
		},
		"login_screen": {
			"feedback_right_password": "",
			"feedback_wrong_password": "",
			"help_code": "",
			"tuto_code_oneshot": "",
		},
		"brain_screen":{
			"intro_1": "",
			"intro_2": "",
			"intro_3": "",
			"help": ""
		},
		"gardens_screen":{
			"intro": "",
			"help_few_plants": "",
			"help_many_plants": "",
		},
		"minigame": {
			"lose": "",
		},
		"ants": {
			"intro": "",
			"help": "",
			"end": "",
		},
		"caterpillar": {
			"intro": "",
			"help": "",
			"end": "",
		},
		"crabs": {
			"intro": "",
			"help": "",
			"end": "",
		},
		"fish": {
			"intro": "",
			"intro_test_game_first_word": "",
			"lose_test_game_first_word": "",
			"win_test_game_first_word": "",
			"lose_test_game_second_word": "",
			"win_test_game_second_word": "",
			"end": "",
			"lose": "",
		},
		"frog": {
			"intro": "",
			"help": "",
			"end": "",
		},
		"jellyfish": {
			"intro": "",
			"help": "",
			"end": "",
		},
		"monkey": {
			"intro": "",
			"help": "",
			"end": "",
		},
		"parakeets": {
			"intro": "",
			"help": "",
			"end": "",
		},
		"penguin":{
			"intro": "",
			"help": "",
			"end": "",
		},
		"turtles":{
			"intro": "",
			"help": "",
			"end": "",
		}
	}
	
	for speech_title: String in speeches.keys():
		var title: KaluluTitle = title_scene.instantiate()
		title.title = speech_title
		speech_container.add_child(title)
		
		for speech_name: String in speeches[speech_title].keys():
			var speech: KaluluSpeech = speech_scene.instantiate()
			speech.speech_category = speech_title
			speech.speech_name = speech_name
			speech.speech_description = speeches[speech_title][speech_name]
			speech_container.add_child(speech)


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/prof_tool_menu.tscn")
