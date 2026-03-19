class_name BrokenCoconutFX
extends Control

signal finished()

@onready var top_particles: GPUParticles2D = $TopParticles
@onready var shards_particles: GPUParticles2D = $ShardsParticles
@onready var bottom_particles: GPUParticles2D = $BottomParticles
@onready var lines_particles: GPUParticles2D = $LinesParticles


func warm_up() -> void:
	modulate.a = 0
	top_particles.emitting = true
	shards_particles.emitting = true
	bottom_particles.emitting = true
	lines_particles.emitting = true
	await get_tree().process_frame
	await get_tree().process_frame
	top_particles.emitting = false
	shards_particles.emitting = false
	bottom_particles.emitting = false
	lines_particles.emitting = false
	modulate.a = 1


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
