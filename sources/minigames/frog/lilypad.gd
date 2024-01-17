extends Control

signal pressed()
signal disappeared()

@onready var animation_player: = $AnimationPlayer
@onready var button: = $TextureButton
@onready var label: = %Label

var stimulus: Dictionary:
	set = _set_stimulus
var disabled: = false:
	set = _set_disabled
var is_distractor: = true


func disappear() -> void:
	animation_player.play("disappear")


func get_real_size() -> Vector2:
	return button.size


func _set_stimulus(value: Dictionary) -> void:
	stimulus = value
	label.text = stimulus["Grapheme"]


func _set_disabled(value: bool) -> void:
	disabled = value
	
	button.disabled = disabled


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "disappear":
		disappeared.emit()


func _on_texture_button_pressed() -> void:
	pressed.emit()
