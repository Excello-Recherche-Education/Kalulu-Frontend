@tool
extends CanvasLayer
class_name MinigameUI

signal garden_button_pressed
signal stimulus_button_pressed
signal pause_button_pressed

signal restart_button_pressed

signal master_volume_changed(volume: float)
signal music_volume_changed(volume: float)
signal voice_volume_changed(volume: float)
signal effects_volume_changed(volume: float)

signal kalulu_button_pressed
signal kalulu_speech_ended

@export var empty_progression_icon: Texture
@export var full_progression_icon: Texture

# Using unique names to avoid changing the path if the interface architecture changes
# Left panel
@onready var garden_button: TextureButton = %GardenButton
@onready var stimulus_button: TextureButton = %StimulusButton
@onready var pause_button: TextureButton = %PauseButton
@onready var kalulu_button: TextureButton = %KaluluButton

#Right panel
@onready var volume_button: TextureButton = %VolumeButton
@onready var empty_lives_rect: TextureRect = %EmptyLivesRect
@onready var lives_rect: TextureRect = %LivesRect
@onready var progression_gauge: NinePatchRect = %ProgressionGauge
@onready var progression_empty_icons_rect: TextureRect = %ProgressionEmptyIconsRect
@onready var progression_full_icons_rect: TextureRect = %ProgressionFullIconsRect

# Center menu
@onready var center_menu: MarginContainer = %CenterMenu
@onready var restart_button: TextureButton = %RestartButton

# Volume menu
@onready var volume_menu: Control = %VolumeMenu
@onready var master_volume_slider: HSlider = %MasterVolumeSlider
@onready var music_volume_slider: HSlider = %MusicVolumeSlider
@onready var voice_volume_slider: HSlider = %VoiceVolumeSlider
@onready var effects_volume_slider: HSlider = %EffectsVolumeSlider

# Kalulu
@onready var kalulu: Control = %Kalulu

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
	kalulu_button.disabled = true


func unlock() -> void:
	garden_button.disabled = false
	stimulus_button.disabled = false
	pause_button.disabled = false
	kalulu_button.disabled = false


# ------------ Lives ------------


func set_maximum_number_of_lives(new_max_number_of_lives: int) -> void:
	empty_lives_rect.custom_minimum_size.x = new_max_number_of_lives * empty_life_size
	if new_max_number_of_lives <= 0:
		empty_lives_rect.visible = false
	else:
		empty_lives_rect.visible = true


func set_number_of_lives(new_number_of_lives: int) -> void:
	lives_rect.custom_minimum_size.x = new_number_of_lives * life_size
	if new_number_of_lives <= 0:
		lives_rect.visible = false
	else:
		lives_rect.visible = true


# ------------ Progression ------------


func set_max_progression(new_max_progression: int) -> void:
	progression_gauge.custom_minimum_size.y = new_max_progression * progression_gauge_unit_size
	progression_empty_icons_rect.custom_minimum_size.y = new_max_progression * progression_gauge_unit_size
	if new_max_progression <= 0:
		progression_empty_icons_rect.visible = false
	else:
		progression_empty_icons_rect.visible = true


func set_current_progression(new_current_progression: int) -> void:
	progression_full_icons_rect.custom_minimum_size.y = new_current_progression * progression_full_icon_size
	if new_current_progression <= 0:
		progression_full_icons_rect.visible = false
	else:
		progression_full_icons_rect.visible = true


# ------------ Left Panel ------------


func _on_garden_button_pressed() -> void:
	garden_button_pressed.emit()


func _on_stimulus_button_pressed() -> void:
	stimulus_button_pressed.emit()


func _on_pause_button_pressed() -> void:
	pause_button_pressed.emit()


func _on_kalulu_button_pressed() -> void:
	kalulu_button_pressed.emit()


# ------------ Center Menu ------------


func show_center_menu(show_menu: bool) -> void:
	center_menu.visible = show_menu
	garden_button.disabled = show_menu
	stimulus_button.disabled = show_menu
	kalulu_button.disabled = show_menu


func _on_restart_button_pressed() -> void:
	restart_button_pressed.emit()


# ------------ Volume Menu ------------


func set_master_volume_slider(volume: float) -> void:
	master_volume_slider.value = volume


func set_music_volume_slider(volume: float) -> void:
	music_volume_slider.value = volume


func set_voice_volume_slider(volume: float) -> void:
	voice_volume_slider.value = volume


func set_effects_volume_slider(volume: float) -> void:
	effects_volume_slider.value = volume


func _on_volume_button_pressed() -> void:
	volume_menu.visible = not volume_menu.visible


func _on_master_volume_slider_value_changed(volume: float) -> void:
	master_volume_changed.emit(volume)


func _on_music_volume_slider_value_changed(volume: float) -> void:
	music_volume_changed.emit(volume)


func _on_voice_volume_slider_value_changed(volume: float) -> void:
	voice_volume_changed.emit(volume)


func _on_effects_volume_slider_value_changed(volume: float) -> void:
	effects_volume_changed.emit(volume)


# ------------ Kalulu ------------


func play_kalulu_speech(speech: AudioStream) -> void:
	kalulu.play_kalulu_speech(speech)


func _on_kalulu_speech_ended() -> void:
	kalulu_speech_ended.emit()
