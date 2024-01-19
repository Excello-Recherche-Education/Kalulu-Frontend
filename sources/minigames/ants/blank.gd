extends TextureRect

const images: = [
	"res://assets/minigames/ants/graphics/hole_02.png",
	"res://assets/minigames/ants/graphics/hole_03.png",
	"res://assets/minigames/ants/graphics/hole_04.png",
]

var stimulus: String


func _ready() -> void:
	texture = load(images[randi() % images.size()])
