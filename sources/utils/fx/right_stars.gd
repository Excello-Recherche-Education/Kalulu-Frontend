class_name RightStarsFX
extends Node2D

@onready var gpu_particles_2d: GPUParticles2D = $GPUParticles2D


func play() -> void:
	gpu_particles_2d.set_emitting(true)
