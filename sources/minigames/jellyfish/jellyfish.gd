@tool
extends Control
class_name Jellyfish

signal pressed()

enum Colors {
	Red,
	Green,
}

const animations: = [
	preload("res://sources/minigames/jellyfish/red_jellyfish_animations.tres"),
	preload("res://sources/minigames/jellyfish/green_jellyfish_animations.tres"),
]

const scales: = [
	Vector2(1.,1.),
	Vector2(1.25, 1.25)
]

const scale_factor : float = 0.2

@export var color: = Colors.Red:
	set(value):
		color = value
		if animated_sprite:
			animated_sprite.sprite_frames = animations[color]
		scale = scales[color] * (1. + randf() * scale_factor)
		
		# Handles sprite size
		$SpriteControl.resized.emit()


@onready var animated_sprite: = %AnimatedSprite2D
@onready var label: = %AutoSizeLabel.get_node("Label")
@onready var highlight_fx: = %HighlightFX
@onready var right_fx: = %RightFX
@onready var wrong_fx: = %WrongFX

var stimulus: Dictionary :
	set(value):
		stimulus = value
		if label:
			if value.has("Grapheme"):
				label.text = value.Grapheme
			else:
				label.text = ""


func _ready() -> void:
	stimulus = stimulus
	
	var f = randf()
	color = Colors.Red if f < 0.7 else Colors.Green
	animated_sprite.play("idle")
	animated_sprite.frame = randi_range(0, animated_sprite.sprite_frames.get_frame_count("idle") - 1)


func is_idle() -> bool:
	return animated_sprite.animation == "idle"


func happy() -> void:
	animated_sprite.play("happy")


func idle() -> void:
	animated_sprite.play("idle")


func hit() -> void:
	animated_sprite.play("hit")


func highlight() -> void:
	highlight_fx.play()


func stop_highlight() -> void:
	highlight_fx.stop()


func right() -> void:
	right_fx.play()
	await right_fx.finished


func wrong() -> void:
	wrong_fx.play()
	await wrong_fx.finished


func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		pressed.emit()


func delete() -> void:
	var tween: = create_tween()
	tween.tween_property(self, "modulate:a", 0, 2)
	await tween.finished
	queue_free()
