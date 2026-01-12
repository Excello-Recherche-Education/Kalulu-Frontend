class_name Parakeet
extends Node2D

signal pressed()

enum Colors {
	Red,
	Green,
	Yellow,
}

const ANIMATIONS: Array[SpriteFrames] = [
	preload("res://sources/minigames/parakeets/red_parakeet_animations.tres"),
	preload("res://sources/minigames/parakeets/green_parakeet_animations.tres"),
	preload("res://sources/minigames/parakeets/yellow_parakeet_animation.tres")
]
const FEATHERS_ANIMATIONS: Array[SpriteFrames] = [
	preload("res://sources/minigames/parakeets/red_parakeet_feathers_animations.tres"),
	preload("res://sources/minigames/parakeets/green_parakeet_feathers_animations.tres"),
	preload("res://sources/minigames/parakeets/yellow_parakeet_feathers_animations.tres")
]

@export var sad_duration: float = 2.0
@export var color: Colors = Colors.Red:
	set(value):
		color = value
		if animated_sprite:
			animated_sprite.sprite_frames = ANIMATIONS[color]
			animated_sprite_2d_feathers.sprite_frames = FEATHERS_ANIMATIONS[color]
@export var uppercase: bool = true:
	set(value):
		uppercase = value
		if label:
			label.text = label.text.to_upper() if uppercase else label.text.to_lower()

var stimulus: Dictionary = {}:
	set(value):
		stimulus = value
		var grapheme: String = value.Grapheme as String
		label.text = grapheme.to_upper() if uppercase else grapheme
var original_label_settings: LabelSettings
var original_text_box_color: Color

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var animated_sprite_2d_feathers: AnimatedSprite2D = $AnimatedSprite2D_Feathers
@onready var label: Label = $Label
@onready var right_fx: RightFX = $RightFX
@onready var right_stars: RightStarsFX = $Right_Stars
@onready var wrong_fx: WrongFX = $WrongFX
@onready var text_box_sprite_2d: Sprite2D = %TextBox_Sprite2D
@onready var text_box_outline_sprite_2d: Sprite2D = %TextBox_Outline_Sprite2D


func _ready() -> void:
	color = color
	animated_sprite.play("idle_front")
	original_label_settings = label.label_settings
	original_text_box_color = text_box_sprite_2d.self_modulate


func _on_button_pressed() -> void:
	pressed.emit()


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
	if animated_sprite.animation == "idle_front":
		if randi() % 4 == 0:
			animated_sprite.play("idle_front_blink")
	elif animated_sprite.animation == "idle_front_blink":
		animated_sprite.play("idle_front")


func fly_to(target: Vector2, duration: float) -> void:
	animated_sprite.play("fly")
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", target, duration)
	await tween.finished


func happy() -> void:
	animated_sprite.play("happy")


func idle() -> void:
	animated_sprite.play("idle_front")


func sad() -> void:
	animated_sprite.play("sad")
	animated_sprite_2d_feathers.modulate.a = 1.0
	animated_sprite_2d_feathers.show()
	animated_sprite_2d_feathers.play("feathers_fall")
	await get_tree().create_timer(sad_duration).timeout
	label.label_settings = original_label_settings
	text_box_sprite_2d.self_modulate = original_text_box_color
	text_box_outline_sprite_2d.visible = false
	call_deferred("_hide_feathers")


func _hide_feathers() -> void:
	await get_tree().create_timer(1).timeout
	var tween: Tween = create_tween()
	tween.tween_property(animated_sprite_2d_feathers, "modulate:a", 0.0, 0.5)
	tween.finished.connect(func() -> void:
		animated_sprite_2d_feathers.hide()
	)


func right() -> void:
	label.label_settings = label.label_settings.duplicate()
	label.label_settings.font_color = Color("#009444")
	text_box_sprite_2d.self_modulate = Color("#e6f3e0")
	text_box_outline_sprite_2d.self_modulate = Color("#009344")
	text_box_outline_sprite_2d.visible = true
	right_stars.play()
	right_fx.play()
	await right_fx.finished


func wrong() -> void:
	label.label_settings = label.label_settings.duplicate()
	label.label_settings.font_color = Color("#be1e2d")
	text_box_sprite_2d.self_modulate = Color("#fce6e6")
	text_box_outline_sprite_2d.self_modulate = Color("#be1e2d")
	text_box_outline_sprite_2d.visible = true
	wrong_fx.play()
	await wrong_fx.finished
