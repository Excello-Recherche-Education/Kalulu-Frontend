class_name Blank
extends TextureRect

var stimulus: String

@onready var area: Area2D = $Area2D


func set_monitorable(p_monitorable: bool) -> void:
	area.monitorable = p_monitorable
