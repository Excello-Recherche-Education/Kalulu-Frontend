@tool
extends Control
class_name SandVFX

const textures: Array[Resource] = [
	preload("res://assets/vfx/Sand_01.png"),
	preload("res://assets/vfx/Sand_02.png"),
	preload("res://assets/vfx/Sand_03.png"),
	preload("res://assets/vfx/Sand_04.png"),
	preload("res://assets/vfx/Sand_05.png"),
	preload("res://assets/vfx/Sand_06.png"),
	preload("res://assets/vfx/Sand_07.png")
]

@onready var particles : GPUParticles2D = $Particles
@onready var timer : Timer = $Timer


func _ready():
	timer.wait_time = particles.lifetime


func play():
	particles.texture = textures.pick_random()
	particles.amount = randi_range(6, 18)
	particles.restart()


func start():
	_on_timer_timeout()


func stop():
	timer.stop()


func _on_timer_timeout():
	play()
	timer.start()
