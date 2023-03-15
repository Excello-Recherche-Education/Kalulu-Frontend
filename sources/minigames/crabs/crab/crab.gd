extends Node2D

const instance_scene: = "res://sources/minigames/crabs/crab/crab.tscn"

signal crab_hit(stimulus: Dictionary)

@onready var animation_player: = $AnimationPlayer
@onready var label: = $Label
@onready var button: = $Button

var stimulus: Dictionary:
	set(p_stimulus):
		stimulus = p_stimulus
		label.text = stimulus["Grapheme"]


func _ready() -> void:
	set_button_active(false)


func set_button_active(active: bool) -> void:
	button.disabled = not active


func _on_button_pressed() -> void:
	crab_hit.emit(stimulus)
	animation_player.play("hit")


func is_button_pressed() -> bool:
	await button.pressed
	return true


func _on_animation_player_animation_finished(animation_name: StringName) -> void:
	var idles: = ["idle1", "idle2"]
	if animation_name in idles:
		var r: = randi() % idles.size()
		animation_player.play(idles[r])
	elif animation_name == "hit":
		animation_player.play("hurt")


static func instantiate() -> Node2D:
	return load(instance_scene).instantiate()
