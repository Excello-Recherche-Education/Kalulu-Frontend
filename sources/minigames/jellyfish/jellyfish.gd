class_name Jellyfish
extends Control

signal pressed(stimulus: Dictionary)

enum Colors {
	BLUE,
	PINK,
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
	Vector2(1.0, 1.0),
	Vector2(1.25, 1.25),
]
const SCALE_FACTOR: float = 0.2

@export var boss: bool = false:
	set(value):
		boss = value
		if is_node_ready():
			_apply_visuals()

var _color: int = Colors.BLUE
var color: int:
	get: return _color
	set(value):
		_color = value
		if is_node_ready():
			_apply_visuals()
var _stimulus: Dictionary = {}
var stimulus: Dictionary:
	get: return _stimulus
	set(value):
		_stimulus = value
		if is_node_ready():
			_apply_label()

@onready var sprite_control: SpriteControl = $SpriteControl
@onready var animated_sprite_body: AnimatedSprite2D = %AnimatedSprite2D_Body
@onready var animated_sprite_arms: AnimatedSprite2D = %AnimatedSprite2D_Arms
@onready var label: Label = %AutoSizeLabel.get_node("Label")
@onready var highlight_fx: HighlightFX = %HighlightFX
@onready var right_fx: RightFX = %RightFX
@onready var right_stars: RightStarsFX = %Right_Stars
@onready var wrong_fx: WrongFX = %WrongFX
@onready var text_box_sprite_2d: Sprite2D = %TextBox_Sprite2D


func _ready() -> void:
	_apply_visuals()
	_apply_label()

	if boss:
		return

	var rand: float = randf()
	color = Colors.BLUE if rand < 0.7 else Colors.PINK
	var rand_frame: int = randi_range(0, animated_sprite_body.sprite_frames.get_frame_count("idle") - 1)
	animated_sprite_body.frame = rand_frame
	animated_sprite_arms.frame = rand_frame
	idle()


func _apply_visuals() -> void:
	if boss:
		animated_sprite_body.sprite_frames = ANIMATIONS_BODY[Colors.PINK]
		animated_sprite_arms.hide()
		return
	else:
		animated_sprite_arms.show()

	animated_sprite_body.sprite_frames = ANIMATIONS_BODY[_color]
	animated_sprite_arms.sprite_frames = ANIMATIONS_ARMS[_color]
	scale = SCALES[_color] * (1.0 + randf() * SCALE_FACTOR)
	sprite_control.resized.emit()


func _apply_label() -> void:
	label.text = str(_stimulus.get("Grapheme", ""))


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
	label.label_settings.font_color = Minigame.LABEL_COLOR_NEUTRAL
	text_box_sprite_2d.self_modulate = Minigame.LABEL_COLOR_WIN
	right_fx.play()
	right_stars.play()
	await right_fx.finished


func wrong() -> void:
	label.label_settings = label.label_settings.duplicate()
	label.label_settings.font_color = Minigame.LABEL_COLOR_NEUTRAL
	text_box_sprite_2d.self_modulate = Minigame.LABEL_COLOR_LOSE
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


func idle_boss() -> void:
	text_box_sprite_2d.hide()
	color = Colors.PINK
	scale = Vector2(0.45, 0.45)
	animated_sprite_body.stop()
	animated_sprite_arms.stop()


func victory_boss() -> void:
	animated_sprite_arms.play("happy")
