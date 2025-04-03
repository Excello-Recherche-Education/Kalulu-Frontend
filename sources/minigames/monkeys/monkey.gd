@tool
extends Node2D

signal pressed()
signal dragged_into_self()

# Namespace
const Coconut: = preload("res://sources/minigames/monkeys/coconut.gd")

@onready var stars: AnimatedSprite2D = $Stars
@onready var coconut: Coconut = $Marker2D/Coconut
@onready var coconut_pivot: Marker2D = $Marker2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var drag_preview_label: Label = $Button/DragPreview/Label
@onready var drag_preview: TextureRect = $Button/DragPreview
@onready var button: Button = $Button
@onready var hit_position: Marker2D = $HitPosition

var locked: = true:
	set(value):
		locked = value or stunned
var stunned: = false:
	set(value):
		stunned = value
		stars.visible = stunned
		locked = true


var stimulus: Dictionary :
	set(value):
		stimulus = value
		if value:
			coconut.text = value.Grapheme
			drag_preview_label.text = value.Grapheme
		else:
			coconut.text = ""
			drag_preview_label.text = ""
		coconut_pivot.hide()


func _ready() -> void:
	(button as Control).set_drag_forwarding(_get_drag_data, _can_drop_data, _drop_data)


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


func hit(p_coconut: Coconut) -> void:
	p_coconut.hide()
	await play("hit")
	animation_player.play("stunned")
	stunned = true


func highlight() -> void:
	coconut.highlight_fx.play()


func stop_highlight() -> void:
	coconut.highlight_fx.stop()


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


func _get_drag_data(at_position: Vector2) -> Variant:
	if locked:
		return null
	
	var _drag_preview: TextureRect = drag_preview.duplicate()
	_drag_preview.show()
	button.set_drag_preview(_drag_preview)
	coconut.hide()
	return {
		monkey = self,
		start_position = button.global_position + at_position,
	}


func _can_drop_data(_at_position: Vector2, _data: Dictionary) -> bool:
	return true


func _drop_data(_at_position: Vector2, data: Dictionary) -> void:
	if data.monkey == self:
		dragged_into_self.emit()


func _on_drag_preview_tree_exiting() -> void:
	coconut.show()
