class_name RightStarsFX
extends Node2D

@onready var particles: CPUParticles2D = $Particles


func play() -> void:
	particles.set_emitting(true)


func replay() -> void:
	particles.restart()
