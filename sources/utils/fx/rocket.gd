extends Path2D

@export var spread_angle := PI/8.0
@export var segments := 5

@onready var path_follow: = $PathFollow2D

@onready var traveling_timer: = $TravelingTimer
@onready var explosion_timer: = $ExplosionTimer

@onready var rocket: = $PathFollow2D/Rocket
@onready var explosion_particles: = $PathFollow2D/ExplosionParticles

@onready var firework_audio_player: = $FireworkAudioPlayer
@onready var blast_audio_player: = $BlastAudioPlayer

const firework_sounds: = [
	preload("res://assets/sfx/fireworks_1.mp3"),
	preload("res://assets/sfx/fireworks_2.mp3"),
	preload("res://assets/sfx/fireworks_3.mp3"),
	preload("res://assets/sfx/fireworks_4.mp3"),
	preload("res://assets/sfx/fireworks_5.mp3"),
]

const blast_sounds: = [
	preload("res://assets/sfx/blast_1.mp3"),
	preload("res://assets/sfx/blast_2.mp3"),
	preload("res://assets/sfx/blast_3.mp3"),
	preload("res://assets/sfx/blast_4.mp3"),
	preload("res://assets/sfx/blast_5.mp3"),
]

const colors: = [
	Color(0.427, 0.796, 1),
	Color(0.976, 0.322, 0.392),
	Color(1, 0.396, 0.753),
	Color(0.78, 0.282, 0.902),
	Color(0.357, 0.604, 0.631),
	Color(1, 0.659, 0.137),
	Color(0.216, 0.757, 0.341),
]

var ind_color: = 0


func _ready() -> void:
	ind_color = randi() % int(rocket.texture.get_size().x / rocket.region_rect.size.x)
	rocket.region_rect.position.x = ind_color * rocket.region_rect.size.x
	
	firework_audio_player.stream = firework_sounds[randi() % firework_sounds.size()]
	blast_audio_player.stream = blast_sounds[randi() % blast_sounds.size()]


func start(start: Vector2, end: Vector2) -> void:
	explosion_particles.modulate = colors[ind_color]
	
	create_path(start, end)
	
	var travel_time: = randf_range(0.5, 1.0)
	traveling_timer.start(travel_time)
	
	path_follow.progress_ratio = 0.0
	var tween: = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)
	var _a: = tween.tween_property(path_follow, "progress_ratio", 1.0, travel_time)
	
	firework_audio_player.play()


func create_path(start: Vector2, end: Vector2) -> void:
	var current := start
	var segment_length := start.distance_to(end) / segments
	
	var general_direction: = (end - start).normalized()
	
	curve.add_point(start, -segment_length * general_direction / 2.0, segment_length * general_direction / 2.0)
	for _segment in range(segments):
		var rotation := randf_range(-spread_angle / 2, spread_angle / 2)
		var new := current + (current.direction_to(end) * segment_length).rotated(rotation)
		var direction: = (new - current).normalized()
		curve.add_point(new, -segment_length * direction / 2.0, segment_length * direction / 2.0)
		current = new


func _on_TravelingTimer_timeout() -> void:
	rocket.visible = false
	explosion_timer.start()
	blast_audio_player.play()
	for particles in explosion_particles.get_children():
		particles.emitting = true


func _on_ExplosionTimer_timeout() -> void:
	queue_free()
