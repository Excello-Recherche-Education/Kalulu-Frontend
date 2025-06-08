extends Path2D
class_name Rocket

@export var spread_angle: float = PI/8.0
@export var segments: int = 5

@onready var path_follow: PathFollow2D = $PathFollow2D

@onready var traveling_timer: Timer = $TravelingTimer
@onready var explosion_timer: Timer = $ExplosionTimer

@onready var rocket: Sprite2D = $PathFollow2D/Rocket
@onready var explosion_particles: Node2D = $PathFollow2D/ExplosionParticles

@onready var firework_audio_player: AudioStreamPlayer2D = $FireworkAudioPlayer
@onready var blast_audio_player: AudioStreamPlayer2D = $BlastAudioPlayer

const firework_sounds: Array[AudioStreamMP3] = [
	preload("res://assets/sfx/fireworks_1.mp3"),
	preload("res://assets/sfx/fireworks_2.mp3"),
	preload("res://assets/sfx/fireworks_3.mp3"),
	preload("res://assets/sfx/fireworks_4.mp3"),
	preload("res://assets/sfx/fireworks_5.mp3"),
]

const blast_sounds: Array[AudioStreamMP3] = [
	preload("res://assets/sfx/blast_1.mp3"),
	preload("res://assets/sfx/blast_2.mp3"),
	preload("res://assets/sfx/blast_3.mp3"),
	preload("res://assets/sfx/blast_4.mp3"),
	preload("res://assets/sfx/blast_5.mp3"),
]

const colors: Array[Color] = [
	Color(0.427, 0.796, 1),
	Color(0.976, 0.322, 0.392),
	Color(1, 0.396, 0.753),
	Color(0.78, 0.282, 0.902),
	Color(0.357, 0.604, 0.631),
	Color(1, 0.659, 0.137),
	Color(0.216, 0.757, 0.341),
]

var ind_color: int = 0


func _ready() -> void:
	ind_color = randi() % int(rocket.texture.get_size().x / rocket.region_rect.size.x)
	rocket.region_rect.position.x = ind_color * rocket.region_rect.size.x
	
	firework_audio_player.stream = firework_sounds[randi() % firework_sounds.size()]
	blast_audio_player.stream = blast_sounds[randi() % blast_sounds.size()]


func start(start_point: Vector2, end_point: Vector2) -> void:
	explosion_particles.modulate = colors[ind_color]
	
	create_path(start_point, end_point)
	
	var travel_time: float = randf_range(0.5, 1.0)
	traveling_timer.start(travel_time)
	
	path_follow.progress_ratio = 0.0
	var tween: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CIRC)
	var _a: PropertyTweener = tween.tween_property(path_follow, "progress_ratio", 1.0, travel_time)
	
	firework_audio_player.play()


func create_path(start_point: Vector2, end_point: Vector2) -> void:
	var current: Vector2 = start_point
	var segment_length: float = start_point.distance_to(end_point) / segments
	
	var general_direction: Vector2 = (end_point - start_point).normalized()
	
	curve.add_point(start_point, -segment_length * general_direction / 2.0, segment_length * general_direction / 2.0)
	for _segment: int in range(segments):
		var angle: float = randf_range(-spread_angle / 2, spread_angle / 2)
		var new: Vector2 = current + (current.direction_to(end_point) * segment_length).rotated(angle)
		var direction: Vector2 = (new - current).normalized()
		curve.add_point(new, -segment_length * direction / 2.0, segment_length * direction / 2.0)
		current = new


func _on_TravelingTimer_timeout() -> void:
	rocket.visible = false
	explosion_timer.start()
	blast_audio_player.play()
	for particles: GPUParticles2D in explosion_particles.get_children():
		particles.emitting = true


func _on_ExplosionTimer_timeout() -> void:
	queue_free()
