extends Node2D
class_name Crab

signal crab_hit(stimulus: Dictionary)

@onready var animation_player: = $AnimationPlayer
@onready var label: = $Label
@onready var button: = $Button

var stimulus: Dictionary


func _ready() -> void:
	set_button_active(false)


func set_button_active(active: bool) -> void:
	button.disabled = not active


func set_stimulus(p_stimulus: Dictionary) -> void:
	stimulus = p_stimulus
	
	label.text = stimulus["Grapheme"]


func _on_button_pressed() -> void:
	emit_signal("crab_hit", stimulus)
	animation_player.play("hit")


func _on_animation_player_animation_finished(animation_name: StringName) -> void:
	var idles: = ["idle1", "idle2"]
	if animation_name in idles:
		var r: = randi() % idles.size()
		animation_player.play(idles[r])
	if animation_name == "hit":
		animation_player.play("hurt")
