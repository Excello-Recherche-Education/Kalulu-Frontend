class_name Snowball
extends Path2D

var target_position: Vector2

@onready var path_follow: PathFollow2D = $PathFollow2D
@onready var sprite: Sprite2D = $PathFollow2D/Sprite2D
@onready var particles: GPUParticles2D = $PathFollow2D/Particles


func _ready() -> void:
	curve.set_point_position(1, target_position)
	var tween: Tween = create_tween()
	tween.tween_property(path_follow, "progress_ratio", 1, .5)
	await tween.finished
	sprite.visible = false
	# Particles
	particles.restart()
	await particles.finished
	queue_free()
