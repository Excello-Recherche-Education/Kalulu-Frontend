@tool
extends Control

signal crab_hit(stimulus: Dictionary)

@onready var body: Control = $Body
@onready var animated_sprite: AnimatedSprite2D = %AnimatedSprite2D
@onready var label: Label = $Body/Label
@onready var button: Button = $Button
@onready var highlight_fx: HighlightFX = %HighlightFX
@onready var right_fx: RightFX = %RightFX
@onready var wrong_fx: WrongFX = %WrongFX
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer

var sounds: = [
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


func _ready() -> void:
	set_button_active(false)
	animated_sprite.play("idle1")
	_on_audio_stream_player_finished()


func set_button_active(active: bool) -> void:
	button.disabled = not active


func is_button_pressed() -> bool:
	await button.pressed
	return true


func highlight() -> void:
	highlight_fx.play()


func is_highlighted() -> bool:
	return highlight_fx.is_playing


func right() -> void:
	right_fx.play()
	await right_fx.finished


func wrong() -> void:
	wrong_fx.play()
	await wrong_fx.finished


func _set_stimulus(value: Dictionary) -> void:
	stimulus = value
	if stimulus.has("Grapheme"):
		label.text = stimulus.Grapheme


func _on_button_pressed() -> void:
	crab_hit.emit(stimulus)
	animated_sprite.play("hit")


func _on_animated_sprite_2d_animation_finished() -> void:
	match animated_sprite.animation:
		"idle1", "idle2":
			if randf() < 0.5 :
				animated_sprite.play("idle1") 
			else : 
				animated_sprite.play("idle2")
		"hit":
			animated_sprite.play("hurt")


func _on_audio_stream_player_finished() -> void:
	audio_stream_player.stream = sounds[randi_range(0, sounds.size() - 1)]
	audio_stream_player.play()
