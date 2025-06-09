extends Node2D
class_name Penguin


const SNOWBALL_SCENE: PackedScene = preload("res://sources/minigames/penguin/snowball.tscn")

@onready var snowball_position: Marker2D = $Sprite2D/Snowball
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var audiostream_player: AudioStreamPlayer = $AudioStreamPlayer

var throw_position: Vector2


func _create_snowball() -> void:
	var snowball: Snowball = SNOWBALL_SCENE.instantiate()
	snowball.position = snowball_position.global_position
	snowball.target_position = throw_position - snowball_position.global_position
	audiostream_player.play()
	get_parent().add_child(snowball)

#region Animations

func idle() -> void:
	if randf() < 0.8:
		animation_player.play("idle")
	else:
		animation_player.play("idle2")


func happy() -> void:
	animation_player.play("happy")
	await animation_player.animation_finished


func sad() -> void:
	animation_player.play("sad")
	await animation_player.animation_finished


func throw(pos: Vector2) -> void:
	throw_position = pos
	animation_player.play("throw")
	await animation_player.animation_finished
	idle()

#endregion

#region Connections

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "idle" or anim_name == "idle2":
		idle()

#endregion
