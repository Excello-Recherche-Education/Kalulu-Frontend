class_name Coconut
extends Node2D

var text: String:
	set(value):
		text = value
		if label:
			label.text = text

@onready var highlight_fx: HighlightFX = $HighlightFX
@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label
@onready var broken_coconut_fx: BrokenCoconutFX = $BrokenCoconutFX


func _ready() -> void:
	label.label_settings.font_color = Minigame.LABEL_COLOR_NEUTRAL


func highlight() -> void:
	highlight_fx.play()


func explode() -> void:
	Log.trace("Coconut: Explode")
	highlight_fx.stop()
	sprite.hide()
	label.hide()
	
	await broken_coconut_fx.play()
	
	queue_free()
