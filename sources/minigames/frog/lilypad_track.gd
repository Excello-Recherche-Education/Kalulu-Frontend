extends Control

signal lilypad_in_center(lilypad: Control)

@onready var audio_player: = $AudioStreamPlayer2D
@onready var spawn_timer: = $SpawnTimer

const lilypad_class: = preload("res://sources/minigames/frog/lilypad.tscn")
const number_of_lilypads: = 25
const lilypad_crossing_time: = 5.0

var is_cleared: = false
var is_enabled: = false:
	set = _set_enabled
var is_highlighting: = false:
	set = _set_highlighting

var ready_to_spawn: = false
var top_to_bottom: = true

var lilypads: = []
var tweens: = []

var stimuli: = []:
	set = _set_stimuli
var are_distractors: = []

var stimuli_queue: = []
var stimuli_queue_size: = 0


func delete() -> void:
	await reset()


func reset() -> void:
	is_cleared = false
	ready_to_spawn = false
	is_enabled = false
	
	for tween in tweens:
		tween.stop()
	
	for lilypad in lilypads:
		lilypad.disappear()
	
	await get_tree().create_timer(0.5).timeout


func start() -> void:
	ready_to_spawn = true


func stop() -> void:
	ready_to_spawn = false


func right() -> void:
	for lilypad in lilypads:
		await lilypad.right()


func _spawn_lilypad() -> void:
	var lilypad: = lilypad_class.instantiate()
	lilypads.append(lilypad)
	
	lilypad.pressed.connect(_on_lilypad_pressed.bind(lilypad))
	lilypad.disappeared.connect(_on_lilypad_disappeared.bind(lilypad))
	add_child(lilypad)
	
	lilypad.disabled = not is_enabled
	
	var start_point: = global_position + Vector2(size.x / 2.0, size.y)
	var end_point: = global_position + Vector2(size.x / 2.0, 0.0)
	if top_to_bottom:
		start_point = global_position + Vector2(size.x / 2.0, 0.0)
		end_point = global_position + Vector2(size.x / 2.0, size.y)
	lilypad.global_position = start_point
	
	var lilypad_size: Vector2 = lilypad.get_real_size()
	if size.x < lilypad_size.x:
		var s: float = size.x / lilypad_size.x
		lilypad.scale = Vector2(s, s)
	
	var potential_stimuli: = stimuli.duplicate()
	var are_potential_distractors: = are_distractors.duplicate()
	for stimulus in stimuli_queue:
		var ind: = potential_stimuli.find(stimulus)
		potential_stimuli.remove_at(ind)
		are_potential_distractors.remove_at(ind)
	
	var i: = randi() % potential_stimuli.size()
	lilypad.stimulus = potential_stimuli[i]
	lilypad.is_distractor = are_potential_distractors[i]
	
	if is_highlighting:
		lilypad.highlight()
	else:
		lilypad.stop_highlight()
	
	stimuli_queue.append(potential_stimuli[i])
	if stimuli_queue.size() > stimuli_queue_size:
		stimuli_queue.pop_front()
	
	var tween: = create_tween()
	tween.finished.connect(_on_tween_finished.bind(lilypad, tween))
	
	tween.tween_property(lilypad, "global_position", end_point, lilypad_crossing_time)
	tweens.append(tween)


func _despawn_lilypad(lilypad: Control) -> void:
	lilypads.erase(lilypad)
	lilypad.queue_free()


func _set_enabled(value: bool) -> void:
	is_enabled = value
	
	for lilypad in lilypads:
		lilypad.disabled = not is_enabled


func _set_highlighting(value: bool) -> void:
	is_highlighting = value
	for lilypad in lilypads:
		if is_highlighting:
			lilypad.highlight()
		else:
			lilypad.stop_highlight()


func _set_stimuli(value: Array) -> void:
	stimuli = value
	stimuli_queue_size = max(0, stimuli.size() - 3)


func _on_lilypad_pressed(lilypad: Control) -> void:
	audio_player.play()
	
	ready_to_spawn = false
	
	for tween in tweens:
		tween.kill()
	tweens = []
	
	for other_lilypad in lilypads:
		if other_lilypad != lilypad:
			other_lilypad.disappear()
	
	var center_tween: = create_tween()
	center_tween.finished.connect(_on_center_tween_finished.bind(lilypad, center_tween))
	
	center_tween.tween_property(lilypad, "global_position", global_position + size / 2.0, 0.5)
	
	tweens.append(center_tween)


func _on_lilypad_disappeared(lilypad: Control) -> void:
	_despawn_lilypad(lilypad)


func _on_tween_finished(lilypad: Control, tween: Tween) -> void:
	lilypad.disappear()
	
	tweens.erase(tween)
	tween.kill()


func _on_center_tween_finished(lilypad: Control, center_tween: Tween) -> void:
	lilypad_in_center.emit(lilypad)
	
	center_tween.kill()
	tweens.erase(center_tween)


func _on_spawn_timer_timeout() -> void:
	if ready_to_spawn:
		_spawn_lilypad()
	
	spawn_timer.start(randf_range(0.75, 1.5))
