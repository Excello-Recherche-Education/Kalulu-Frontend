@tool
extends CanvasLayer
class_name MinigameUI

signal garden_button_pressed
signal stimulus_button_pressed
signal pause_button_pressed

signal restart_button_pressed
signal back_to_menu_pressed

signal master_volume_changed(volume: float)
signal music_volume_changed(volume: float)
signal voice_volume_changed(volume: float)
signal effects_volume_changed(volume: float)

signal kalulu_button_pressed
signal kalulu_speech_ended

const empty_lives_icon: = preload("res://assets/minigames/minigame_ui/graphic/life_empty.png")
const full_lives_icon: = preload("res://assets/minigames/minigame_ui/graphic/life.png")

@export var empty_progression_icon: Texture
@export var full_progression_icon: Texture

# Using unique names to avoid changing the path if the interface architecture changes
# Left panel
@onready var garden_button: TextureButton = %GardenButton
@onready var stimulus_button: TextureButton = %StimulusButton
@onready var stimulus_texture: TextureRect = %StimulusTexture
@onready var pause_button: TextureButton = %PauseButton
@onready var kalulu_button: TextureButton = %KaluluButton

#Right panel
@onready var volume_button: TextureButton = %VolumeButton

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

@onready var progression_container: = %ProgressionContainer
@onready var model_progression_rect: = %ProgressionIconsRect
@onready var lives_container: = %LivesContainer
@onready var model_lives_rect: = %LivesIconsRect

@onready var animation_player: = $AnimationPlayer


func _ready() -> void:
	model_progression_rect.texture = empty_progression_icon


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
	var lives_rects: = lives_container.get_children()
	# Never remove the first
	for i in range(1, lives_rects.size()):
		if i >= new_max_number_of_lives:
			lives_rects[i].queue_free()
	for i in range(lives_rects.size(), new_max_number_of_lives):
		var new_lives_rect: = model_lives_rect.duplicate()
		new_lives_rect.texture = full_lives_icon
		lives_container.add_child(new_lives_rect)
	model_lives_rect.visible = new_max_number_of_lives >= 1


func set_number_of_lives(new_number_of_lives: int) -> void:
	var max_lives: = lives_container.get_child_count()
	if new_number_of_lives > max_lives:
		set_maximum_number_of_lives(new_number_of_lives)
	var lives_rects: = lives_container.get_children()
	for i in max_lives:
		if i < max_lives - new_number_of_lives:
			lives_rects[i].texture = empty_lives_icon
		else:
			lives_rects[i].texture = full_lives_icon


# ------------ Progression ------------


func set_max_progression(new_max_progression: int) -> void:
	var progression_rects: = progression_container.get_children()
	# Never remove the first
	for i in range(1, progression_rects.size()):
		if i >= new_max_progression:
			progression_rects[i].queue_free()
	for i in range(progression_rects.size(), new_max_progression):
		var new_progression_rect: = model_progression_rect.duplicate()
		new_progression_rect.show()
		new_progression_rect.texture = empty_progression_icon
		progression_container.add_child(new_progression_rect)
	model_progression_rect.visible = new_max_progression >= 1


func set_progression(new_progression: int) -> void:
	var max_progression: = progression_container.get_child_count()
	if new_progression > max_progression:
		set_max_progression(new_progression)
	var progression_rects: = progression_container.get_children()
	for i in max_progression:
		if i < new_progression:
			progression_rects[i].texture = full_progression_icon
		else:
			progression_rects[i].texture = empty_progression_icon


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


func _on_back_to_menu_button_pressed() -> void:
	back_to_menu_pressed.emit()


func repeat_stimulus_animation(appear: bool) -> void:
	if appear:
		animation_player.play("repeat_stimulus")
	else:
		animation_player.play_backwards("repeat_stimulus")
	await animation_player.animation_finished
