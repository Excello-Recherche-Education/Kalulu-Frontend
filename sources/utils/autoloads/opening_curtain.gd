@tool
class_name OpeningCurtainClass
extends CanvasLayer

signal animation_finished(animation_name: StringName)

var is_closed: bool = false

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func open() -> void:
	Log.trace("OpeningCurtain: Open requested")
	if is_closed:
		is_closed = false
		animation_player.play("open")
		await animation_player.animation_finished
		Log.trace("OpeningCurtain: Open animation finished")
	else:
		Log.trace("OpeningCurtain: Open ignored because curtain is already open")


func close() -> void:
	Log.trace("OpeningCurtain: Close requested")
	if not is_closed:
		is_closed = true
		animation_player.play("close")
		await animation_player.animation_finished
		Log.trace("OpeningCurtain: Close animation finished")
	else:
		Log.trace("OpeningCurtain: Close ignored because curtain is already closed")


func _on_animation_player_animation_finished(animation_name: StringName) -> void:
	Log.trace("OpeningCurtain: Animation %s completed, emitting signal" % animation_name)
	animation_finished.emit(animation_name)
