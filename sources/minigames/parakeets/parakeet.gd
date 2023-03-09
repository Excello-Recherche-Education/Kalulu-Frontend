@tool
extends Node2D

const instance_scene: = "res://sources/minigames/parakeets/parakeet.tscn"

signal pressed()

@export var sad_duration: = 2.0

@onready var animated_sprite: = $AnimatedSprite2D
@onready var label: = $Label

var stimulus: Dictionary :
	set(value):
		stimulus = value
		label.text = value.Grapheme

const animations: = [
	preload("res://sources/minigames/parakeets/red_parakeet_animations.tres"),
	preload("res://sources/minigames/parakeets/green_parakeet_animations.tres"),
	preload("res://sources/minigames/parakeets/yellow_parakeet_spritesheet.tres")
]


func _ready() -> void:
	animated_sprite.sprite_frames = animations[randi() % animations.size()]


func _on_button_pressed() -> void:
	pressed.emit()


static func instantiate():
	return load(instance_scene).instantiate()


func turn_to_back() -> void:
	animated_sprite.play("turn_to_back")
	label.hide()
	await animated_sprite.animation_finished
	animated_sprite.play("back")


func turn_to_front() -> void:
	animated_sprite.play_backwards("turn_to_back")
	await animated_sprite.animation_finished
	label.show()
	animated_sprite.play("idle_front")


func _on_animated_sprite_2d_animation_looped() -> void:
	if animated_sprite.animation == "idle_front" and randi() % 4 == 0:
		animated_sprite.play("idle_front_blink")


func fly_to(target: Vector2, duration: float) -> void:
	animated_sprite.play("fly")
	label.position.y = -195
	var tween: = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", target, duration)
	await tween.finished


func happy() -> void:
	animated_sprite.play("happy")


func idle() -> void:
	animated_sprite.play("idle_front")
	label.position.y = -166


func sad() -> void:
	animated_sprite.play("sad")
	await get_tree().create_timer(sad_duration).timeout
