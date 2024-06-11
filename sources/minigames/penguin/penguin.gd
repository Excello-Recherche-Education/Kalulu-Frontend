extends Node2D

signal pressed(pos: Vector2)

# Namespace
const Snowball: = preload("res://sources/minigames/penguin/snowball.gd")

const snowball_scene: PackedScene = preload("res://sources/minigames/penguin/snowball.tscn")

@onready var snowball_position: Marker2D = $Sprite2D/Snowball
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var label: Label = $Label
@onready var button: Button = $Button

var throw_position: Vector2

var gp: Dictionary:
	set(value):
		gp = value
		if gp:
			label.text = gp.Grapheme
			button.disabled = false
			snowball_position.visible = false
		else:
			label.text = ""
			button.disabled = true
			snowball_position.visible = true


func set_button_enabled(is_enabled: bool) -> void:
	button.disabled = !is_enabled


func idle():
	if randf() < 0.8:
		animation_player.play("idle")
	else:
		animation_player.play("idle2")


func throw(pos: Vector2) -> void:
	throw_position = pos
	animation_player.play("throw")
	await animation_player.animation_finished
	idle()


func _create_snowball() -> void:
	var snowball: Snowball = snowball_scene.instantiate()
	snowball.position = snowball_position.global_position
	snowball.target_position = throw_position - snowball_position.global_position
	
	get_parent().add_child(snowball)
	
	print("SNOWBALL INC !")


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "idle" or anim_name == "idle2":
		idle()


func _on_button_pressed() -> void:
	pressed.emit(get_global_mouse_position())
