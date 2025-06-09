extends Control
class_name Lilypad

signal pressed()
signal disappeared()

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var button: TextureButton = $TextureButton
@onready var label: Label = %Label
@onready var highlight_fx: HighlightFX = %HighlightFX
@onready var right_fx: RightFX = %RightFX
@onready var wrong_fx: WrongFX = %WrongFX

var stimulus: Dictionary = {}:
	set = _set_stimulus
var disabled: bool = false:
	set = _set_disabled
var is_distractor: bool = true
var top_to_bottom: bool = false


func disappear() -> void:
	button.disabled = true
	animation_player.play("disappear")


func highlight() -> void:
	if not is_distractor:
		highlight_fx.play()


func right() -> void:
	right_fx.play()
	await right_fx.finished


func wrong() -> void:
	wrong_fx.play()
	await wrong_fx.finished


func stop_highlight() -> void:
	if not is_distractor:
		highlight_fx.stop()


func _set_stimulus(value: Dictionary) -> void:
	stimulus = value
	if stimulus:
		label.text = stimulus["Grapheme"]
	else:
		label.text = ""


func _set_disabled(value: bool) -> void:
	disabled = value
	
	button.disabled = disabled
	label.visible = !disabled


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "disappear":
		disappeared.emit()


func _on_texture_button_pressed() -> void:
	pressed.emit()


func _on_top_visible_on_screen_notifier_screen_exited() -> void:
	if top_to_bottom:
		disappear()


func _on_bottom_visible_on_screen_notifier_screen_exited() -> void:
	if not top_to_bottom:
		disappear()
