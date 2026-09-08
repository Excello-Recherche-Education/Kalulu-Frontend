class_name MinigameUI
extends CanvasLayer

signal back_button_pressed()
signal stimulus_button_pressed()
signal restart_button_pressed()
signal kalulu_button_pressed()
signal kalulu_speech_ended()
signal pause_ended()

const KALULU: GDScript = preload("res://sources/minigames/base/kalulu_ingame.gd")
const BACK_BUTTON_HOLD_DURATION_SECONDS: float = 1.0

@export var empty_progression_icon: Texture
@export var full_progression_icon: Texture
@export var stimulus_button_visible: bool = true:
	set(visible):
		stimulus_button_visible = visible
		if stimulus_button:
			_handle_stimulus_button()

var is_paused: bool = false
var back_button_hold_progress_seconds: float = 0.0
var is_back_button_hold_active: bool = false

@onready var back_button: BackButton = %BackButton
@onready var stimulus_button: TextureButton = %StimulusButton
@onready var pause_button: TextureButton = %PauseButton
@onready var kalulu_button: TextureButton = %KaluluButton
@onready var center_menu: MarginContainer = %CenterMenu
@onready var kalulu: KALULU = %Kalulu
@onready var progression_container: VBoxContainer = %ProgressionContainer
@onready var progression_gauge: NinePatchRect = %ProgressionGauge
@onready var model_progression_rect: TextureRect = %ProgressionIconsRect


func _ready() -> void:
	model_progression_rect.texture = empty_progression_icon
	_handle_stimulus_button()
	_cancel_back_button_hold()


func _process(delta: float) -> void:
	_process_back_button_hold(delta)


## Gives the tree back before this screen disappears.
##
## Two things here pause the whole tree: the pause menu, and Kalulu talking. Both
## belong to this screen, and both can be walked out of -- the back and restart
## buttons sit under this CanvasLayer, whose process_mode is ALWAYS, so they keep
## working while everything else is frozen. get_tree().paused is global and
## survives a scene change, so a pause left behind follows the player into the
## gardens, where _ready() raises its lock and then waits on timers and tweens that
## are themselves paused: the lock is never lifted, and the whole screen stops
## responding to clicks while looking perfectly normal.
func _exit_tree() -> void:
	if get_tree() and get_tree().paused:
		Log.trace("MinigameUI: Releasing the tree on the way out")
		get_tree().paused = false


func _process_back_button_hold(delta: float) -> void:
	if not is_back_button_hold_active:
		return
	if is_paused or back_button.disabled:
		_cancel_back_button_hold()
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or not back_button.get_global_rect().has_point(get_viewport().get_mouse_position()):
		_cancel_back_button_hold()
		return
	back_button_hold_progress_seconds += delta
	var progress_ratio: float = clampf(back_button_hold_progress_seconds / BACK_BUTTON_HOLD_DURATION_SECONDS, 0.0, 1.0)
	back_button.set_hold_progress_ratio(progress_ratio)
	if progress_ratio >= 1.0:
		_cancel_back_button_hold()
		_emit_back_button_pressed()


func _handle_stimulus_button() -> void:
	stimulus_button.set_visible(stimulus_button_visible)

#region Locking

func lock() -> void:
	back_button.set_disabled(true)
	_cancel_back_button_hold()
	stimulus_button.set_disabled(true)
	pause_button.set_disabled(true)
	kalulu_button.set_disabled(true)


func unlock() -> void:
	back_button.set_disabled(false)
	stimulus_button.set_disabled(false)
	pause_button.set_disabled(false)
	kalulu_button.set_disabled(false)

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
	model_progression_rect.set_visible(new_max_progression >= 1)


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

func _emit_back_button_pressed() -> void:
	back_button_pressed.emit()


func _on_back_button_button_down() -> void:
	if back_button.disabled or is_back_button_hold_active:
		return
	is_back_button_hold_active = true
	back_button_hold_progress_seconds = 0.0
	back_button.begin_hold()


func _on_back_button_button_up() -> void:
	_cancel_back_button_hold()


func _cancel_back_button_hold() -> void:
	is_back_button_hold_active = false
	back_button_hold_progress_seconds = 0.0
	back_button.cancel_hold()


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
	center_menu.set_visible(show_menu)
	back_button.set_disabled(show_menu)
	if show_menu:
		_cancel_back_button_hold()
	stimulus_button.set_disabled(show_menu)
	kalulu_button.set_disabled(show_menu)
	pause_button.set_visible(!show_menu)


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
