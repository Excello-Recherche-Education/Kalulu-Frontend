@tool
extends MarginContainer

signal pressed()

enum Colors {
	Red,
	Green,
}

const animations: = [
	preload("res://sources/minigames/jellyfish/red_jellyfish_animations.tres"),
	preload("res://sources/minigames/jellyfish/green_jellyfish_animations.tres"),
]

const sizes: = [
	Vector2(400, 400),
	Vector2(500, 500),
]

@export var color: = Colors.Red:
	set(value):
		color = value
		if animated_sprite:
			animated_sprite.sprite_frames = animations[color]
		custom_minimum_size = sizes[color] * (1. + randf() * 0.2)

@onready var animated_sprite: = %AnimatedSprite2D
@onready var label: = %AutoSizeLabel.get_node("Label")

var stimulus: Dictionary :
	set(value):
		stimulus = value
		label.text = value.Grapheme


func _ready() -> void:
	var f = randf()
	color = Colors.Red if f < 0.7 else Colors.Green
	animated_sprite.play("idle")
	animated_sprite.frame = randi_range(0, animated_sprite.sprite_frames.get_frame_count("idle") - 1)


func happy() -> void:
	animated_sprite.play("happy")


func idle() -> void:
	animated_sprite.play("idle")


func hit() -> void:
	animated_sprite.play("hit")


func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		pressed.emit()


func delete() -> void:
	var tween: = create_tween()
	tween.tween_property(self, "modulate:a", 0, 1)
	await tween.finished
	queue_free()
