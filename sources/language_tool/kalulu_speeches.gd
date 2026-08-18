extends Control

const TITLE_SCENE: PackedScene = preload("res://sources/language_tool/kalulu_speech_title.tscn")
const SPEECH_SCENE: PackedScene = preload("res://sources/language_tool/kalulu_speech.tscn")

@onready var speech_container: VBoxContainer = %SpeechContainer


func _ready() -> void:
	var speeches: Dictionary[String, Dictionary] = {
		"title_screen": {
			"feedback_welcome": "Not used by the game any more",
			"tuto_welcome_oneshot": "Greeting played after the splash screen",
		},
		"login_screen": {
			"feedback_right_password": "Right access code entered",
			"feedback_wrong_password": "Wrong access code entered",
			"help_code": "Help button on the access code screen",
			"tuto_code_oneshot": "Not used by the game any more",
		},
		"brain_screen":{
			"intro_1": "First arrival in the gardens, 1 of 3",
			"intro_2": "First arrival in the gardens, 2 of 3",
			"intro_3": "First arrival in the gardens, 3 of 3",
			"help": "Kalulu tapped on the brain map",
			"victory": "Endgame reward, after the final boss"
		},
		"gardens_screen":{
			"intro": "First arrival, after the brain tutorial",
			"help_few_plants": "Help button, garden under 75% grown",
			"help_many_plants": "Help button, garden over 75% grown",
		},
		"minigame": {
			"lose": "Played when any minigame is lost",
		},
		"ants": {
			"intro": "First play of this minigame",
			"help": "Help button during this minigame",
			"end": "Played when this minigame is won",
		},
		"caterpillar": {
			"intro": "First play of this minigame",
			"help": "Help button during this minigame",
			"end": "Played when this minigame is won",
		},
		"crabs": {
			"intro": "First play of this minigame",
			"help": "Help button during this minigame",
			"end": "Played when this minigame is won",
		},
		"fish": {
			"intro": "First play of this minigame",
			"intro_test_game_first_word": "Tutorial: first word presented",
			"lose_test_game_first_word": "Tutorial: first word answered wrong",
			"win_test_game_first_word": "Tutorial: first word answered right",
			"lose_test_game_second_word": "Tutorial: second word answered wrong",
			"win_test_game_second_word": "Tutorial: second word answered right",
			"end": "Played when this minigame is won",
			"lose": "Not used by the game any more",
		},
		"frog": {
			"intro": "First play of this minigame",
			"help": "Help button during this minigame",
			"end": "Played when this minigame is won",
		},
		"jellyfish": {
			"intro": "First play of this minigame",
			"help": "Help button during this minigame",
			"end": "Played when this minigame is won",
		},
		"monkey": {
			"intro": "First play of this minigame",
			"help": "Help button during this minigame",
			"end": "Played when this minigame is won",
		},
		"parakeets": {
			"intro": "First play of this minigame",
			"help": "Help button during this minigame",
			"end": "Played when this minigame is won",
		},
		"penguin":{
			"intro": "First play of this minigame",
			"help": "Help button during this minigame",
			"end": "Played when this minigame is won",
		},
		"turtles":{
			"intro": "First play of this minigame",
			"help": "Help button during this minigame",
			"end": "Played when this minigame is won",
		}
	}
	
	for speech_title: String in speeches.keys():
		var title: KaluluTitle = TITLE_SCENE.instantiate()
		title.title = speech_title
		speech_container.add_child(title)
		
		for speech_name: String in speeches[speech_title].keys():
			var speech: KaluluSpeech = SPEECH_SCENE.instantiate()
			speech.speech_category = speech_title
			speech.speech_name = speech_name
			speech.speech_description = speeches[speech_title][speech_name]
			speech_container.add_child(speech)


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sources/language_tool/prof_tool_menu.tscn")
