extends CanvasLayer
class_name MinigameUI

signal garden_button_pressed
signal stimulus_button_pressed
signal pause_button_pressed
signal kalulu_button_pressed

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

# Lives management
var max_number_of_lives: = 1
var number_of_lives: = 1
var empty_life_size: = 0.0
var life_size: = 0.0

# Progression management
var max_progression: = 1
var current_progression: = 1
var progression_gauge_unit_size: = 0.0
var progression_empty_icon_size: = 0.0
var progression_full_icon_size: = 0.0


# ------------ Initialisation ------------


func _ready() -> void:
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
	max_number_of_lives = number_of_lives
	
	empty_lives_rect.custom_minimum_size.x = new_max_number_of_lives * empty_life_size


func set_number_of_lives(new_number_of_lives: int) -> void:
	if new_number_of_lives > max_number_of_lives:
		set_maximum_number_of_lives(new_number_of_lives)
	
	number_of_lives = new_number_of_lives
	
	lives_rect.custom_minimum_size.x = new_number_of_lives * life_size


# ------------ Progression ------------


func set_max_progression(new_max_progression: int) -> void:
	max_progression = new_max_progression
	
	progression_gauge.custom_minimum_size.y = new_max_progression * progression_gauge_unit_size
	progression_empty_icons_rect.custom_minimum_size.y = new_max_progression * progression_gauge_unit_size


func set_current_progression(new_current_progression: int) -> void:
	if current_progression > max_progression:
		set_max_progression(new_current_progression)
	
	current_progression = new_current_progression
	
	progression_full_icons_rect.custom_minimum_size.y = new_current_progression * progression_full_icon_size


# ------------ Actions ------------


func _on_garden_button_pressed() -> void:
	garden_button_pressed.emit()


func _on_stimulus_button_pressed() -> void:
	stimulus_button_pressed.emit()


func _on_pause_button_pressed() -> void:
	pause_button_pressed.emit()


func _on_kalulu_button_pressed() -> void:
	kalulu_button_pressed.emit()


