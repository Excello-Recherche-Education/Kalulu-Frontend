extends Node2D

signal pressed(gp: Dictionary)

@onready var snowball: Marker2D = $Sprite2D/Snowball
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var label: Label = $Label
@onready var button: Button = $Button

var gp: Dictionary:
	set(value):
		gp = value
		if gp:
			label.text = gp.Grapheme
			button.disabled = false
			snowball.visible = false
		else:
			label.text = ""
			button.disabled = true
			snowball.visible = true


func set_button_enabled(is_enabled: bool) -> void:
	button.disabled = !is_enabled


func idle():
	if randf() < 0.8:
		animation_player.play("idle")
	else:
		animation_player.play("idle2")


func throw() -> void:
	animation_player.play("throw")
	await animation_player.animation_finished
	idle()


func _create_snowball() -> void:
	print("SNOWBALL INC !")


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "idle" or anim_name == "idle2":
		idle()


func _on_button_pressed() -> void:
	pressed.emit(gp)
