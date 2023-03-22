extends Control

signal disappeared

@export var lilypad_crossing_time: = 5.0
@export var number_of_lilypad: = 25.0

const lilypad_class: = preload("res://sources/minigames/frog/lilypad/lilypad.tscn")

@onready var spawn_timer: = $SpawnTimer

var is_cleared: = false
var stimuli: = []
var are_they_distractors: = []
var ready_to_spawn: = false
var despawned_lilypads: = []
var spawned_lilypads: = []
var tweens: Array[Tween] = []
var top_point: = Vector2.ZERO
var bottom_point: = Vector2.ZERO
var center_point: = Vector2.ZERO
var lilypad_scale: = 1.0
var top_to_bottom: = true


func _ready() -> void:
	for i in range(number_of_lilypad):
		var lilypad: = lilypad_class.instantiate()
		add_child(lilypad)
		despawned_lilypads.append(lilypad)
		
		lilypad.position = top_point
		
		lilypad.frog_land.connect(_on_lilypad_frog_land.bind(lilypad))
		lilypad.frog_fall.connect(_on_lilypad_frog_fall.bind(lilypad))


func _process(_delta: float) -> void:
	if ready_to_spawn and stimuli.size() != 0:
		var index: = randi() % stimuli.size()
		_spawn_lilypad(stimuli[index], are_they_distractors[index])


func disappear() -> void:
	if spawned_lilypads.size() != 0:
		for i in range(1, spawned_lilypads.size()):
			_despawn_lilypad(spawned_lilypads[i])
		await _despawn_lilypad(spawned_lilypads[0])
	
	disappeared.emit()


func restart() -> void:
	_reset_tweens()
	
	for lilypad in spawned_lilypads:
		_despawn_lilypad(lilypad)
	
	ready_to_spawn = true
	is_cleared = false


func _spawn_lilypad(stimulus: Dictionary, is_distractor: bool) -> void:
	if despawned_lilypads.size() != 0:
		var lilypad: Node2D = despawned_lilypads.pop_front()
		spawned_lilypads.append(lilypad)
		
		var start: = Vector2.ZERO
		var end: = Vector2.ZERO
		if top_to_bottom:
			start = top_point
			end = bottom_point
		else:
			start = bottom_point
			end = top_point
		
		lilypad.scale = Vector2(lilypad_scale, lilypad_scale)
		lilypad.stimulus = stimulus
		lilypad.is_distractor = is_distractor
		lilypad.position = start
		lilypad.appear()
		
		var tween: = create_tween()
		tween.tween_property(lilypad, "position", end, lilypad_crossing_time)
		tween.finished.connect(_on_lilypad_traveling_ended.bind(lilypad, tween))
		tweens.append(tween)
		
		ready_to_spawn = false
		spawn_timer.start(randf_range(0.5, 1.5))


func _despawn_lilypad(lilypad: Node2D) -> void:
	if lilypad in spawned_lilypads:
		await lilypad.disappear()
		despawned_lilypads.append(lilypad)
		spawned_lilypads.erase(lilypad)
		lilypad.position = top_point


func _reset_tweens() -> void:
	for tween in tweens:
		tween.pause()
		tween.kill()
	tweens = []


func _on_lilypad_frog_land(lilypad: Node2D) -> void:
	_reset_tweens()
	
	for other_lilypad in spawned_lilypads:
		if other_lilypad != lilypad:
			_despawn_lilypad(other_lilypad)
	
	var tween: = create_tween()
	tween.tween_property(lilypad, "position", center_point, 0.5)
	tweens.append(tween)
	
	spawn_timer.stop()
	ready_to_spawn = false
	is_cleared = true


func _on_lilypad_frog_fall(lilypad: Node2D) -> void:
	_despawn_lilypad(lilypad)


func _on_lilypad_traveling_ended(lilypad: Node2D, tween) -> void:
	_despawn_lilypad(lilypad)
	tweens.erase(tween)


func _on_spawn_timer_timeout() -> void:
	ready_to_spawn = true


func _on_resized() -> void:
	var rect: = get_rect()
	
	top_point.x = size.x / 2.0
	top_point.y = 0
	
	bottom_point.x = size.x / 2.0
	bottom_point.y = rect.size.y
	
	center_point = rect.size / 2.0
	
	lilypad_scale = rect.size.x / 100.0
