class_name WaterRingFX
extends Control

@export_range(1, 10) var min_particle: int = 1
@export_range(1, 10) var max_particle: int = 4

@onready var particles: GPUParticles2D = $GPUParticles2D


func play() -> void:
	particles.amount = randi_range(min_particle, max_particle)
	particles.restart()
	await particles.finished
