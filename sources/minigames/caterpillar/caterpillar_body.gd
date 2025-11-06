class_name CaterpillarBody
extends Node2D

var gp: Dictionary = {}:
	set(value):
		gp = value
		if gp.has("Grapheme"):
			label.text = gp.Grapheme
			resize_body()
		else:
			label.text = ""
			resize_body()
var margin: float = 1.0
var base_width: int = 10 # Minimal width of the body

# @onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var label: Label = %Label
@onready var right_FX: RightFX = %RightFX
@onready var body_left: Sprite2D = %Sprite2D_Body_Left
@onready var body_center: TextureRect = %TextureRect_Body_Center
@onready var body_right: Sprite2D = %Sprite2D_Body_Right
@onready var caterpillar_leg_back: AnimatedSprite2D = $Position/AnimatedSprite2D_Leg_Back
@onready var caterpillar_leg_front: AnimatedSprite2D = $Position/AnimatedSprite2D_Leg_Front


func idle() -> void:
	caterpillar_leg_front.pause()
	caterpillar_leg_back.pause()


func walk() -> void:
	caterpillar_leg_front.play()
	caterpillar_leg_back.play()


func right() -> void:
	right_FX.play()
	await right_FX.finished


func get_width() -> float:
	label.reset_size()
	var text_w: float = label.size.x
	var end_width: float = max(float(base_width), text_w + float(margin) * 2.0)
	return end_width


func resize_body() -> void:
	var letters_count: int = label.text.length()
	if letters_count <= 0:
		return
	
	var end_width: float = get_width()
	var center_h: float = float(body_center.texture.get_height())
	
	var tween: Tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	
	var apply_width: Callable = func(width: float) -> void:
		body_center.size = Vector2(width, center_h)
		_update_body_layout()
	
	var start_width: float = body_center.size.x
	tween.tween_method(apply_width, start_width, end_width, 0.3)
	
	await tween.finished
	
	caterpillar_leg_back.global_position = Vector2(body_center.global_position.x + end_width/2, caterpillar_leg_back.global_position.y)
	caterpillar_leg_front.global_position = Vector2(body_center.global_position.x + end_width/2, caterpillar_leg_front.global_position.y)


func _update_body_layout() -> void:
	var left_width: float = float(body_left.texture.get_width())
	var center_height: float = float(body_center.texture.get_height())
	var current_center_w: float = body_center.size.x
	var label_width: float = label.size.x
	var label_height: float = label.size.y
	
	body_left.position = Vector2(0.0, 0.0)
	body_center.position = Vector2(left_width, 0.0)
	body_right.position = Vector2(left_width + current_center_w, 0.0)
	
	label.position = Vector2(
		left_width + margin + (current_center_w - 2.0 * margin) * 0.5 - label_width * 0.5,
		center_height * 0.5 - label_height * 0.5
	)
