@tool
extends Node2D

signal pressed()
signal dragged_into_self()
signal dragged_into(vector)

const instance_scene: = "res://sources/minigames/monkeys/monkey.tscn"

@onready var coconut: = $Marker2D/Coconut
@onready var animation_player: = $AnimationPlayer
@onready var drag_preview_label: = $Button/DragPreview/Label
@onready var drag_preview: = $Button/DragPreview
@onready var button: = $Button


var stimulus: Dictionary :
	set(value):
		stimulus = value
		coconut.text = value.Grapheme
		drag_preview_label.text = value.Grapheme


static func instantiate():
	return load(instance_scene).instantiate()


func _ready() -> void:
	button.set_drag_forwarding(_get_drag_data, _can_drop_data, _drop_data)


func _on_button_pressed() -> void:
	pressed.emit()


func talk() -> void:
	animation_player.play("talk")
	await animation_player.animation_finished
	animation_player.play_backwards("talk")
	await animation_player.animation_finished
	animation_player.play("idle")


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "idle":
		if randf() < 0.25:
			animation_player.play("idle_blink")
		else:
			animation_player.play("idle")
	elif anim_name == "idle_blink":
		animation_player.play("idle")


func _on_button_dragging() -> void:
	coconut.hide()


func _get_drag_data(at_position: Vector2):
	var _drag_preview = drag_preview.duplicate()
	_drag_preview.show()
	button.set_drag_preview(_drag_preview)
	print(at_position)
	coconut.hide()
	return {
		object = self,
		start_position = button.global_position + at_position,
	}


func _can_drop_data(_at_position: Vector2, _data) -> bool:
	return true


func _drop_data(at_position: Vector2, data) -> void:
	if data.object == self:
		dragged_into_self.emit()
	else:
		dragged_into.emit(button.global_position + at_position - data.start_position)


func _on_drag_preview_tree_exiting() -> void:
	coconut.show()
