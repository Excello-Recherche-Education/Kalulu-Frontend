@tool
class_name Monkey
extends Node2D

signal pressed()
signal dragged_into_self()

var locked: bool = true:
	set(value):
		locked = value or stunned
var stunned: bool = false:
	set(value):
		stunned = value
		stars.set_visible(stunned)
		locked = true
var stimulus: Dictionary = {}:
	set(value):
		stimulus = value
		if value:
			coconut.text = value.Grapheme
			drag_preview_label.text = value.Grapheme
		else:
			coconut.text = ""
			drag_preview_label.text = ""
var blink_counter: int = 0
var blink_delay: int = 3
var blink_random: int = 3
var grab_animation_name: String = "grab"
var grab_time: float = 1.0

@onready var stars: AnimatedSprite2D = $Stars
@onready var coconut: Coconut = $Coconut
@onready var drag_preview_label: Label = $Button/DragPreview/Label
@onready var drag_preview: TextureRect = $Button/DragPreview
@onready var button: Button = $Button
@onready var hit_position: Marker2D = $HitPosition
@onready var grab_position: Marker2D = $GrabPosition
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	(button as Control).set_drag_forwarding(_get_drag_data, _can_drop_data, _drop_data)
	grab_time = Utils.get_animation_duration(animated_sprite_2d, grab_animation_name)


func _on_button_pressed() -> void:
	if locked:
		return
	pressed.emit()


func play(animation: String) -> void:
	Log.trace("Monkey: Play animation %s" % animation)
	animated_sprite_2d.play(animation)
	await animated_sprite_2d.animation_finished
	if animation == grab_animation_name:
		var original_position: Vector2 = coconut.global_position
		coconut.apply_scale(Vector2(0.01, 0.01))
		coconut.show()
		coconut.global_position = grab_position.global_position
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(coconut, "global_scale", Vector2(1, 1), grab_time)
		tween.tween_property(coconut, "global_position", original_position, grab_time)
		animated_sprite_2d.play_backwards(animation)
		await animated_sprite_2d.animation_finished
	animated_sprite_2d.play("idle")


func talk() -> void:
	Log.trace("Monkey: Talk")
	animated_sprite_2d.play("talk")
	await animated_sprite_2d.animation_finished
	animated_sprite_2d.play_backwards("talk")
	await animated_sprite_2d.animation_finished
	animated_sprite_2d.play("idle")


func hit(p_coconut: Coconut) -> void:
	Log.trace("Monkey: Hit")
	p_coconut.explode()
	await play("hit")
	animated_sprite_2d.play("stunned")
	stunned = true


func highlight() -> void:
	coconut.highlight_fx.play()


func stop_highlight() -> void:
	coconut.highlight_fx.stop()


func _on_animated_sprite_2d_animation_finished() -> void:
	match animated_sprite_2d.animation:
		"idle":
			blink_counter -= 1
			if blink_counter <= 0:
				blink_counter = blink_delay + randi_range(0, blink_random)
				animated_sprite_2d.play("idle_blink")
			else:
				animated_sprite_2d.play("idle")
		"idle_blink":
			animated_sprite_2d.play("idle")


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
