extends Path2D

signal finished
signal demo_finished

@export var points_per_curve: int = 25
@export var hand_min_travel_time: float = 0.5
@export var hand_max_travel_time: float = 2.0
@export var distance: float = 100.0

@export var color_gradient: Gradient

@onready var line: Line2D = $Line2D
@onready var guide: PathFollow2D = $GuidePathFollow
@onready var hand: PathFollow2D = $HandPathFollow2D
@onready var guide_sprite: Sprite2D = $GuidePathFollow/Guide
@onready var hand_sprite: Sprite2D = $HandPathFollow2D/Hand

var curve_points: PackedVector2Array
@onready var remaining_curve: Curve2D = Curve2D.new()

var is_playing: bool = false
var is_in_demo: bool = false
var touch_positions: Array[Vector2]
var should_play_effects: bool = false


func _ready() -> void:
	guide_sprite.visible = false
	hand_sprite.visible = false


func _exit_tree() -> void:
	pass
	#if is_instance_valid(remaining_curve):
		#remaining_curve.free()


func _process(delta: float) -> void:
	should_play_effects = false
	
	if is_playing or is_in_demo:
		var points: PackedVector2Array = []
		for index: int in range(0, int(guide.progress), 10):
			var i_f: float = float(index)
			var point: Vector2 = curve.sample_baked(i_f)
			points.append(point)
		line.points = points
		
		if is_playing:
			hand_sprite.visible = false
			if Input.is_action_pressed("left_click"):
				touch_positions.append(get_global_mouse_position())
			
			if guide.progress_ratio >= 0.99:
				stop()
			elif not touch_positions.is_empty():
				_tracing_process()
				_reset_hand_offset()
			elif not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				hand_sprite.visible = true
				_hand_process(delta)


func _tracing_process() -> void:
	while touch_positions.size() > 0:
		var touch_position: Vector2 = touch_positions.pop_front()
		var touch_vector: Vector2 = touch_position - guide.global_position
		var current_offset: float = 0.0
		if touch_vector.length() < distance:
			var target_offset: float = remaining_curve.get_closest_offset(touch_position - global_position)
			if target_offset > current_offset and target_offset - current_offset <= distance:
				guide.progress = curve.get_closest_offset(remaining_curve.sample_baked(target_offset))
				line.default_color = color_gradient.sample(guide.progress_ratio)
				
				should_play_effects = true
				var remove_up_to: int = 0
				for index: int in curve_points.size():
					var offset: float = curve.get_closest_offset(curve_points[index])
					if offset > guide.progress:
						remove_up_to = index
						break
				for _index: int in min(remove_up_to, curve_points.size() - 2):
					curve_points.remove_at(0)
					remaining_curve.remove_point(0)


func _hand_process(delta: float) -> void:
	var current_progression: float = guide.progress_ratio
	var current_hand_travel_time: float = current_progression * hand_min_travel_time + (1.0 - current_progression) * hand_max_travel_time
	var hand_speed: float = (1.0 - current_progression) / current_hand_travel_time
	
	hand.progress_ratio += delta * hand_speed
	if hand.progress_ratio >= 1.0:
		_reset_hand_offset()


func _reset_hand_offset() -> void:
	hand.progress_ratio = guide.progress_ratio


func setup(points: Array) -> void:
	curve = Curve2D.new()
	curve.bake_interval = 1
	curve.resource_local_to_scene = true
	line.width = 50.0
	
	var smooth_points: Array[Vector2] = _smooth_points(points)
	for point: Vector2 in smooth_points:
		curve.add_point(point)
	
	guide.progress = 0.0
	hand.progress = 0.0
	
	curve_points = curve.get_baked_points()
	
	remaining_curve.clear_points()
	for point: Vector2 in curve_points:
		remaining_curve.add_point(point)


func _smooth_points(points: Array) -> Array:
	return Bezier.bezier_sampling(points, maxi(points_per_curve, points.size()))


func set_points(points: Array) -> void:
	curve.clear_points()
	for point: Vector2 in points:
		curve.add_point(point)


func set_guide_progress(progress: float) -> void:
	guide.progress = progress


func get_guide_progress() -> float:
	return guide.progress


func get_guide_progress_ratio() -> float:
	return guide.progress_ratio


func set_hand_progress(progress: float) -> void:
	hand.progress = progress


func start() -> void:
	is_playing = true
	guide_sprite.visible = true
	
	guide.progress = 0.0
	hand.progress = 0.0


func stop() -> void:
	is_playing = false
	guide_sprite.visible = false
	
	finished.emit()


func demo() -> void:
	is_in_demo = true
	hand_sprite.visible = true
	hand.progress_ratio = 0.0
	
	var tween: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(hand, "progress_ratio", 1.0, hand_max_travel_time)
	tween.tween_callback(demo_end)


func demo_end() -> void:
	hand_sprite.visible = false
	is_in_demo = false
	demo_finished.emit()
