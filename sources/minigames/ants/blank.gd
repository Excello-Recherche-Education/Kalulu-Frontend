extends TextureRect

class_name Blank

const images: Array[String] = [
	"res://assets/minigames/ants/graphics/hole_02.png",
	"res://assets/minigames/ants/graphics/hole_03.png",
	"res://assets/minigames/ants/graphics/hole_04.png",
]

var stimulus: String

@onready var area: Area2D = $Area2D


func _ready() -> void:
	texture = load(images[randi() % images.size()])


func set_monitorable(p_monitorable: bool) -> void:
	area.monitorable = p_monitorable
