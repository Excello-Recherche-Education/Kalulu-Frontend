@tool
extends Node2D

signal pressed()
signal dragged_into_self()
signal dragged_into(vector, monkey)

const instance_scene: = "res://sources/minigames/monkeys/monkey.tscn"

@onready var coconut: = $Marker2D/Coconut
@onready var animation_player: = $AnimationPlayer
@onready var drag_preview_label: = $Button/DragPreview/Label
@onready var drag_preview: = $Button/DragPreview
@onready var button: = $Button
@onready var hit_position: = $HitPosition

var locked: = true:
	set(value):
		locked = value or stunned
var stunned: = false:
	set(value):
		stunned = value
		locked = true


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
	if locked:
		return
	
	pressed.emit()


func play(animation: String) -> void:
	animation_player.play(animation)
	await animation_player.animation_finished
	animation_player.play("idle")


func talk() -> void:
	animation_player.play("talk")
	await animation_player.animation_finished
	animation_player.play_backwards("talk")
	await animation_player.animation_finished
	animation_player.play("idle")


func hit(p_coconut: Node2D) -> void:
	p_coconut.hide()
	await play("hit")
	animation_player.play("stunned")
	stunned = true


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
	if locked:
		return null
	
	var _drag_preview = drag_preview.duplicate()
	_drag_preview.show()
	button.set_drag_preview(_drag_preview)
	coconut.hide()
	return {
		monkey = self,
		start_position = button.global_position + at_position,
	}


func _can_drop_data(_at_position: Vector2, _data) -> bool:
	return true


func _drop_data(at_position: Vector2, data) -> void:
	if data.monkey == self:
		dragged_into_self.emit()
	else:
		dragged_into.emit(button.global_position + at_position - data.start_position, data.monkey)


func _on_drag_preview_tree_exiting() -> void:
	coconut.show()
