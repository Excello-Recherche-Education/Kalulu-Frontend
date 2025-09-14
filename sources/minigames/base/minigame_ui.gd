@tool
class_name MinigameUI
extends CanvasLayer

signal garden_button_pressed()
signal stimulus_button_pressed()
signal restart_button_pressed()
signal kalulu_button_pressed()
signal kalulu_speech_ended()
signal pause_ended()

const KALULU := preload("res://sources/minigames/base/kalulu.gd")

@export var empty_progression_icon: Texture
@export var full_progression_icon: Texture
@export var stimulus_button_visible: bool = true:
	set(visible):
		stimulus_button_visible = visible
		if stimulus_button:
			_handle_stimulus_button()

var is_paused: bool = false

@onready var garden_button: TextureButton = %GardenButton
@onready var stimulus_margin: MarginContainer = %StimulusMargin
@onready var stimulus_button: TextureButton = %StimulusButton
@onready var stimulus_texture: TextureRect = %StimulusTexture
@onready var pause_margin: MarginContainer = %PauseMargin
@onready var pause_button: TextureButton = %PauseButton
@onready var kalulu_button: TextureButton = %KaluluButton
@onready var center_menu: MarginContainer = %CenterMenu
@onready var kalulu: KALULU = %Kalulu
@onready var progression_container: VBoxContainer = %ProgressionContainer
@onready var progression_gauge: NinePatchRect = %ProgressionGauge
@onready var model_progression_rect: TextureRect = %ProgressionIconsRect
@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	model_progression_rect.texture = empty_progression_icon
	_handle_stimulus_button()


func _handle_stimulus_button() -> void:
	stimulus_margin.visible = stimulus_button_visible
	if stimulus_button_visible:
		pause_margin.size_flags_stretch_ratio = 1
	else:
		pause_margin.size_flags_stretch_ratio = 2

#region Locking

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

#endregion

#region Progression

func set_max_progression(new_max_progression: int) -> void:
	if is_paused:
		await pause_ended
	var progression_rects: Array[Node] = progression_container.get_children()
	# Never remove the first
	for index: int in range(1, progression_rects.size()):
		if index >= new_max_progression:
			progression_rects[index].queue_free()
	for index: int in range(progression_rects.size(), new_max_progression):
		var new_progression_rect: TextureRect = model_progression_rect.duplicate()
		new_progression_rect.show()
		new_progression_rect.texture = empty_progression_icon
		progression_container.add_child(new_progression_rect)
	model_progression_rect.visible = new_max_progression >= 1


func set_progression(new_progression: int) -> void:
	if is_paused:
		await pause_ended
	var max_progression: int = progression_container.get_child_count()
	if new_progression > max_progression:
		set_max_progression(new_progression)
	var progression_rects: Array[Node] = progression_container.get_children()
	for index: int in range(max_progression):
		var progression_rect: TextureRect = progression_rects[index]
		if index < new_progression:
			progression_rect.texture = full_progression_icon
		else:
			progression_rect.texture = empty_progression_icon

#endregion

#region Left Panel

func _on_garden_button_pressed() -> void:
	garden_button_pressed.emit()


func _on_stimulus_button_pressed() -> void:
	stimulus_button_pressed.emit()


func _on_pause_button_pressed() -> void:
	is_paused = true
	show_center_menu(true)
	get_tree().paused = true


func _on_kalulu_button_pressed() -> void:
	kalulu_button_pressed.emit()

#endregion

#region Pause Menu

func show_center_menu(show_menu: bool) -> void:
	center_menu.visible = show_menu
	garden_button.disabled = show_menu
	stimulus_button.disabled = show_menu
	kalulu_button.disabled = show_menu
	pause_button.visible = !show_menu


func _on_restart_button_pressed() -> void:
	restart_button_pressed.emit()


func _on_continue_button_pressed() -> void:
	is_paused = false
	show_center_menu(false)
	get_tree().paused = false
	
	pause_ended.emit()


#endregion

#region Kalulu

func play_kalulu_speech(speech: AudioStream) -> void:
	if is_paused:
		await pause_ended
	kalulu_button.hide()
	get_tree().paused = true
	kalulu.play_kalulu_speech(speech)


func _on_kalulu_speech_ended() -> void:
	kalulu_button.show()
	get_tree().paused = false
	pause_ended.emit()
	kalulu_speech_ended.emit()

#endregion

func repeat_stimulus_animation(appear: bool) -> void:
	if appear:
		animation_player.play("repeat_stimulus")
	else:
		animation_player.play_backwards("repeat_stimulus")
	await animation_player.animation_finished
