extends Node2D
class_name Crab

signal crab_hit(stimulus: Dictionary)

@onready var animation_player: = $AnimationPlayer
@onready var label: = $Label
@onready var button: = $Button
@onready var right_fx: = $RightFX
@onready var wrong_fx: = $WrongFX


var stimulus: Dictionary:
	set = _set_stimulus


func _ready() -> void:
	set_button_active(false)


func _process(_delta: float) -> void:
#	right_fx.global_rotation = 0.0
#	wrong_fx.global_rotation = 0.0
	pass


func set_button_active(active: bool) -> void:
	button.disabled = not active


func is_button_pressed() -> bool:
	await button.pressed
	return true


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
	animation_player.play("hit")


func _on_animation_player_animation_finished(animation_name: StringName) -> void:
	var idles: = ["idle1", "idle2"]
	if animation_name in idles:
		var r: = randi() % idles.size()
		animation_player.play(idles[r])
	elif animation_name == "hit":
		animation_player.play("hurt")
