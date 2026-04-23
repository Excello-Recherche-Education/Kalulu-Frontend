class_name Coconut
extends Node2D

var text: String:
	set(value):
		text = value
		if label:
			label.text = text
# External, shared across all coconuts in the minigame. Set by the minigame before play.
var broken_fx: BrokenCoconutFX

@onready var highlight_fx: HighlightFX = $HighlightFX
@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label


func _ready() -> void:
	label.label_settings.font_color = Minigame.LABEL_COLOR_NEUTRAL


func highlight() -> void:
	highlight_fx.play()


func explode() -> void:
	Log.trace("Coconut: Explode")
	highlight_fx.stop()
	sprite.hide()
	label.hide()
	if broken_fx:
		broken_fx.global_position = global_position
		await broken_fx.play()
	queue_free()
