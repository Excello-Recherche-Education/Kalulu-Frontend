extends Control

@onready var aspect_ratio_container: AspectRatioContainer = $AspectRatioContainer


func _ready() -> void:
	aspect_ratio_container.position = - aspect_ratio_container.size / 2
