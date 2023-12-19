extends Node2D
class_name LetterSegment

signal finished()

@export var points_per_curve: = 10
@export var max_distance: = 50.0
@export var max_distance_start: = 35.0
@export var hand_min_travel_time: = 0.5
@export var hand_max_travel_time: = 2.0
@export var color_gradient: GradientTexture1D

@onready var tracing_path: = $TracingPath
@onready var guide_path_follow: = $TracingPath/GuidePathFollow
@onready var guide_sprite: = $TracingPath/GuidePathFollow/Guide
@onready var hand_path_follow: = $TracingPath/HandPathFollow2D
@onready var hand_sprite: = $TracingPath/HandPathFollow2D/Sprite
@onready var tracing_effects: = $TracingEffects
@onready var complete_particles: = $CompleteParticles
@onready var complete_sound: = $CompleteAudioStreamPlayer

var max_offset: = 0.0
var touch_positions: = []
var is_playing: = true
var is_in_demo: = false
var remaining_curve: Curve2D
var curve_points: PackedVector2Array
var register_positions: = false


func _ready() -> void:
	complete_sound.stop()
	complete_particles.emitting = false
	
	guide_sprite.visible = false
	hand_sprite.visible = false
	
	set_process(false)
	set_physics_process(false)
	set_process_unhandled_input(false)


func setup(points: Array, word_size: int) -> void:
	if points.size() == 1:
		points.append(points[0] + 5.0 * Vector2.DOWN)
	
	tracing_path.curve = Curve2D.new()
	tracing_path.curve.bake_interval = 1
	tracing_path.curve.resource_local_to_scene = true
	
	tracing_path.width = 20.0 + 20.0 * max(4.0 - word_size, 1.0)
	
	max_distance = 2 * tracing_path.width
	max_distance_start = 0.5 * max_distance
	
	var guide_scale: float = 0.4 + 0.1 * max(4.0 - word_size, 1.0)
	guide_sprite.scale = Vector2(guide_scale, guide_scale)
	
	var smooth_points: = _smooth_points(points) if points.size() > 1 else points.duplicate()
	
	for point in smooth_points:
		tracing_path.curve.add_point(point)
	
	max_offset = tracing_path.curve.get_closest_offset(points[-1])
	guide_path_follow.progress = 0.0
	hand_path_follow.progress = 0.0
	curve_points = PackedVector2Array(tracing_path.curve.get_baked_points())
	remaining_curve = tracing_path.curve.duplicate()
	remaining_curve.clear_points()
	for p in curve_points:
		remaining_curve.add_point(p)


func _smooth_points(points: Array) -> Array:
	var selected_points: = []
	for i in range(0, points.size() - 1, 4):
		selected_points.append(points[i])
	selected_points.append(points[-1])
	
	var smoothed_points_sum: = []
	smoothed_points_sum.resize(selected_points.size())
	var smoothed_points_count: = smoothed_points_sum.duplicate()
	for i in selected_points.size():
		var current_points = selected_points.slice(i, i + points_per_curve - 1)
		var sample_points
		if i == selected_points.size() - 1:
			sample_points = [selected_points[i]]
		else:
			sample_points = Bezier.bezier_sampling(current_points, min(points_per_curve, current_points.size()) - 1)
		for j in sample_points.size():
			var val = smoothed_points_sum[i + j]
			smoothed_points_sum[i + j] = sample_points[j] if val == null else val + sample_points[j]
			val = smoothed_points_count[i + j]
			smoothed_points_count[i + j] = 1 if val == null else val + 1  
	
	var smoothed_points: = smoothed_points_sum.duplicate()
	for i in smoothed_points_sum.size():
		smoothed_points[i] = smoothed_points_sum[i] / smoothed_points_count[i]
	
	return smoothed_points


func start() -> void:
	is_playing = true
	
	guide_sprite.visible = true
	
	guide_path_follow.progress = 0.0
	hand_path_follow.progress = 0.0
	
	set_process(true)
	set_physics_process(true)
	set_process_unhandled_input(true)


func stop() -> void:
	is_playing = false
	
	guide_sprite.visible = false
	tracing_path.color = color_gradient.gradient.sample(1.0)
	
	tracing_effects.stop()
	
	complete_sound.play()
	complete_particles.emitting = true
	complete_particles.global_position = guide_path_follow.global_position


func demo() -> void:
	is_in_demo = true
	
	hand_sprite.visible = true
	
	hand_path_follow.progress_ratio = 0.0
	
	var tween: = get_tree().create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(hand_path_follow, "progress_ratio", 1.0, hand_max_travel_time)
	tween.start()
	await tween.tween_completed
	
	hand_sprite.visible = false
	
	is_in_demo = false
	
	emit_signal("finished")


func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		register_positions = not register_positions


func _process(delta: float) -> void:
	var should_play_effects: = false
	
	hand_sprite.visible = false
	
	if is_playing:
		if register_positions:
			touch_positions.append(get_global_mouse_position())
		
		if guide_path_follow.progress_ratio >= 0.99:
			stop()
		elif not touch_positions.is_empty():
			should_play_effects = _tracing_process()
			_reset_hand_offset()
		elif not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			hand_sprite.visible = true
			_hand_process(delta)
	
	tracing_effects.set_pitch_scale(1.0 + guide_path_follow.progress_ratio)
	
	if should_play_effects:
		tracing_effects.play()
	else:
		tracing_effects.stop()


func _tracing_process() -> bool:
	var should_play_effects: = false
	while touch_positions.size() > 0:
		var touch_position: Vector2 = touch_positions.pop_front()
		var touch_vector: Vector2 = touch_position - guide_path_follow.global_position
		var current_offset = 0.0
		var cond_max_distance: = max_distance_start if guide_path_follow.progress == 0 else max_distance
		if touch_vector.length() < cond_max_distance:
			var touch_position_local: Vector2 = touch_position - tracing_path.global_position
			var target_offset: float = remaining_curve.get_closest_offset(touch_position_local)
			if target_offset > current_offset and target_offset - current_offset <= max_distance:
				guide_path_follow.progress = tracing_path.curve.get_closest_offset(remaining_curve.sample_baked(target_offset))
				
				tracing_path.color = color_gradient.gradient.sample(guide_path_follow.progress_ratio)
				
				should_play_effects = true
				var remove_up_to: = 0
				for i in curve_points.size():
					var offset = tracing_path.curve.get_closest_offset(curve_points[i])
					if offset > guide_path_follow.progress:
						remove_up_to = i
						break
				for i in int(min(remove_up_to, curve_points.size() - 2)):
					curve_points.remove_at(0)
					remaining_curve.remove_point(0)
	
	return should_play_effects


func _hand_process(delta: float) -> void:
	var current_progression: float = guide_path_follow.progress_ratio
	var current_hand_travel_time: = current_progression * hand_min_travel_time + (1.0 - current_progression) * hand_max_travel_time
	var hand_speed: = (1.0 - current_progression) / current_hand_travel_time
	
	hand_path_follow.progress_ratio += delta * hand_speed
	if hand_path_follow.progress_ratio >= 1.0:
		_reset_hand_offset()


func _reset_hand_offset() -> void:
	hand_path_follow.progress_ratio = guide_path_follow.progress_ratio


func _on_CompleteAudioStreamPlayer_finished() -> void:
	set_process(false)
	set_physics_process(false)
	set_process_unhandled_input(false)
	
	tracing_effects.stop()
	
	finished.emit()
