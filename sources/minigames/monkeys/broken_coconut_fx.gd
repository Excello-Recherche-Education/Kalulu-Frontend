extends Control
class_name BrokenCoconutFX

signal finished()


@onready var top_particles: GPUParticles2D = $TopParticles
@onready var shards_particles: GPUParticles2D = $ShardsParticles
@onready var bottom_particles: GPUParticles2D = $BottomParticles
@onready var lines_particles: GPUParticles2D = $LinesParticles

func play() -> void:
	shards_particles.amount = randi_range(4, 10)
	lines_particles.amount = randi_range(1, 3)
	
	lines_particles.restart()
	shards_particles.restart()
	top_particles.restart()
	bottom_particles.restart()
	
	await finished


func _on_shards_particles_finished() -> void:
	finished.emit()
