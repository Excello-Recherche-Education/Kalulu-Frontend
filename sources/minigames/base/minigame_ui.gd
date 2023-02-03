extends CanvasLayer
class_name MinigameUI

signal garden_button_pressed
signal stimulus_button_pressed
signal pause_button_pressed
signal kalulu_button_pressed
signal kalulu_speech_end

@export var empty_progression_icon: Texture
@export var full_progression_icon: Texture

# Using unique names to avoid changing the path if the interface architecture changes
@onready var garden_button: TextureButton = get_node("%GardenButton")
@onready var stimulus_button: TextureButton = get_node("%StimulusButton")
@onready var pause_button: TextureButton = get_node("%PauseButton")
@onready var Kalulu_button: TextureButton = get_node("%KaluluButton")
@onready var empty_lives_rect: TextureRect = get_node("%EmptyLivesRect")
@onready var lives_rect: TextureRect = get_node("%LivesRect")
@onready var progression_gauge: NinePatchRect = get_node("%ProgressionGauge")
@onready var progression_empty_icons_rect: TextureRect = get_node("%ProgressionEmptyIconsRect")
@onready var progression_full_icons_rect: TextureRect = get_node("%ProgressionFullIconsRect")

# Kalulu
@onready var kalulu: = $MainControl/Kalulu

# Lives management
var empty_life_size: = 0.0
var life_size: = 0.0

# Progression management
var progression_gauge_unit_size: = 0.0
var progression_empty_icon_size: = 0.0
var progression_full_icon_size: = 0.0

# ------------ Initialisation ------------


func _ready() -> void:
	progression_empty_icons_rect.texture = empty_progression_icon
	progression_full_icons_rect.texture = full_progression_icon
	
	empty_life_size = empty_lives_rect.custom_minimum_size.x
	life_size = lives_rect.custom_minimum_size.x
	
	progression_gauge_unit_size = progression_gauge.custom_minimum_size.y
	progression_empty_icon_size = progression_empty_icons_rect.custom_minimum_size.y
	progression_full_icon_size = progression_full_icons_rect.custom_minimum_size.y


# ------------ Lock/Unlock ------------


func lock() -> void:
	garden_button.disabled = true
	stimulus_button.disabled = true
	pause_button.disabled = true
	Kalulu_button.disabled = true


func unlock() -> void:
	garden_button.disabled = false
	stimulus_button.disabled = false
	pause_button.disabled = false
	Kalulu_button.disabled = false


# ------------ Lives ------------


func set_maximum_number_of_lives(new_max_number_of_lives: int) -> void:
	empty_lives_rect.custom_minimum_size.x = new_max_number_of_lives * empty_life_size
	if new_max_number_of_lives == 0:
		empty_lives_rect.scale.x = 0
	else:
		empty_lives_rect.scale.x = 1


func set_number_of_lives(new_number_of_lives: int) -> void:
	lives_rect.custom_minimum_size.x = new_number_of_lives * life_size
	if new_number_of_lives == 0:
		lives_rect.scale.x = 0
	else:
		lives_rect.scale.x = 1


# ------------ Progression ------------


func set_max_progression(new_max_progression: int) -> void:
	progression_gauge.custom_minimum_size.y = new_max_progression * progression_gauge_unit_size
	progression_empty_icons_rect.custom_minimum_size.y = new_max_progression * progression_gauge_unit_size
	if new_max_progression == 0:
		progression_empty_icons_rect.scale.y = 0
	else:
		progression_empty_icons_rect.scale.y = 1


func set_current_progression(new_current_progression: int) -> void:
	progression_full_icons_rect.custom_minimum_size.y = new_current_progression * progression_full_icon_size
	if new_current_progression == 0:
		progression_full_icons_rect.scale.y = 0
	else:
		progression_full_icons_rect.scale.y = 1


# ------------ Actions ------------


func _on_garden_button_pressed() -> void:
	garden_button_pressed.emit()


func _on_stimulus_button_pressed() -> void:
	stimulus_button_pressed.emit()


func _on_pause_button_pressed() -> void:
	pause_button_pressed.emit()


func _on_kalulu_button_pressed() -> void:
	kalulu_button_pressed.emit()


# ------------ Kalulu ------------


func play_kalulu_speech(speech: AudioStream) -> void:
	kalulu.play_kalulu_speech(speech)


func _on_kalulu_kalulu_speech_end() -> void:
	emit_signal("kalulu_speech_end")
