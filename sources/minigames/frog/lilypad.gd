class_name Lilypad
extends Control

signal pressed()
signal disappeared()

var stimulus: Dictionary = {}:
	set = _set_stimulus
var disabled: bool = false:
	set = _set_disabled
var is_distractor: bool = true
var top_to_bottom: bool = false

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var button: TextureButton = $TextureButton
@onready var label: Label = $TextureButton/TextBox_Sprite2D/PercentMarginContainer/AspectRatioContainer/AutoSizeLabel/Label
@onready var highlight_fx: HighlightFX = %HighlightFX
@onready var right_fx: RightFX = %RightFX
@onready var wrong_fx: WrongFX = %WrongFX
@onready var text_box_sprite_2d: Sprite2D = %TextBox_Sprite2D


func disappear() -> void:
	button.set_disabled(true)
	var tween: Tween = create_tween()
	tween.parallel().tween_property(
		label,
		"self_modulate:a",
		0.0,
		0.5
	)
	tween.parallel().tween_property(
		text_box_sprite_2d,
		"self_modulate:a",
		0.0,
		0.5
	)
	animation_player.play("disappear")


func highlight() -> void:
	if not is_distractor:
		highlight_fx.play()


func right() -> void:
	var previous_settings: LabelSettings = label.label_settings
	var previous_background_color: Color = text_box_sprite_2d.self_modulate
	label.label_settings = label.label_settings.duplicate()
	label.label_settings.font_color = Minigame.LABEL_COLOR_NEUTRAL
	text_box_sprite_2d.self_modulate = Minigame.LABEL_COLOR_WIN
	right_fx.play()
	await right_fx.finished
	label.label_settings = previous_settings
	text_box_sprite_2d.self_modulate = previous_background_color


func wrong() -> void:
	label.label_settings = label.label_settings.duplicate()
	label.label_settings.font_color = Minigame.LABEL_COLOR_NEUTRAL
	text_box_sprite_2d.self_modulate = Minigame.LABEL_COLOR_LOSE
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
	button.set_disabled(disabled)
	label.set_visible(!disabled)


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
