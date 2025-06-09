extends TextureRect

class_name Blank

const IMAGES: Array[String] = [
	"res://assets/minigames/ants/graphics/hole_02.png",
	"res://assets/minigames/ants/graphics/hole_03.png",
	"res://assets/minigames/ants/graphics/hole_04.png",
]

var stimulus: String

@onready var area: Area2D = $Area2D


func _ready() -> void:
	texture = load(IMAGES[randi() % IMAGES.size()])


func set_monitorable(p_monitorable: bool) -> void:
	area.monitorable = p_monitorable
