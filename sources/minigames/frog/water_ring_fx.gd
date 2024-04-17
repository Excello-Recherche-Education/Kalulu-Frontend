extends Control
class_name WaterRingFX

@export_range(1, 10) var min: int = 1
@export_range(1, 10) var max: int = 4

@onready var particles: GPUParticles2D = $GPUParticles2D

func play() -> void:
	particles.amount = randi_range(min, max)
	particles.restart()
