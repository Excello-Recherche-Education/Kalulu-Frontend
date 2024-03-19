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

var is_playing : bool = false

func _ready() -> void:
	timer.wait_time = particles.lifetime


func play() -> void:
	particles.texture = textures.pick_random()
	particles.amount = randi_range(6, 18)
	particles.restart()


func start() -> void:
	is_playing = true
	_on_timer_timeout()


func stop() -> void:
	is_playing = false
	timer.stop()


func _on_timer_timeout() -> void:
	play()
	timer.start()
