@tool
class_name Crab
extends Control

signal crab_hit(stimulus: Dictionary)

var sounds: Array[AudioStreamMP3] = [
	preload("res://assets/minigames/crabs/audio/sfx/crab_random_1.mp3"),
	preload("res://assets/minigames/crabs/audio/sfx/crab_random_2.mp3"),
	preload("res://assets/minigames/crabs/audio/sfx/crab_random_3.mp3"),
	preload("res://assets/minigames/crabs/audio/sfx/crab_random_4.mp3"),
	preload("res://assets/minigames/crabs/audio/sfx/crab_random_5.mp3"),
	preload("res://assets/minigames/crabs/audio/sfx/crab_random_6.mp3"),
	preload("res://assets/minigames/crabs/audio/sfx/crab_random_7.mp3"),
	preload("res://assets/minigames/crabs/audio/sfx/crab_random_8.mp3"),
	preload("res://assets/minigames/crabs/audio/sfx/crab_random_9.mp3"),
	preload("res://assets/minigames/crabs/audio/sfx/crab_random_10.mp3"),
	preload("res://assets/minigames/crabs/audio/sfx/crab_random_11.mp3"),
	preload("res://assets/minigames/crabs/audio/sfx/crab_random_12.mp3"),
	preload("res://assets/minigames/crabs/audio/sfx/crab_random_13.mp3"),
]
var stimulus: Dictionary:
	set = _set_stimulus
var blink_counter: int = 0
var blink_delay: int = 3
var blink_random: int = 3

@onready var body: Control = $Body
@onready var animated_sprite: AnimatedSprite2D = %AnimatedSprite2D
@onready var label: Label = %AutoSizeLabel.get_node("Label")
@onready var button: Button = $Button
@onready var highlight_fx: HighlightFX = %HighlightFX
@onready var right_fx: RightFX = %RightFX
@onready var wrong_fx: WrongFX = %WrongFX
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var text_outline: Sprite2D = %TextBox_Outline_Sprite2D
@onready var text_box_sprite_2d: Sprite2D = %TextBox_Sprite2D


func _ready() -> void:
	set_button_active(false)
	animated_sprite.play("idle")
	if not Engine.is_editor_hint():
		_on_audio_stream_player_finished()


func set_button_active(active: bool) -> void:
	button.disabled = not active


func is_button_pressed() -> bool:
	await button.pressed
	return true


func show_label() -> void:
	label.visible = true


func hide_label() -> void:
	label.visible = false


func highlight() -> void:
	highlight_fx.play()


func is_highlighted() -> bool:
	return highlight_fx.is_playing


func right() -> void:
	label.label_settings = label.label_settings.duplicate()
	label.label_settings.font_color = Color("#009444")
	text_box_sprite_2d.self_modulate = Color("#e6f3e0")
	text_outline.self_modulate = Color("#009344")
	text_outline.visible = true
	animated_sprite.play("right")
	right_fx.play()
	await right_fx.finished


func wrong() -> void:
	label.label_settings = label.label_settings.duplicate()
	label.label_settings.font_color = Color("#be1e2d")
	text_box_sprite_2d.self_modulate = Color("#fce6e6")
	text_outline.self_modulate = Color("#be1e2d")
	text_outline.visible = true
	animated_sprite.play("wrong")
	wrong_fx.play()
	await wrong_fx.finished


func _set_stimulus(value: Dictionary) -> void:
	stimulus = value
	if stimulus.has("Grapheme"):
		label.text = stimulus.Grapheme


func _on_button_pressed() -> void:
	crab_hit.emit(stimulus)


func _on_animated_sprite_2d_animation_finished() -> void:
	match animated_sprite.animation:
		"idle":
			blink_counter -= 1
			if blink_counter <= 0:
				blink_counter = blink_delay + randi_range(0, blink_random)
				animated_sprite.play("idle_blink") 
			else: 
				animated_sprite.play("idle")
		"idle_blink":
			animated_sprite.play("idle")


func _on_audio_stream_player_finished() -> void:
	audio_stream_player.stream = sounds[randi_range(0, sounds.size() - 1)]
	audio_stream_player.play()
