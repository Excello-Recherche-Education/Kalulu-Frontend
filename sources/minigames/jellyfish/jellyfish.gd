@tool
class_name Jellyfish
extends Control

signal pressed(stimulus: Dictionary)

enum Colors {
	Red,
	Green,
}

const ANIMATIONS_BODY: Array[SpriteFrames] = [
	preload("res://sources/minigames/jellyfish/blue_jellyfish_animations_body.tres"),
	preload("res://sources/minigames/jellyfish/pink_jellyfish_animations_body.tres"),
]
const ANIMATIONS_ARMS: Array[SpriteFrames] = [
	preload("res://sources/minigames/jellyfish/blue_jellyfish_animations_arms.tres"),
	preload("res://sources/minigames/jellyfish/pink_jellyfish_animations_arms.tres"),
]
const SCALES: Array[Vector2] = [
	Vector2(1.,1.),
	Vector2(1.25, 1.25)
]
const SCALE_FACTOR: float = 0.2

@export var color: int = Colors.Red:
	set(value):
		color = value
		if animated_sprite_body:
			animated_sprite_body.sprite_frames = ANIMATIONS_BODY[color]
		else:
			Logger.error("Jellyfish: no animated sprite body")
		if animated_sprite_arms:
			animated_sprite_arms.sprite_frames = ANIMATIONS_ARMS[color]
		else:
			Logger.error("Jellyfish: no animated sprite arms")
		scale = SCALES[color] * (1. + randf() * SCALE_FACTOR)
		
		# Handles sprite size
		sprite_control.resized.emit()

var stimulus: Dictionary = {}:
	set(value):
		stimulus = value
		if label:
			if value.has("Grapheme"):
				label.text = value.Grapheme
			else:
				label.text = ""

@onready var sprite_control: SpriteControl = $SpriteControl
@onready var animated_sprite_body: AnimatedSprite2D = %AnimatedSprite2D_Body
@onready var animated_sprite_arms: AnimatedSprite2D = %AnimatedSprite2D_Arms
@onready var label: Label = %AutoSizeLabel.get_node("Label")
@onready var highlight_fx: HighlightFX = %HighlightFX
@onready var right_fx: RightFX = %RightFX
@onready var wrong_fx: WrongFX = %WrongFX
@onready var text_box_sprite_2d: Sprite2D = %TextBox_Sprite2D
@onready var text_box_outline_sprite_2d: Sprite2D = %TextBox_Outline_Sprite2D


func _ready() -> void:
	stimulus = stimulus
	
	var rand: float = randf()
	color = Colors.Red if rand < 0.7 else Colors.Green
	var rand_frame: int = randi_range(0, animated_sprite_body.sprite_frames.get_frame_count("idle") - 1)
	animated_sprite_body.frame = rand_frame
	animated_sprite_arms.frame = rand_frame
	idle()


func is_idle() -> bool:
	return animated_sprite_body.animation == "idle"


func happy() -> void:
	play_animation_by_name("happy")


func idle() -> void:
	play_animation_by_name("idle")


func hit() -> void:
	play_animation_by_name("hit")


func play_animation_by_name(animation_name: String) -> void:
	animated_sprite_body.play(animation_name)
	animated_sprite_arms.play(animation_name)


func highlight() -> void:
	highlight_fx.play()


func stop_highlight() -> void:
	highlight_fx.stop()


func right() -> void:
	label.label_settings = label.label_settings.duplicate()
	label.label_settings.font_color = Color("#009444")
	text_box_sprite_2d.self_modulate = Color("#e6f3e0")
	text_box_outline_sprite_2d.self_modulate = Color("#009344")
	text_box_outline_sprite_2d.visible = true
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


func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_click"):
		pressed.emit(stimulus)


func delete() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0, 2)
	await tween.finished
	queue_free()
